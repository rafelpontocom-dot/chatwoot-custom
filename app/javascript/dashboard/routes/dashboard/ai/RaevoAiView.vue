<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useAdmin } from 'dashboard/composables/useAdmin';
import RaevoPageHeader from 'dashboard/components-next/raevo/RaevoPageHeader.vue';
import TabBar from 'dashboard/components-next/tabbar/TabBar.vue';
import RaevoAiKnowledgePanel from './RaevoAiKnowledgePanel.vue';
import RaevoField from 'dashboard/components-next/raevo/RaevoField.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import RaevoAiAPI from 'dashboard/api/raevoAi';
import RaevoAiServiceHoursSettings from './RaevoAiServiceHoursSettings.vue';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const accountId = computed(() => route.params.accountId);

// Três abas, e a separação não é arbitrária: «Painel» é o que a clínica vem
// ver, «A secretária» é o que ela configura, «Conhecimento» é o que a
// secretária sabe responder.
const abaAtiva = ref('panel');
const abas = computed(() => [
  { key: 'panel', label: t('RAEVO_AI.TABS.PANEL') },
  { key: 'assistant', label: t('RAEVO_AI.TABS.ASSISTANT') },
  { key: 'knowledge', label: t('RAEVO_AI.TABS.KNOWLEDGE') },
]);
const indiceDaAba = computed(() =>
  abas.value.findIndex(aba => aba.key === abaAtiva.value)
);
const mudarAba = aba => {
  abaAtiva.value = aba.key;
};

// A calha encolhe no Conhecimento. Ali o trabalho é editar texto lado a lado
// com a lista, e uma coluna fixa de 18rem dava três colunas a 1280px — que é
// exactamente a largura onde isto se parte. O estado continua no ecrã, numa
// faixa; é a promessa da bancada cumprida com a forma que a aba comporta.
const calhaCompacta = computed(() => abaAtiva.value === 'knowledge');

// A janela que a clínica escolheu ver. Trinta dias por omissão porque é o que
// responde «como foi o mês», que é a pergunta que ela traz.
const windowDays = ref(30);
const windowOptions = [7, 30, 90];

// Pausa: o estado vem do serviço, e é ele que o botão altera.
const pauseState = ref(null);
const isSavingPause = ref(false);
const pauseError = ref(null);

// O que a secretária fez e o que ficou por resolver.
const activity = ref({ recent: [], attention: { failed: 0, pending: 0 } });

const overview = ref(null);
const isLoading = ref(true);
const hasError = ref(false);
const isPreparing = ref(false);
const isDisabled = ref(false);
const { isAdmin } = useAdmin();
const formatTokens = value =>
  Number.isFinite(Number(value))
    ? new Intl.NumberFormat('en-US').format(Number(value))
    : '—';
const formatUsd = value => `US$ ${Number(value || 0).toFixed(2)}`;

const usage = computed(() => overview.value?.usage || {});

const usageCost = computed(() => {
  const reported = Number(usage.value.provider_reported_cost_usd || 0);
  const estimated = Number(usage.value.catalog_estimated_cost_usd || 0);
  const unavailable = Number(usage.value.cost_unavailable_calls || 0);
  const parts = [];

  if (reported > 0) parts.push(formatUsd(reported));
  if (estimated > 0) parts.push(`${formatUsd(estimated)} est.`);
  if (unavailable > 0) parts.push(`${unavailable} indisponível`);

  return parts.length ? parts.join(' · ') : '—';
});

const numero = valor =>
  Number.isFinite(Number(valor))
    ? new Intl.NumberFormat(undefined).format(Number(valor))
    : null;

// Taxa de uma etapa sobre a anterior. É isto que transforma cinco números
// soltos num funil: 112 oportunidades só quer dizer alguma coisa ao lado das
// 308 conversas de onde saíram.
const taxa = (parte, total) => {
  if (!Number.isFinite(Number(parte)) || !Number(total)) return null;
  return `${((Number(parte) / Number(total)) * 100).toFixed(1).replace('.', ',')}%`;
};

// A taxa sozinha é ambígua: «57,1%» de quê? Na calha, onde o número está
// encostado ao rótulo e não há espaço para uma coluna de contexto, a legenda
// tem de dizer sobre que etapa a percentagem foi calculada.
// A chave chega inteira e não montada por interpolação, pela mesma razão que o
// mapa de comandos: uma tradução em falta tem de ser encontrada pelas
// ferramentas, e não descoberta como texto cru no ecrã da clínica.
//
// Acima de 100% não se mostra nada. Os degraus não vêm todos da mesma base —
// «oportunidades criadas» conta comandos no Chatwoot e os restantes contam
// desfechos no runtime —, e as duas contas podem discordar de boa-fé: a
// secretária pré-agenda numa conversa cuja oportunidade já existia e não
// precisou de ser criada. Escrever «2700,0% das oportunidades» destrói a
// confiança no ecrã inteiro; não escrever nada só deixa a linha mais sóbria.
const sobre = (parte, total, chave) => {
  const valor = taxa(parte, total);
  if (!valor || Number(parte) > Number(total)) return null;
  return t(chave, { rate: valor });
};

// A jornada segue o quadro da clínica: Leads de entrada e Qualificação dão a
// oportunidade, «Agendar» é o pré-agendado, «Agendado» é o agendado e «Ganho»
// é o desfecho. «Não responde» e «Perdido» ficam de fora de propósito — são
// ramos terminais, não degraus, e contá-los subia o funil quando ele piorava.
//
// Não há degrau de «qualificada» porque nesta clínica qualificar e agendar são
// o mesmo momento: o lead qualificou-se ao marcar. Um degrau que mede a mesma
// gente que o seguinte não informa, ocupa espaço.
const journeySteps = computed(() => {
  const conversas = usage.value.conversations;
  const criadas = overview.value?.opportunities_created;
  const preAgendadas = usage.value.pre_scheduled;
  const agendadas = usage.value.appointments;
  const ganhas = usage.value.payments;

  // O desfecho mostra as duas coisas: que é o resultado do pacote e quanto do
  // degrau anterior sobreviveu até aqui.
  const desfecho = sobre(ganhas, agendadas, 'RAEVO_AI.JOURNEY.OF_SCHEDULED');

  return [
    {
      key: 'CONVERSATIONS',
      label: t('RAEVO_AI.JOURNEY.CONVERSATIONS'),
      linkLabel: t('RAEVO_AI.JOURNEY.LINK_CONVERSATIONS'),
      value: numero(conversas),
      caption: null,
      link: { name: 'home' },
    },
    {
      key: 'OPPORTUNITIES',
      label: t('RAEVO_AI.JOURNEY.OPPORTUNITIES'),
      linkLabel: t('RAEVO_AI.JOURNEY.LINK_KANBAN'),
      value: numero(criadas),
      caption: sobre(criadas, conversas, 'RAEVO_AI.JOURNEY.OF_CONVERSATIONS'),
      link: { name: 'kanban_boards' },
    },
    {
      key: 'PRE_SCHEDULED',
      label: t('RAEVO_AI.JOURNEY.PRE_SCHEDULED'),
      linkLabel: t('RAEVO_AI.JOURNEY.LINK_KANBAN'),
      value: numero(preAgendadas),
      // Medido contra as conversas, e não contra as oportunidades criadas: é
      // aqui que o funil atravessa a fronteira entre o Chatwoot e o runtime, e
      // a conversa é a única base que os dois lados partilham.
      caption: sobre(
        preAgendadas,
        conversas,
        'RAEVO_AI.JOURNEY.OF_CONVERSATIONS'
      ),
      link: { name: 'kanban_boards' },
    },
    {
      key: 'SCHEDULED',
      label: t('RAEVO_AI.JOURNEY.SCHEDULED'),
      linkLabel: t('RAEVO_AI.JOURNEY.LINK_CALENDAR'),
      value: numero(agendadas),
      caption: sobre(
        agendadas,
        preAgendadas,
        'RAEVO_AI.JOURNEY.OF_PRE_SCHEDULED'
      ),
      link: { name: 'calendar_index' },
    },
    {
      key: 'WON',
      label: t('RAEVO_AI.JOURNEY.WON'),
      linkLabel: t('RAEVO_AI.JOURNEY.LINK_FINANCE'),
      value: numero(ganhas),
      caption: desfecho
        ? `${t('RAEVO_AI.JOURNEY.OUTCOME')} · ${desfecho}`
        : t('RAEVO_AI.JOURNEY.OUTCOME'),
      link: { name: 'finance_index' },
      outcome: true,
    },
  ];
});

// Quanto tempo passou, em palavras. Numa lista de atividade o que interessa é
// a recência, não a hora cheia.
const desdeEntao = iso => {
  if (!iso) return null;
  const minutos = Math.round((Date.now() - new Date(iso).getTime()) / 60000);
  if (!Number.isFinite(minutos)) return null;
  if (minutos < 60)
    return t('RAEVO_AI.ACTIVITY.AGO_MINUTES', { count: Math.max(minutos, 0) });
  if (minutos < 1440)
    return t('RAEVO_AI.ACTIVITY.AGO_HOURS', {
      count: Math.round(minutos / 60),
    });
  return t('RAEVO_AI.ACTIVITY.AGO_DAYS', { count: Math.round(minutos / 1440) });
};

const estadoTitulo = computed(() => {
  if (!pauseState.value) return t('RAEVO_AI.OVERVIEW.STATUS_UNKNOWN');
  return pauseState.value.paused
    ? t('RAEVO_AI.OVERVIEW.PLATE_PAUSED')
    : t('RAEVO_AI.OVERVIEW.PLATE_ACTIVE');
});

// A prova de que ela está viva não é o estado guardado: é a última resposta que
// chegou mesmo ao paciente.
const ultimaResposta = computed(() => {
  const quando = desdeEntao(overview.value?.last_delivered_at);
  return quando
    ? t('RAEVO_AI.OVERVIEW.LAST_DELIVERED', { ago: quando })
    : t('RAEVO_AI.OVERVIEW.LAST_DELIVERED_NONE');
});

const atualizadoEm = computed(() => {
  const iso = overview.value?.generated_at;
  if (!iso) return null;
  const data = new Date(iso);
  if (Number.isNaN(data.getTime())) return null;
  return t('RAEVO_AI.OVERVIEW.UPDATED_AT', {
    time: new Intl.DateTimeFormat(undefined, {
      hour: '2-digit',
      minute: '2-digit',
    }).format(data),
  });
});

// Quanto tempo a paciente esperou pela primeira resposta. Em minutos abaixo de
// uma hora, porque é a unidade em que a clínica pensa.
const firstResponse = computed(() => {
  const segundos = usage.value.first_response_seconds;
  if (!Number.isFinite(Number(segundos))) return null;
  const minutos = Math.round(Number(segundos) / 60);
  return minutos < 60
    ? t('RAEVO_AI.ATTENDANCE.MINUTES', { count: minutos })
    : t('RAEVO_AI.ATTENDANCE.HOURS', { count: Math.round(minutos / 6) / 10 });
});

const attendanceMetrics = computed(() => [
  {
    key: 'RESPONSES',
    label: t('RAEVO_AI.ATTENDANCE.RESPONSES'),
    value: numero(usage.value.responses_delivered),
    caption:
      usage.value.conversations && usage.value.responses_delivered
        ? t('RAEVO_AI.ATTENDANCE.PER_CONVERSATION', {
            rate: (usage.value.responses_delivered / usage.value.conversations)
              .toFixed(1)
              .replace('.', ','),
          })
        : null,
    link: { name: 'home' },
  },
  {
    key: 'HANDOFFS',
    label: t('RAEVO_AI.ATTENDANCE.HANDOFFS'),
    value: numero(usage.value.handoffs),
    caption: taxa(usage.value.handoffs, usage.value.conversations)
      ? t('RAEVO_AI.ATTENDANCE.OF_CONVERSATIONS', {
          rate: taxa(usage.value.handoffs, usage.value.conversations),
        })
      : null,
    link: { name: 'home' },
  },
  {
    key: 'FIRST_RESPONSE',
    label: t('RAEVO_AI.ATTENDANCE.FIRST_RESPONSE'),
    value: firstResponse.value,
    caption: t('RAEVO_AI.ATTENDANCE.MEDIAN'),
  },
]);

const costMetrics = computed(() => {
  const total =
    Number(usage.value.provider_reported_cost_usd || 0) +
    Number(usage.value.catalog_estimated_cost_usd || 0);
  const conversas = Number(usage.value.conversations || 0);
  const agendadas = Number(usage.value.appointments || 0);
  const entrada = Number(usage.value.prompt_tokens || 0);
  const saida = Number(usage.value.completion_tokens || 0);

  return [
    {
      key: 'TOTAL',
      label: t('RAEVO_AI.COSTS.TOTAL'),
      value: formatUsd(total),
      caption: null,
    },
    {
      key: 'PER_CONVERSATION',
      label: t('RAEVO_AI.COSTS.PER_CONVERSATION'),
      value: conversas ? `US$ ${(total / conversas).toFixed(3)}` : '—',
      caption: t('RAEVO_AI.COSTS.CONVERSATIONS', { count: conversas }),
    },
    {
      key: 'PER_APPOINTMENT',
      label: t('RAEVO_AI.COSTS.PER_APPOINTMENT'),
      value: agendadas ? formatUsd(total / agendadas) : '—',
      caption: t('RAEVO_AI.COSTS.APPOINTMENTS', { count: agendadas }),
    },
    {
      key: 'TOKENS',
      label: t('RAEVO_AI.COSTS.TOKENS'),
      value: `${formatTokens(entrada)} / ${formatTokens(saida)}`,
      caption: t('RAEVO_AI.COSTS.TOKENS_TOTAL', {
        total: formatTokens(entrada + saida),
      }),
    },
  ];
});
const capabilityLabels = {
  atendimento: t('RAEVO_AI.CAPABILITIES.ITEMS.ATENDIMENTO'),
  crm: t('RAEVO_AI.CAPABILITIES.ITEMS.CRM'),
  agenda: t('RAEVO_AI.CAPABILITIES.ITEMS.AGENDA'),
  observabilidade: t('RAEVO_AI.CAPABILITIES.ITEMS.OBSERVABILITY'),
};
const capabilityProviderLabels = {
  chatwoot: t('RAEVO_AI.CAPABILITIES.PROVIDERS.CHATWOOT'),
  kommo: t('RAEVO_AI.CAPABILITIES.PROVIDERS.KOMMO'),
  calcom: t('RAEVO_AI.CAPABILITIES.PROVIDERS.CALCOM'),
  google_calendar: t('RAEVO_AI.CAPABILITIES.PROVIDERS.GOOGLE_CALENDAR'),
  feegow: t('RAEVO_AI.CAPABILITIES.PROVIDERS.FEEGOW'),
  chatwoot_native: t('RAEVO_AI.CAPABILITIES.PROVIDERS.CHATWOOT_NATIVE'),
};
const activeCapabilities = computed(() => {
  const capabilities = overview.value?.capabilities?.capabilities;
  if (!Array.isArray(capabilities)) return [];

  return capabilities
    .map(capability => ({
      id: capability?.id,
      label: capabilityLabels[capability?.id],
      provider: capabilityProviderLabels[capability?.provider] || null,
    }))
    .filter(capability => capability.label);
});

// `command_type` chega como `crm.move_stage`; o ecrã da clínica não mostra
// identificadores de sistema. O mapa é explícito, e não uma chave montada por
// interpolação, para uma tradução em falta ser encontrada pelas ferramentas em
// vez de aparecer como texto cru ao cliente.
const commandLabels = computed(() => ({
  'calendar.book_appointment': t(
    'RAEVO_AI.ACTIVITY.COMMANDS.CALENDAR_BOOK_APPOINTMENT'
  ),
  'crm.add_label': t('RAEVO_AI.ACTIVITY.COMMANDS.CRM_ADD_LABEL'),
  'crm.ensure_opportunity': t(
    'RAEVO_AI.ACTIVITY.COMMANDS.CRM_ENSURE_OPPORTUNITY'
  ),
  'crm.move_stage': t('RAEVO_AI.ACTIVITY.COMMANDS.CRM_MOVE_STAGE'),
  'crm.update_contact_name': t(
    'RAEVO_AI.ACTIVITY.COMMANDS.CRM_UPDATE_CONTACT_NAME'
  ),
  'crm.update_fields': t('RAEVO_AI.ACTIVITY.COMMANDS.CRM_UPDATE_FIELDS'),
  'finance.create_charge': t(
    'RAEVO_AI.ACTIVITY.COMMANDS.FINANCE_CREATE_CHARGE'
  ),
  'handoff.apply': t('RAEVO_AI.ACTIVITY.COMMANDS.HANDOFF_APPLY'),
}));

const stateLabels = computed(() => ({
  applied: t('RAEVO_AI.ACTIVITY.STATE_APPLIED'),
  claimed: t('RAEVO_AI.ACTIVITY.STATE_CLAIMED'),
  failed_retryable: t('RAEVO_AI.ACTIVITY.STATE_FAILED_RETRYABLE'),
  failed_terminal: t('RAEVO_AI.ACTIVITY.STATE_FAILED_TERMINAL'),
}));

const commandLabel = tipo =>
  commandLabels.value[tipo] ?? t('RAEVO_AI.ACTIVITY.COMMANDS.UNKNOWN');

const stateLabel = estado =>
  stateLabels.value[estado] ?? t('RAEVO_AI.ACTIVITY.STATE_UNKNOWN');

const loadOverview = async () => {
  isLoading.value = true;
  hasError.value = false;
  isPreparing.value = false;
  isDisabled.value = false;

  try {
    const { data } = await RaevoAiAPI.getOverview(windowDays.value);
    const connectionState = data?.connection_state;
    overview.value = connectionState ? data.overview : data;
    isPreparing.value = connectionState === 'not_configured';
    isDisabled.value = connectionState === 'disabled';
    hasError.value = connectionState === 'unavailable';
  } catch (error) {
    overview.value = null;
    isPreparing.value = error?.response?.status === 404;
    hasError.value = !isPreparing.value;
  } finally {
    isLoading.value = false;
  }
};

const loadPauseState = async () => {
  try {
    const { data } = await RaevoAiAPI.getPauseState();
    pauseState.value = data.state;
  } catch {
    // O painel não fica refém do estado de pausa: sem ele o botão esconde-se,
    // em vez de o ecrã inteiro falhar por causa de um controlo.
    pauseState.value = null;
  }
};

const loadActivity = async () => {
  try {
    const { data } = await RaevoAiAPI.getActivity();
    activity.value = data;
  } catch {
    activity.value = { recent: [], attention: { failed: 0, pending: 0 } };
  }
};

const togglePause = async () => {
  const queroPausar = !pauseState.value?.paused;
  // Pausar faz a clínica deixar de responder ao paciente: pede confirmação.
  // Retomar não pede — voltar a atender não é a decisão arriscada.
  // eslint-disable-next-line no-alert
  if (queroPausar && !window.confirm(t('RAEVO_AI.PAUSE.CONFIRM'))) return;

  isSavingPause.value = true;
  pauseError.value = null;
  try {
    const { data } = await RaevoAiAPI.savePauseState({
      paused: queroPausar,
      expected_revision: pauseState.value?.revision ?? null,
    });
    pauseState.value = data.state;
  } catch (e) {
    pauseError.value =
      e?.response?.status === 409
        ? t('RAEVO_AI.PAUSE.CONFLICT')
        : t('RAEVO_AI.PAUSE.UNAVAILABLE');
  } finally {
    isSavingPause.value = false;
  }
};

const changeWindow = async dias => {
  windowDays.value = dias;
  await loadOverview();
};

onMounted(loadOverview);
onMounted(loadPauseState);
onMounted(loadActivity);

const servicePackages = computed(() => [
  {
    key: 'QUALIFY_HANDOFF',
    icon: 'i-lucide-messages-square',
    title: t('RAEVO_AI.PACKAGES.QUALIFY_HANDOFF.TITLE'),
    description: t('RAEVO_AI.PACKAGES.QUALIFY_HANDOFF.DESCRIPTION'),
  },
  {
    key: 'SCHEDULE',
    icon: 'i-lucide-calendar-check-2',
    title: t('RAEVO_AI.PACKAGES.SCHEDULE.TITLE'),
    description: t('RAEVO_AI.PACKAGES.SCHEDULE.DESCRIPTION'),
  },
  {
    key: 'COMPLETE',
    icon: 'i-lucide-badge-dollar-sign',
    title: t('RAEVO_AI.PACKAGES.COMPLETE.TITLE'),
    description: t('RAEVO_AI.PACKAGES.COMPLETE.DESCRIPTION'),
  },
]);

// Só o pacote contratado aparece: mostrar os três transformava o painel da
// clínica num folheto do que ela não comprou.
//
// O runtime nomeia os pacotes à sua maneira; esta tabela é a tradução para os
// três do ecrã. Pacote desconhecido não mostra nada — inventar qual seria pior
// do que dizer que ainda não se sabe.
const PACKAGE_BY_RUNTIME = {
  atendimento_basico: 'QUALIFY_HANDOFF',
  crm: 'QUALIFY_HANDOFF',
  agenda: 'SCHEDULE',
  completo: 'COMPLETE',
};

const contractedPackage = computed(() => {
  const key = PACKAGE_BY_RUNTIME[overview.value?.package];
  return servicePackages.value.find(item => item.key === key) ?? null;
});

// Ícone e cor por desfecho. Cor sozinha não comunica estado — vai sempre com
// ícone e com o texto do estado por baixo.
const APARENCIA_POR_ESTADO = {
  applied: { icon: 'i-lucide-check', tone: 'bg-n-teal-3 text-n-teal-11' },
  claimed: { icon: 'i-lucide-loader', tone: 'bg-n-blue-3 text-n-blue-11' },
  failed_retryable: {
    icon: 'i-lucide-rotate-ccw',
    tone: 'bg-n-amber-3 text-n-amber-11',
  },
  failed_terminal: {
    icon: 'i-lucide-triangle-alert',
    tone: 'bg-n-ruby-3 text-n-ruby-11',
  },
};

// Para onde o «Abrir» leva, dito antes de se carregar. Sem isto a linha tinha
// setecentos pixéis vazios entre o que ela fez e o botão, e a clínica só
// descobria o destino depois de sair do ecrã.
const nomeDoDestino = alvo => {
  if (alvo?.type === 'conversation')
    return t('RAEVO_AI.ACTIVITY.TARGET_CONVERSATION', { id: alvo.id });
  if (alvo?.type === 'card')
    return t('RAEVO_AI.ACTIVITY.TARGET_CARD', { id: alvo.id });
  return null;
};

const destinoDoItem = alvo => {
  if (alvo?.type === 'conversation') {
    return {
      name: 'home',
      params: { accountId: accountId.value },
      query: { conversation_id: alvo.id },
    };
  }
  if (alvo?.type === 'card') {
    return {
      name: 'kanban_board_show',
      params: { accountId: accountId.value, boardId: alvo.board_id },
      query: { card_id: alvo.id },
    };
  }
  return null;
};

const activityRows = computed(() =>
  activity.value.recent.map(item => ({
    id: item.id,
    ago: desdeEntao(item.occurred_at) ?? '—',
    occurredAt: item.occurred_at,
    rawState: item.state,
    label: commandLabel(item.command_type),
    state: stateLabel(item.state),
    icon: (APARENCIA_POR_ESTADO[item.state] ?? APARENCIA_POR_ESTADO.claimed)
      .icon,
    tone: (APARENCIA_POR_ESTADO[item.state] ?? APARENCIA_POR_ESTADO.claimed)
      .tone,
    // A conversa e o cartão servem os dois como destino. Sem nenhum não há
    // botão — melhor do que um botão que não abre nada.
    to: destinoDoItem(item.target),
    destino: nomeDoDestino(item.target),
  }))
);

const abrirRegisto = item => {
  if (item.to) router.push(item.to);
};

// O mesmo limiar que o servidor usa em `activity_controller.rb`: reclamado há
// menos de cinco minutos é trabalho a decorrer, não trabalho parado. Repetido
// aqui porque as contagens vêm prontas e as linhas não.
const PARADO_DEPOIS_DE_MS = 5 * 60 * 1000;
const ESTADOS_FALHADOS = ['failed_retryable', 'failed_terminal'];

const precisaDePessoa = linha => {
  if (ESTADOS_FALHADOS.includes(linha.rawState)) return true;
  if (linha.rawState !== 'claimed') return false;
  const quando = new Date(linha.occurredAt).getTime();
  return Number.isFinite(quando) && Date.now() - quando >= PARADO_DEPOIS_DE_MS;
};

// As contagens do servidor cobrem tudo; as linhas só as vinte mais recentes. A
// contagem é que manda no título, e as linhas são o que dá para agir agora.
const needsYouRows = computed(() => activityRows.value.filter(precisaDePessoa));

const needsYouTotal = computed(
  () => activity.value.attention.failed + activity.value.attention.pending
);

const needsYouTitle = computed(() =>
  needsYouTotal.value
    ? t('RAEVO_AI.ACTIVITY.ATTENTION_TITLE', { count: needsYouTotal.value })
    : t('RAEVO_AI.ACTIVITY.ATTENTION_TITLE_EMPTY')
);

// Quando o servidor conta mais do que as vinte linhas mostram, dizê-lo é a
// diferença entre «resolvi tudo» e «resolvi o que via».
const needsYouRemainder = computed(() =>
  Math.max(needsYouTotal.value - needsYouRows.value.length, 0)
);

// Leitura, exceto o nome e o horário. O resto muda-se com a Raevo, e dizê-lo é
// mais honesto do que oferecer um campo que não grava.
// O nome em uso vem do overview; nulo ali significa que a clínica não escolheu
// e o runtime usa o padrão.
const assistantName = ref('');
const isSavingName = ref(false);
const nameError = ref(null);

watch(
  () => overview.value?.assistant_name,
  valor => {
    assistantName.value = valor ?? '';
  },
  { immediate: true }
);

const saveAssistantName = async () => {
  isSavingName.value = true;
  nameError.value = null;
  try {
    const { data } = await RaevoAiAPI.saveAssistantName(
      assistantName.value.trim()
    );
    // Vazio repõe o padrão, e é o serviço que diz qual é — o ecrã não o inventa.
    assistantName.value = data.state.assistant_name ?? '';
    if (overview.value) {
      overview.value.assistant_name = data.state.assistant_name;
      overview.value.effective_assistant_name = data.state.effective_name;
    }
  } catch (e) {
    nameError.value =
      e?.response?.status === 409
        ? t('RAEVO_AI.SETUP.NAME_CONFLICT')
        : t('RAEVO_AI.SETUP.NAME_UNAVAILABLE');
  } finally {
    isSavingName.value = false;
  }
};

const setupRows = computed(() => [
  {
    key: 'package',
    label: t('RAEVO_AI.SETUP.PACKAGE'),
    value: contractedPackage.value?.title ?? '—',
    detail: contractedPackage.value?.description ?? null,
  },
  {
    key: 'capabilities',
    label: t('RAEVO_AI.SETUP.CAPABILITIES'),
    value: activeCapabilities.value.length
      ? activeCapabilities.value.map(c => c.label).join(' · ')
      : '—',
    detail: null,
  },
  {
    key: 'language',
    label: t('RAEVO_AI.SETUP.LANGUAGE'),
    value: t('RAEVO_AI.SETUP.LANGUAGE_VALUE'),
    detail: null,
  },
]);
</script>

<template>
  <main
    data-testid="ai-workspace"
    class="flex min-h-0 w-full min-w-0 flex-1 flex-col overflow-y-auto bg-n-background px-4 py-5 pb-10 sm:px-6 lg:px-8"
  >
    <div class="mx-auto flex w-full max-w-[96rem] flex-col gap-4">
      <RaevoPageHeader
        :eyebrow="t('RAEVO_AI.EYEBROW')"
        :title="t('RAEVO_AI.TITLE')"
        :subtitle="t('RAEVO_AI.SUBTITLE')"
      >
        <template #actions>
          <div v-if="pauseState" class="flex items-center gap-2">
            <span
              data-testid="ai-pause-state"
              class="flex items-center gap-2 rounded-full px-2.5 py-1 text-xs font-medium"
              :class="
                pauseState.paused
                  ? 'bg-n-amber-3 text-n-amber-11'
                  : 'bg-n-teal-3 text-n-teal-11'
              "
            >
              <i
                :class="
                  pauseState.paused
                    ? 'i-lucide-circle-pause'
                    : 'i-lucide-circle-check'
                "
                class="size-3.5"
                aria-hidden="true"
              />
              {{
                pauseState.paused
                  ? t('RAEVO_AI.PAUSE.STATE_PAUSED')
                  : t('RAEVO_AI.PAUSE.STATE_ACTIVE')
              }}
            </span>
            <NextButton
              v-if="isAdmin"
              data-testid="ai-pause-toggle"
              size="sm"
              :variant="pauseState.paused ? 'solid' : 'faded'"
              :is-loading="isSavingPause"
              :label="
                pauseState.paused
                  ? t('RAEVO_AI.PAUSE.RESUME')
                  : t('RAEVO_AI.PAUSE.PAUSE')
              "
              @click="togglePause"
            />
          </div>
        </template>

        <template #tabs>
          <TabBar
            data-testid="ai-tabs"
            :tabs="abas"
            :initial-active-tab="indiceDaAba"
            @tab-changed="mudarAba"
          />
        </template>
      </RaevoPageHeader>

      <p
        v-if="pauseError"
        data-testid="ai-pause-error"
        class="text-sm text-n-ruby-11"
        role="alert"
      >
        {{ pauseError }}
      </p>

      <!-- A bancada. O estado e a jornada ficam numa calha fixa à esquerda e
           não saem do ecrã enquanto se trabalha à direita; era a rolar até aos
           custos que a clínica perdia de vista se a secretária estava pausada. -->
      <div
        class="grid items-start gap-4"
        :class="
          calhaCompacta ? '' : 'lg:grid-cols-[minmax(0,18.5rem)_minmax(0,1fr)]'
        "
      >
        <aside
          data-testid="ai-rail"
          class="flex flex-col gap-3"
          :class="calhaCompacta ? '' : 'lg:sticky lg:top-0'"
        >
          <!-- Compacta, a placa é uma linha: o estado à esquerda e o período à
               direita. Empilhada ocuparia a largura toda para deixar metade
               vazia, que foi o que o primeiro ensaio mostrou. -->
          <section
            data-testid="ai-plate"
            class="rounded-xl bg-raevo-plate p-4"
            :class="
              calhaCompacta
                ? 'flex flex-wrap items-center justify-between gap-x-6 gap-y-3'
                : ''
            "
          >
            <div>
              <p
                class="text-micro font-semibold uppercase text-raevo-plate-muted"
              >
                {{ t('RAEVO_AI.OVERVIEW.STATE_EYEBROW') }}
              </p>
              <h2 class="mt-1 text-base font-semibold text-raevo-plate-fg">
                {{ estadoTitulo }}
              </h2>
              <p class="mt-1 text-xs leading-5 text-raevo-plate-muted">
                {{ ultimaResposta }}
              </p>
            </div>

            <div
              data-testid="ai-window-filter"
              class="flex flex-wrap items-center gap-1.5"
              :class="calhaCompacta ? '' : 'mt-3'"
              role="group"
              :aria-label="t('RAEVO_AI.OVERVIEW.WINDOW_LABEL')"
            >
              <button
                v-for="dias in windowOptions"
                :key="dias"
                type="button"
                :aria-pressed="windowDays === dias"
                :aria-label="t('RAEVO_AI.OVERVIEW.WINDOW_DAYS', { days: dias })"
                class="rounded-full px-2.5 py-1 text-micro font-semibold"
                :class="
                  windowDays === dias
                    ? 'bg-raevo-plate-fg text-raevo-plate'
                    : 'bg-raevo-plate-soft text-raevo-plate-muted'
                "
                @click="changeWindow(dias)"
              >
                <!-- Abreviado porque a calha tem 296px e «Últimos 30 dias»
                     vezes três quebrava para duas linhas. O rótulo por extenso
                     fica no `aria-label`, que é onde faz falta. -->
                {{ t('RAEVO_AI.OVERVIEW.WINDOW_DAYS_SHORT', { days: dias }) }}
              </button>
              <span
                v-if="atualizadoEm"
                class="text-micro text-raevo-plate-muted"
              >
                {{ atualizadoEm }}
              </span>
            </div>

            <!-- A jornada em calha: rótulo à esquerda, número à direita, e a
                 legenda a dizer sobre que etapa a percentagem foi calculada —
                 «57,1%» sozinho não diz de quê. -->
            <div
              v-if="isLoading && !calhaCompacta"
              class="mt-3 h-48 animate-pulse rounded-lg bg-raevo-plate-soft"
              role="status"
              :aria-label="t('RAEVO_AI.OVERVIEW.LOADING')"
            />
            <dl
              v-else-if="!calhaCompacta"
              data-testid="ai-journey"
              class="mt-3 flex flex-col gap-px overflow-hidden rounded-lg bg-raevo-plate-soft"
              :aria-label="t('RAEVO_AI.JOURNEY.LABEL')"
            >
              <div
                v-for="etapa in journeySteps"
                :key="etapa.key"
                data-testid="ai-journey-step"
                class="group relative flex items-baseline justify-between gap-3 px-3 py-2.5"
                :class="
                  etapa.outcome
                    ? 'border-l-2 border-solid border-n-teal-9 bg-raevo-plate-soft'
                    : 'bg-raevo-plate'
                "
              >
                <dt class="min-w-0">
                  <router-link
                    :to="{ ...etapa.link, params: { accountId } }"
                    :aria-label="etapa.linkLabel"
                    class="text-xs font-semibold text-raevo-plate-fg after:absolute after:inset-0 after:content-[''] group-hover:underline focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-n-teal-9"
                  >
                    {{ etapa.label }}
                  </router-link>
                  <span
                    v-if="etapa.hint || etapa.caption"
                    class="mt-0.5 block text-micro text-raevo-plate-muted"
                  >
                    {{ etapa.hint || etapa.caption }}
                  </span>
                </dt>
                <dd
                  class="flex shrink-0 items-center gap-1 text-base font-semibold tabular-nums"
                  :class="
                    etapa.outcome ? 'text-n-teal-9' : 'text-raevo-plate-fg'
                  "
                >
                  {{ etapa.value ?? '—' }}
                  <i
                    class="i-lucide-chevron-right size-3.5 text-raevo-plate-muted"
                    aria-hidden="true"
                  />
                </dd>
              </div>
            </dl>

            <p
              v-if="!calhaCompacta"
              class="mt-2 text-micro leading-4 text-raevo-plate-muted"
            >
              {{ t('RAEVO_AI.JOURNEY.NOTE') }}
            </p>
          </section>

          <!-- Nota técnica, e é por isso que está aqui em baixo e não em cima:
               ocupava o espaço nobre das três abas para dizer uma coisa que se
               lê uma vez. -->
          <p class="text-micro leading-4 text-n-slate-10">
            {{ t('RAEVO_AI.NATIVE_AREA.DESCRIPTION') }}
          </p>
        </aside>

        <div class="flex min-w-0 flex-col gap-4">
          <template v-if="abaAtiva === 'panel'">
            <div
              v-if="isLoading"
              class="grid gap-4 sm:grid-cols-2"
              role="status"
              :aria-label="t('RAEVO_AI.OVERVIEW.LOADING')"
            >
              <div
                v-for="index in 2"
                :key="index"
                class="h-64 animate-pulse rounded-xl bg-n-alpha-2"
              />
            </div>

            <section
              v-else-if="isPreparing"
              data-testid="ai-overview-setup"
              class="flex items-start gap-4 rounded-xl border border-n-weak bg-n-solid-1 p-4"
              role="status"
            >
              <span
                class="grid size-9 shrink-0 place-items-center rounded-lg bg-n-blue-3 text-n-blue-11"
              >
                <i class="i-lucide-settings-2 size-4" aria-hidden="true" />
              </span>
              <div>
                <h3 class="text-sm font-semibold text-n-slate-12">
                  {{ t('RAEVO_AI.OVERVIEW.SETUP.TITLE') }}
                </h3>
                <p class="mt-1 text-sm leading-6 text-n-slate-11">
                  {{ t('RAEVO_AI.OVERVIEW.SETUP.DESCRIPTION') }}
                </p>
              </div>
            </section>

            <section
              v-else-if="isDisabled"
              data-testid="ai-overview-disabled"
              class="flex items-start gap-4 rounded-xl border border-n-weak bg-n-solid-1 p-4"
              role="status"
            >
              <span
                class="grid size-9 shrink-0 place-items-center rounded-lg bg-n-amber-3 text-n-amber-11"
              >
                <i class="i-lucide-circle-pause size-4" aria-hidden="true" />
              </span>
              <div>
                <h3 class="text-sm font-semibold text-n-slate-12">
                  {{ t('RAEVO_AI.OVERVIEW.DISABLED.TITLE') }}
                </h3>
                <p class="mt-1 text-sm leading-6 text-n-slate-11">
                  {{ t('RAEVO_AI.OVERVIEW.DISABLED.DESCRIPTION') }}
                </p>
              </div>
            </section>

            <section
              v-else-if="hasError"
              data-testid="ai-overview-error"
              class="flex flex-col items-start gap-4 rounded-xl border border-n-weak bg-n-solid-1 p-4 sm:flex-row sm:items-center sm:justify-between"
              role="alert"
            >
              <div>
                <h3 class="text-sm font-semibold text-n-slate-12">
                  {{ t('RAEVO_AI.OVERVIEW.ERROR.TITLE') }}
                </h3>
                <p class="mt-1 text-sm leading-6 text-n-slate-11">
                  {{ t('RAEVO_AI.OVERVIEW.ERROR.DESCRIPTION') }}
                </p>
              </div>
              <NextButton
                data-testid="ai-overview-retry"
                size="sm"
                variant="faded"
                :label="t('RAEVO_AI.OVERVIEW.ERROR.RETRY')"
                @click="loadOverview"
              />
            </section>

            <div v-else data-testid="ai-overview" class="flex flex-col gap-4">
              <!-- O que precisa de uma pessoa abre o trabalho. Antes vivia na
                   outra aba, abaixo da atividade: quem só abre o Painel nunca
                   o via. -->
              <section
                data-testid="ai-needs-you"
                class="rounded-xl border border-n-weak bg-n-solid-1 p-4"
              >
                <p class="text-micro font-semibold uppercase text-n-slate-10">
                  {{ t('RAEVO_AI.ACTIVITY.EYEBROW') }}
                </p>
                <h3 class="mt-1 text-sm font-semibold text-n-slate-12">
                  {{ needsYouTitle }}
                </h3>

                <p
                  v-if="!needsYouRows.length"
                  class="mt-3 text-sm leading-6 text-n-slate-11"
                >
                  {{ t('RAEVO_AI.ACTIVITY.ATTENTION_EMPTY') }}
                </p>

                <ul v-else class="mt-3 flex list-none flex-col gap-2 p-0">
                  <li
                    v-for="item in needsYouRows"
                    :key="item.id"
                    data-testid="ai-attention-row"
                    class="grid grid-cols-[auto_auto_minmax(0,1fr)_auto_auto] items-center gap-3 rounded-lg border border-n-weak p-2.5"
                  >
                    <span
                      class="w-14 shrink-0 text-right text-micro tabular-nums text-n-slate-10"
                    >
                      {{ item.ago }}
                    </span>
                    <span
                      class="grid size-7 shrink-0 place-items-center rounded-lg"
                      :class="item.tone"
                    >
                      <i :class="item.icon" class="size-4" aria-hidden="true" />
                    </span>
                    <!-- Aqui o desfecho lidera e a acção fica por baixo. Ao
                         contrário do registo, «Agendou uma consulta» com
                         «Falhou» em letra pequena lia-se como se tivesse
                         agendado — e esta é a lista de quem precisa de agir. -->
                    <span class="min-w-0">
                      <strong
                        class="block text-sm font-semibold text-n-slate-12"
                      >
                        {{ item.state }}
                      </strong>
                      <small class="mt-0.5 block text-xs text-n-slate-10">
                        {{ item.label }}
                      </small>
                    </span>
                    <span
                      v-if="item.destino"
                      class="hidden shrink-0 text-xs text-n-slate-10 sm:block"
                    >
                      {{ item.destino }}
                    </span>
                    <NextButton
                      v-if="item.to"
                      size="sm"
                      variant="faded"
                      :label="t('RAEVO_AI.ACTIVITY.OPEN')"
                      @click="abrirRegisto(item)"
                    />
                  </li>
                </ul>

                <p
                  v-if="needsYouRemainder"
                  data-testid="ai-needs-you-remainder"
                  class="mt-3 rounded-lg bg-n-alpha-1 px-3 py-2 text-xs leading-5 text-n-slate-11"
                >
                  {{
                    t('RAEVO_AI.ACTIVITY.ATTENTION_REMAINDER', {
                      count: needsYouRemainder,
                    })
                  }}
                </p>
              </section>

              <div class="grid gap-4 md:grid-cols-2">
                <section
                  data-testid="ai-attendance"
                  class="rounded-xl border border-n-weak bg-n-solid-1 p-4"
                >
                  <p class="text-micro font-semibold uppercase text-n-slate-10">
                    {{ t('RAEVO_AI.ATTENDANCE.EYEBROW') }}
                  </p>
                  <h3 class="mt-1 text-sm font-semibold text-n-slate-12">
                    {{ t('RAEVO_AI.ATTENDANCE.TITLE') }}
                  </h3>

                  <dl
                    class="mt-3 flex flex-col gap-px overflow-hidden rounded-lg bg-n-weak"
                  >
                    <div
                      v-for="item in attendanceMetrics"
                      :key="item.key"
                      class="bg-n-solid-1 px-3 py-2.5"
                    >
                      <dt class="text-xs text-n-slate-10">
                        {{ item.label }}
                      </dt>
                      <dd
                        class="mt-0.5 text-base font-semibold tabular-nums text-n-slate-12"
                      >
                        {{ item.value ?? '—' }}
                        <small
                          v-if="item.caption"
                          class="mt-0.5 block text-micro font-normal text-n-slate-10"
                        >
                          {{ item.caption }}
                        </small>
                        <router-link
                          v-if="item.link"
                          :to="{ ...item.link, params: { accountId } }"
                          class="mt-1 inline-flex text-micro font-semibold text-n-blue-11"
                        >
                          {{ t('RAEVO_AI.ATTENDANCE.OPEN_LIST') }}
                        </router-link>
                      </dd>
                    </div>
                  </dl>

                  <p
                    class="mt-3 rounded-lg bg-n-alpha-1 px-3 py-2 text-xs leading-5 text-n-slate-11"
                  >
                    {{ t('RAEVO_AI.ATTENDANCE.HANDOFF_NOTE') }}
                  </p>
                </section>

                <section
                  data-testid="ai-costs"
                  class="rounded-xl border border-n-weak bg-n-solid-1 p-4"
                >
                  <p class="text-micro font-semibold uppercase text-n-slate-10">
                    {{ t('RAEVO_AI.COSTS.EYEBROW') }}
                  </p>
                  <h3 class="mt-1 text-sm font-semibold text-n-slate-12">
                    {{ t('RAEVO_AI.COSTS.TITLE') }}
                  </h3>

                  <dl
                    class="mt-3 flex flex-col gap-px overflow-hidden rounded-lg bg-n-weak"
                  >
                    <div
                      v-for="item in costMetrics"
                      :key="item.key"
                      class="bg-n-solid-1 px-3 py-2.5"
                    >
                      <dt class="text-xs text-n-slate-10">
                        {{ item.label }}
                      </dt>
                      <dd
                        class="mt-0.5 text-base font-semibold tabular-nums text-n-slate-12"
                      >
                        {{ item.value }}
                        <small
                          v-if="item.caption"
                          class="mt-0.5 block text-micro font-normal text-n-slate-10"
                        >
                          {{ item.caption }}
                        </small>
                      </dd>
                    </div>
                  </dl>

                  <p
                    data-testid="ai-cost-split"
                    class="mt-3 rounded-lg bg-n-alpha-1 px-3 py-2 text-xs leading-5 text-n-slate-11"
                  >
                    {{ t('RAEVO_AI.COSTS.SPLIT', { split: usageCost }) }}
                  </p>
                </section>
              </div>
            </div>
          </template>

          <template v-if="abaAtiva === 'assistant'">
            <section
              data-testid="ai-activity"
              class="rounded-xl border border-n-weak bg-n-solid-1 p-4"
            >
              <p class="text-micro font-semibold uppercase text-n-slate-10">
                {{ t('RAEVO_AI.ACTIVITY.EYEBROW_RECENT') }}
              </p>
              <h3 class="mt-1 text-sm font-semibold text-n-slate-12">
                {{ t('RAEVO_AI.ACTIVITY.RECENT_TITLE') }}
              </h3>

              <p
                v-if="!activity.recent.length"
                class="mt-3 rounded-lg border border-dashed border-n-weak p-4 text-center text-sm text-n-slate-11"
              >
                {{ t('RAEVO_AI.ACTIVITY.RECENT_EMPTY') }}
              </p>

              <ul v-else class="mt-3 flex list-none flex-col gap-2 p-0">
                <li
                  v-for="item in activityRows"
                  :key="item.id"
                  data-testid="ai-activity-item"
                  class="grid grid-cols-[auto_auto_minmax(0,1fr)_auto_auto] items-center gap-3 rounded-lg border border-n-weak p-2.5"
                >
                  <span
                    class="w-14 shrink-0 text-right text-micro tabular-nums text-n-slate-10"
                  >
                    {{ item.ago }}
                  </span>
                  <span
                    class="grid size-7 shrink-0 place-items-center rounded-lg"
                    :class="item.tone"
                  >
                    <i :class="item.icon" class="size-4" aria-hidden="true" />
                  </span>
                  <span class="min-w-0">
                    <strong class="block text-sm font-semibold text-n-slate-12">
                      {{ item.label }}
                    </strong>
                    <small class="mt-0.5 block text-xs text-n-slate-10">
                      {{ item.state }}
                    </small>
                  </span>
                  <span
                    v-if="item.destino"
                    class="hidden shrink-0 text-xs text-n-slate-10 sm:block"
                  >
                    {{ item.destino }}
                  </span>
                  <NextButton
                    v-if="item.to"
                    size="sm"
                    variant="faded"
                    :label="t('RAEVO_AI.ACTIVITY.OPEN')"
                    @click="abrirRegisto(item)"
                  />
                </li>
              </ul>

              <p
                class="mt-3 rounded-lg bg-n-alpha-1 px-3 py-2 text-xs leading-5 text-n-slate-11"
              >
                {{ t('RAEVO_AI.ACTIVITY.PRIVACY_NOTE') }}
              </p>
            </section>

            <section
              data-testid="ai-setup"
              class="rounded-xl border border-n-weak bg-n-solid-1 p-4"
            >
              <p class="text-micro font-semibold uppercase text-n-slate-10">
                {{ t('RAEVO_AI.SETUP.EYEBROW') }}
              </p>
              <h3 class="mt-1 text-sm font-semibold text-n-slate-12">
                {{ t('RAEVO_AI.SETUP.TITLE') }}
              </h3>

              <div class="mt-3 grid gap-4 sm:grid-cols-2">
                <dl class="flex list-none flex-col p-0">
                  <!-- Editável tira o `dt`: o rótulo é do RaevoField, como
                       manda o sistema, e dois rótulos seguidos liam-se
                       «Nome / Nome». -->
                  <div class="border-b border-n-weak py-2">
                    <div v-if="isAdmin">
                      <RaevoField
                        :label="t('RAEVO_AI.SETUP.NAME')"
                        :hint="t('RAEVO_AI.SETUP.NAME_HINT')"
                        :error="nameError || ''"
                      >
                        <template #default="{ controlClass, fieldId }">
                          <input
                            :id="fieldId"
                            v-model="assistantName"
                            data-testid="ai-assistant-name"
                            type="text"
                            maxlength="40"
                            :placeholder="t('RAEVO_AI.SETUP.NAME_PLACEHOLDER')"
                            :disabled="isSavingName"
                            :class="controlClass"
                            @change="saveAssistantName"
                          />
                        </template>
                      </RaevoField>
                    </div>
                    <template v-else>
                      <dt class="text-xs font-medium text-n-slate-10">
                        {{ t('RAEVO_AI.SETUP.NAME') }}
                      </dt>
                      <dd class="mt-1 text-sm font-medium text-n-slate-12">
                        {{ assistantName || t('RAEVO_AI.SETUP.NAME_VALUE') }}
                      </dd>
                    </template>
                  </div>

                  <div
                    v-for="linha in setupRows"
                    :key="linha.key"
                    class="border-b border-n-weak py-2 last:border-b-0"
                  >
                    <dt class="text-xs font-medium text-n-slate-10">
                      {{ linha.label }}
                    </dt>
                    <dd class="mt-1 text-sm font-medium text-n-slate-12">
                      {{ linha.value }}
                      <small
                        v-if="linha.detail"
                        class="mt-1 block text-xs font-normal leading-5 text-n-slate-10"
                      >
                        {{ linha.detail }}
                      </small>
                    </dd>
                  </div>
                </dl>

                <RaevoAiServiceHoursSettings v-if="isAdmin" />
              </div>
            </section>
          </template>

          <RaevoAiKnowledgePanel
            v-if="abaAtiva === 'knowledge'"
            :is-admin="isAdmin"
          />
        </div>
      </div>
    </div>
  </main>
</template>
