<script setup>
import { computed, nextTick, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { debounce } from '@chatwoot/utils';
import calendarAPI from 'dashboard/api/calendar';
import { useMapGetter } from 'dashboard/composables/store';
import { frontendURL } from 'dashboard/helper/URLHelper';
import KanbanCalendarBookingDialog from '../kanban/KanbanCalendarBookingDialog.vue';
import {
  RAEVO_CONTROL_CLASS,
  RAEVO_SELECT_STANDALONE_CLASS,
} from 'dashboard/components-next/raevo/raevoControl';
import CalendarAppointmentDetailsDialog from './CalendarAppointmentDetailsDialog.vue';
import CalendarEventPopover from './CalendarEventPopover.vue';
import CalendarQuickCreate from './CalendarQuickCreate.vue';

const { t, locale } = useI18n();

// `pt_BR` é o nome do catálogo, não uma etiqueta BCP-47: passá-lo ao `Intl`
// atira "Incorrect locale information provided".
const intlLocale = computed(() =>
  locale.value === 'pt_BR' ? 'pt-BR' : locale.value
);
const route = useRoute() || { query: {} };
const router = useRouter();
const currentAccountId = useMapGetter('getCurrentAccountId');
const selectedDate = ref(new Date());
const view = ref('week');
const appointments = ref([]);
const resources = ref([]);
const selectedStatus = ref('all');
const searchQuery = ref('');
const isLoading = ref(false);
const loadError = ref(false);
const bookingDialog = ref(null);
const appointmentDetailsDialog = ref(null);
const draggedAppointment = ref(null);
// Direção A · o clique num horário vazio abre um balão ancorado, como no
// Google, e não o diálogo inteiro. O diálogo fica atrás de "Mais opções".
const procedures = ref([]);
// Direção A · clicar num agendamento abre um balão ancorado nele, como no
// Google. O diálogo de 543 linhas fica atrás do ⋮, e das duas ações que
// precisam de mais informação: cancelar e remarcar.
const openedAppointment = ref(null);
const eventAnchor = ref(null);
const isChangingStatus = ref(false);
const quickSlot = ref(null);
const quickAnchor = ref(null);

const dateFormatter = computed(
  () =>
    new Intl.DateTimeFormat(intlLocale.value, {
      ...(view.value === 'month'
        ? {}
        : {
            day: 'numeric',
            weekday: view.value === 'week' ? 'long' : undefined,
          }),
      month: 'long',
      year: 'numeric',
    })
);

const dateLabel = computed(() =>
  dateFormatter.value.format(selectedDate.value)
);

const firstVisibleDate = computed(() => {
  const date = new Date(selectedDate.value);
  const weekday = date.getDay();
  date.setDate(date.getDate() - (weekday === 0 ? 6 : weekday - 1));
  date.setHours(0, 0, 0, 0);
  return date;
});

const calendarDays = computed(() => {
  const count = view.value === 'day' ? 1 : 7;
  return Array.from({ length: count }, (_, index) => {
    const date = new Date(
      view.value === 'day' ? selectedDate.value : firstVisibleDate.value
    );
    date.setDate(date.getDate() + index);
    date.setHours(0, 0, 0, 0);
    return date;
  });
});
const monthDays = computed(() => {
  const firstDay = new Date(
    selectedDate.value.getFullYear(),
    selectedDate.value.getMonth(),
    1
  );
  const mondayOffset = (firstDay.getDay() + 6) % 7;
  const firstVisibleDay = new Date(firstDay);
  firstVisibleDay.setDate(firstDay.getDate() - mondayOffset);

  return Array.from({ length: 42 }, (_, index) => {
    const day = new Date(firstVisibleDay);
    day.setDate(firstVisibleDay.getDate() + index);
    return day;
  });
});
const visibleRange = computed(() => {
  const days = view.value === 'month' ? monthDays.value : calendarDays.value;
  const startsAt = new Date(days[0]);
  const endsAt = new Date(days.at(-1));
  endsAt.setDate(endsAt.getDate() + 1);
  return { startsAt, endsAt };
});

const hourSlots = computed(() => {
  const appointmentHours = appointments.value.map(appointment =>
    new Date(appointment.starts_at).getHours()
  );
  // O fim conta, não só o início: uma consulta das 17h que dura duas horas
  // transbordava para fora da grade e a segunda metade não se via.
  //
  // Sem data de fim, a hora sai `NaN` e contamina o `Math.max` — a grade
  // ficava sem uma única linha e a agenda aparecia vazia. Descartar é a
  // resposta certa: a consulta continua a desenhar-se pela hora de início.
  const endHours = appointments.value
    .map(appointment => {
      const endsAt = new Date(appointment.ends_at);
      return endsAt.getMinutes() ? endsAt.getHours() : endsAt.getHours() - 1;
    })
    .filter(Number.isFinite);
  const firstHour = Math.min(8, ...appointmentHours.filter(Number.isFinite));
  const lastHour = Math.max(
    17,
    ...appointmentHours.filter(Number.isFinite),
    ...endHours
  );

  return Array.from(
    { length: lastHour - firstHour + 1 },
    (_, index) => firstHour + index
  );
});
const gridClass = computed(() =>
  view.value === 'day'
    ? 'grid-cols-[4rem_minmax(16rem,1fr)]'
    : 'grid-cols-[4rem_repeat(7,minmax(10rem,1fr))]'
);
// Raevo · Sereno — o estado da consulta se lê pela cor da régua à esquerda,
// não só pelo preenchimento. Ver docs/raevo-design-system.md §2.
const APPOINTMENT_TONES = {
  scheduled: 'border-s-n-slate-9 bg-n-slate-3 hover:bg-n-slate-4',
  confirmed: 'border-s-n-teal-9 bg-n-teal-3 hover:bg-n-teal-4',
  checked_in: 'border-s-n-blue-9 bg-n-blue-3 hover:bg-n-blue-4',
  completed: 'border-s-n-teal-9 bg-n-teal-3 hover:bg-n-teal-4',
  no_show: 'border-s-n-ruby-9 bg-n-ruby-3 hover:bg-n-ruby-4',
  canceled: 'border-s-n-slate-8 bg-n-slate-3 opacity-60 hover:opacity-80',
};
const appointmentToneClass = appointment =>
  APPOINTMENT_TONES[appointment?.status] || APPOINTMENT_TONES.scheduled;

/**
 * A barra lateral leva a cor do procedimento — dado que a configuração já
 * pedia e que não aparecia em lado nenhum. Cancelado perde a cor: um
 * agendamento morto não deve competir por atenção com os vivos.
 */
const appointmentAccent = appointment => {
  const cor = appointment?.procedure?.color;
  if (!cor || appointment.status === 'canceled') return {};
  return { borderInlineStartColor: cor };
};

const calendarStatuses = computed(() => [
  { value: 'scheduled', label: t('CALENDAR.DETAIL.STATUS.SCHEDULED') },
  { value: 'confirmed', label: t('CALENDAR.DETAIL.STATUS.CONFIRMED') },
  { value: 'checked_in', label: t('CALENDAR.DETAIL.STATUS.CHECKED_IN') },
  { value: 'completed', label: t('CALENDAR.DETAIL.STATUS.COMPLETED') },
  { value: 'no_show', label: t('CALENDAR.DETAIL.STATUS.NO_SHOW') },
  { value: 'canceled', label: t('CALENDAR.DETAIL.STATUS.CANCELED') },
]);
const emptyDescription = computed(() =>
  resources.value.length
    ? t('CALENDAR.EMPTY_FILTERED_DESCRIPTION')
    : t('CALENDAR.EMPTY_DESCRIPTION')
);

/**
 * O cabeçalho do mês imprimia a data da primeira semana — "27 Mon", "28 Tue" —
 * em vez do nome do dia. Deriva-se da própria coluna, para nunca desalinhar
 * seja qual for o dia em que a semana começa.
 */
const monthWeekdayLabel = index => {
  const dia = monthDays.value[index];
  if (!dia) return '';
  return new Intl.DateTimeFormat(intlLocale.value, { weekday: 'short' }).format(
    dia
  );
};

const isoDate = date => date.toISOString();

// Direção A · padrão Google. A lateral traz o mini-calendário e as agendas em
// caixas de seleção, como no Google Calendar: todas visíveis por omissão, e
// desmarcar esconde. O filtro por recurso deixa de ser um select de escolha
// única — a API já aceitava `resource_ids` em array.
const miniWeekdayLabels = ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'];

const hiddenResourceIds = ref([]);

const visibleResourceIds = computed(() =>
  resources.value
    .filter(resource => !hiddenResourceIds.value.includes(resource.id))
    .map(resource => resource.id)
);

const isResourceVisible = resource =>
  !hiddenResourceIds.value.includes(resource.id);

const toggleResourceVisibility = resource => {
  hiddenResourceIds.value = isResourceVisible(resource)
    ? [...hiddenResourceIds.value, resource.id]
    : hiddenResourceIds.value.filter(id => id !== resource.id);
};

// Mini-calendário: seis semanas a partir da segunda-feira anterior ao dia 1.
const miniMonthDays = computed(() => {
  const base = new Date(selectedDate.value);
  const first = new Date(base.getFullYear(), base.getMonth(), 1);
  const offset = (first.getDay() + 6) % 7;
  const start = new Date(first);
  start.setDate(first.getDate() - offset);

  return Array.from({ length: 42 }, (_, index) => {
    const day = new Date(start);
    day.setDate(start.getDate() + index);
    return day;
  });
});

const isSameDay = (a, b) =>
  a.getFullYear() === b.getFullYear() &&
  a.getMonth() === b.getMonth() &&
  a.getDate() === b.getDate();

const isToday = day => isSameDay(day, new Date());
const isSelectedDay = day => isSameDay(day, selectedDate.value);
const isOutsideMonth = day => day.getMonth() !== selectedDate.value.getMonth();

const pickMiniDay = day => {
  selectedDate.value = new Date(day);
};

const miniMonthLabel = computed(() =>
  new Intl.DateTimeFormat(intlLocale.value, {
    month: 'long',
    year: 'numeric',
  }).format(selectedDate.value)
);

const loadAppointments = async () => {
  isLoading.value = true;
  loadError.value = false;
  const { startsAt, endsAt } = visibleRange.value;

  try {
    const { data } = await calendarAPI.getAppointments({
      starts_at: isoDate(startsAt),
      ends_at: isoDate(endsAt),
      resource_ids: hiddenResourceIds.value.length
        ? visibleResourceIds.value
        : undefined,
      status:
        selectedStatus.value && selectedStatus.value !== 'all'
          ? selectedStatus.value
          : undefined,
      q: searchQuery.value.trim() || undefined,
    });
    appointments.value = data;
  } catch {
    appointments.value = [];
    loadError.value = true;
  } finally {
    isLoading.value = false;
  }
};

const loadProcedures = async () => {
  try {
    const response = await calendarAPI.getProcedures();
    procedures.value = (response.data || []).filter(item => item.active);
  } catch {
    procedures.value = [];
  }
};

const loadResources = async () => {
  try {
    const response = await calendarAPI.getResources();
    resources.value = (response.data || []).filter(resource => resource.active);
  } catch {
    resources.value = [];
  }
};

/** Meia hora é o que o balão de criação rápida assume quando não há melhor. */
const FALLBACK_DURATION = 30;

/**
 * Nunca menos de um quarto de hora, para o chip não desaparecer — e diz
 * também se a duração é sabida. Sem data de fim desenha-se meia hora, mas
 * isso é um palpite: não serve para decidir esconder texto, senão a falta de
 * um dado apagava o profissional e a situação do cartão.
 */
const durationOf = (appointment, startsAt) => {
  const minutos = (new Date(appointment.ends_at) - startsAt) / 60000;
  const conhecida = Number.isFinite(minutos) && minutos > 0;
  return {
    minutos: conhecida ? Math.max(15, minutos) : FALLBACK_DURATION,
    conhecida,
  };
};

/** Minutos desde a meia-noite — a unidade em que a grade mede tudo. */
const minutesOfDay = date => date.getHours() * 60 + date.getMinutes();

/**
 * Quantas colunas são precisas para o dia, e em qual delas cada consulta cai.
 *
 * Duas consultas que se sobrepõem não podem ocupar o mesmo espaço, senão uma
 * esconde a outra e a agenda mente. O algoritmo é o mesmo do Google: agrupa em
 * blocos de consultas que se tocam, e dentro do bloco dá a cada uma a primeira
 * coluna livre. Todas as consultas do mesmo bloco partilham a largura, para as
 * arestas ficarem alinhadas.
 */
const layoutForDay = day => {
  const doDia = appointments.value
    .filter(appointment => isSameDay(new Date(appointment.starts_at), day))
    .map(appointment => ({
      appointment,
      inicio: minutesOfDay(new Date(appointment.starts_at)),
      fim:
        minutesOfDay(new Date(appointment.starts_at)) +
        durationOf(appointment, new Date(appointment.starts_at)).minutos,
    }))
    .sort((first, second) => first.inicio - second.inicio);

  const posicoes = new Map();
  let bloco = [];
  let fimDoBloco = -1;

  const fecharBloco = () => {
    if (!bloco.length) return;
    const colunas = Math.max(...bloco.map(item => item.coluna)) + 1;
    bloco.forEach(item =>
      posicoes.set(item.appointment.id, { coluna: item.coluna, colunas })
    );
    bloco = [];
    fimDoBloco = -1;
  };

  doDia.forEach(item => {
    // Uma consulta que começa depois de tudo o que veio antes ter acabado
    // abre um bloco novo: não disputa espaço com ninguém.
    if (item.inicio >= fimDoBloco) fecharBloco();

    const ocupadas = new Set(
      bloco.filter(outra => outra.fim > item.inicio).map(outra => outra.coluna)
    );
    let coluna = 0;
    while (ocupadas.has(coluna)) coluna += 1;

    bloco.push({ ...item, coluna });
    fimDoBloco = Math.max(fimDoBloco, item.fim);
  });
  fecharBloco();

  return posicoes;
};

// Altura mínima para uma consulta curta continuar legível: abaixo disto o
// nome do paciente deixa de caber e o alvo fica difícil de acertar.
const MIN_APPOINTMENT_HEIGHT = '1.75rem';

/**
 * As consultas que começam nesta hora, já com a geometria calculada. A altura
 * é proporcional à duração — era o que faltava para a agenda se ler de relance:
 * antes, uma consulta de 50 minutos e uma de duas horas ocupavam o mesmo.
 */
const appointmentsForSlot = (day, hour) => {
  const posicoes = layoutForDay(day);

  return appointments.value
    .filter(appointment => {
      const startsAt = new Date(appointment.starts_at);
      return isSameDay(startsAt, day) && startsAt.getHours() === hour;
    })
    .map(appointment => {
      const startsAt = new Date(appointment.starts_at);
      const { minutos: duracao, conhecida } = durationOf(appointment, startsAt);
      const { coluna = 0, colunas = 1 } = posicoes.get(appointment.id) || {};
      const largura = 100 / colunas;

      return {
        appointment,
        // Abaixo de três quartos de hora não cabem três linhas: mostra-se só a
        // primeira, como o Google faz nos eventos curtos. Cortar texto a meio
        // com `overflow-hidden` seria pior do que não o pôr.
        compacto: conhecida && duracao < 45,
        // Percentagens da própria célula: a célula é uma hora, por isso 150%
        // de altura é hora e meia, seja qual for o zoom do navegador.
        estilo: {
          top: `${(startsAt.getMinutes() / 60) * 100}%`,
          height: `${(duracao / 60) * 100}%`,
          minHeight: MIN_APPOINTMENT_HEIGHT,
          left: `${coluna * largura}%`,
          width: `${largura}%`,
          ...appointmentAccent(appointment),
        },
      };
    });
};
const appointmentsForDay = day =>
  appointments.value.filter(appointment => {
    const startsAt = new Date(appointment.starts_at);
    return (
      startsAt.getFullYear() === day.getFullYear() &&
      startsAt.getMonth() === day.getMonth() &&
      startsAt.getDate() === day.getDate()
    );
  });

const formatDay = day =>
  new Intl.DateTimeFormat(intlLocale.value, {
    weekday: 'short',
    day: 'numeric',
  }).format(day);

const formatTime = value =>
  new Intl.DateTimeFormat(intlLocale.value, {
    hour: '2-digit',
    minute: '2-digit',
  }).format(new Date(value));

const statusLabel = status =>
  ({
    scheduled: t('CALENDAR.DETAIL.STATUS.SCHEDULED'),
    confirmed: t('CALENDAR.DETAIL.STATUS.CONFIRMED'),
    checked_in: t('CALENDAR.DETAIL.STATUS.CHECKED_IN'),
    completed: t('CALENDAR.DETAIL.STATUS.COMPLETED'),
    no_show: t('CALENDAR.DETAIL.STATUS.NO_SHOW'),
    canceled: t('CALENDAR.DETAIL.STATUS.CANCELED'),
  })[status] || status;

const changeDay = amount => {
  const nextDate = new Date(selectedDate.value);
  nextDate.setDate(nextDate.getDate() + amount);
  selectedDate.value = nextDate;
};
const changePeriod = direction => {
  if (view.value === 'month') {
    const nextDate = new Date(selectedDate.value);
    nextDate.setMonth(nextDate.getMonth() + direction);
    selectedDate.value = nextDate;
    return;
  }
  changeDay(view.value === 'week' ? direction * 7 : direction);
};
const isCurrentMonth = day => day.getMonth() === selectedDate.value.getMonth();

const goToToday = () => {
  selectedDate.value = new Date();
};

const openBooking = () => bookingDialog.value?.open();
const startBookingAtSlot = (day, hour, event) => {
  const startsAt = new Date(day);
  startsAt.setHours(hour, 0, 0, 0);

  // Ancorar no clique, sem sair do ecrã.
  const alvo = event?.currentTarget?.getBoundingClientRect?.();
  quickAnchor.value = alvo
    ? {
        top: Math.min(alvo.bottom + 6, window.innerHeight - 340),
        left: Math.min(alvo.left, window.innerWidth - 340),
      }
    : { top: 120, left: 120 };
  quickSlot.value = startsAt;
};

const closeQuickCreate = () => {
  quickSlot.value = null;
};

const openFullDialogFromQuick = () => {
  const startsAt = quickSlot.value;
  closeQuickCreate();
  bookingDialog.value?.open({ startsAt });
};
// A engrenagem passa a levar à página de configuração; o diálogo antigo sai.
const openSettings = () =>
  router.push(
    frontendURL(
      `accounts/${currentAccountId.value}/calendar/settings/procedures`
    )
  );
const openAppointment = (appointment, event) => {
  const alvo = event?.currentTarget?.getBoundingClientRect?.();
  eventAnchor.value = alvo
    ? {
        top: Math.min(alvo.top, window.innerHeight - 320),
        left: Math.min(alvo.right + 8, window.innerWidth - 336),
      }
    : { top: 120, left: 120 };
  openedAppointment.value = appointment;
};

const closeEventPopover = () => {
  openedAppointment.value = null;
};

/** Abre o diálogo com o agendamento que o balão estava a mostrar. */
const openAppointmentDetails = () => {
  const id = openedAppointment.value?.id;
  closeEventPopover();
  appointmentDetailsDialog.value?.open(id);
};

const rescheduleFromPopover = () => {
  const agendamento = openedAppointment.value;
  closeEventPopover();
  appointmentDetailsDialog.value?.openForReschedule(
    agendamento.id,
    new Date(agendamento.starts_at)
  );
};

/**
 * Só as ações que não pedem mais nada ao utilizador acontecem no balão. Quem
 * decide continua a ser o servidor: o balão manda a ação e recarrega o que
 * voltar, sem presumir o novo estado.
 */
const changeAppointmentStatus = async action => {
  const agendamento = openedAppointment.value;
  if (!agendamento || isChangingStatus.value) return;

  isChangingStatus.value = true;
  try {
    await calendarAPI.updateAppointment(agendamento.id, {
      appointment: { action, lock_version: agendamento.lock_version },
    });
    closeEventPopover();
    await loadAppointments();
  } catch (statusError) {
    // O diálogo mostra o motivo da recusa; o balão não tem onde o dizer.
    openAppointmentDetails();
  } finally {
    isChangingStatus.value = false;
  }
};
const openRequestedAppointment = async appointmentId => {
  const id = Number(appointmentId);
  if (!id) return;

  await nextTick();
  appointmentDetailsDialog.value?.open(id);
};
const beginRescheduleDrag = appointment => {
  draggedAppointment.value = appointment;
};
const assistedReschedule = (day, hour) => {
  if (!draggedAppointment.value) return;

  const startsAt = new Date(day);
  const originalStart = new Date(draggedAppointment.value.starts_at);
  startsAt.setHours(hour, originalStart.getMinutes(), 0, 0);
  appointmentDetailsDialog.value?.openForReschedule(
    draggedAppointment.value.id,
    startsAt.toISOString()
  );
  draggedAppointment.value = null;
};
const handleAppointmentCreated = () => loadAppointments();

const debouncedLoadAppointments = debounce(loadAppointments, 250, false);

watch(
  [selectedDate, view, hiddenResourceIds, selectedStatus],
  loadAppointments,
  { deep: true }
);
watch(searchQuery, debouncedLoadAppointments);
watch(() => route.query?.appointmentId, openRequestedAppointment);
onMounted(() => {
  loadAppointments();
  loadResources();
  loadProcedures();
  openRequestedAppointment(route.query?.appointmentId);
});
</script>

<template>
  <main
    data-testid="calendar-workspace"
    class="flex h-full min-h-0 w-full flex-col bg-n-background px-4 py-4 lg:px-6"
  >
    <!--
      Direção A · padrão Google: uma barra só. Criar à esquerda, navegação de
      período, a data como título, e a vista à direita. O cabeçalho anterior
      empilhava título, filtros, busca e período em três faixas.
    -->
    <header
      data-testid="calendar-topbar"
      class="flex items-center gap-3 overflow-x-auto border-b border-n-weak px-4 py-2"
    >
      <button
        type="button"
        data-testid="calendar-new-appointment"
        class="inline-flex items-center gap-2 rounded-full bg-n-brand px-4 py-2 text-sm font-semibold text-white outline-none hover:bg-n-blue-10 focus-visible:ring-2 focus-visible:ring-n-brand focus-visible:ring-offset-2"
        @click="openBooking"
      >
        <i class="i-lucide-plus size-4" aria-hidden="true" />
        {{ t('CALENDAR.NEW_APPOINTMENT') }}
      </button>

      <div
        data-testid="calendar-toolbar-period"
        class="flex shrink-0 items-center gap-1"
      >
        <button
          type="button"
          class="flex size-8 items-center justify-center rounded-full text-n-slate-11 outline-none hover:bg-n-alpha-2 focus-visible:ring-2 focus-visible:ring-n-brand"
          :aria-label="t('CALENDAR.PREVIOUS')"
          :title="t('CALENDAR.PREVIOUS')"
          @click="changePeriod(-1)"
        >
          <i class="i-lucide-chevron-left size-4" aria-hidden="true" />
        </button>
        <button
          type="button"
          class="flex size-8 items-center justify-center rounded-full text-n-slate-11 outline-none hover:bg-n-alpha-2 focus-visible:ring-2 focus-visible:ring-n-brand"
          :aria-label="t('CALENDAR.NEXT')"
          :title="t('CALENDAR.NEXT')"
          @click="changePeriod(1)"
        >
          <i class="i-lucide-chevron-right size-4" aria-hidden="true" />
        </button>
        <button
          type="button"
          class="rounded-full border border-n-weak px-3 py-1.5 text-sm font-medium text-n-slate-12 outline-none hover:bg-n-alpha-2 focus-visible:ring-2 focus-visible:ring-n-brand"
          @click="goToToday"
        >
          {{ t('CALENDAR.TODAY') }}
        </button>
      </div>

      <h1
        data-testid="calendar-date-label"
        class="mb-0 min-w-0 shrink truncate text-xl font-semibold tracking-tight text-n-slate-12"
      >
        {{ dateLabel }}
      </h1>

      <div data-testid="calendar-toolbar-search" class="ms-auto w-56 shrink-0">
        <label class="sr-only" for="calendar-search">
          {{ t('CALENDAR.SEARCH') }}
        </label>
        <input
          id="calendar-search"
          v-model="searchQuery"
          type="search"
          :placeholder="t('CALENDAR.SEARCH_PLACEHOLDER')"
          :class="RAEVO_CONTROL_CLASS"
        />
      </div>

      <label class="sr-only" for="calendar-view-select">
        {{ t('CALENDAR.VIEW') }}
      </label>
      <div class="w-32 shrink-0">
        <select
          id="calendar-view-select"
          v-model="view"
          data-testid="calendar-toolbar-view"
          :class="RAEVO_SELECT_STANDALONE_CLASS"
        >
          <option value="day">{{ t('CALENDAR.DAY') }}</option>
          <option value="week">{{ t('CALENDAR.WEEK') }}</option>
          <option value="month">{{ t('CALENDAR.MONTH') }}</option>
        </select>
      </div>

      <button
        type="button"
        data-testid="calendar-open-settings"
        class="flex size-9 shrink-0 items-center justify-center rounded-full border border-n-weak text-n-slate-11 outline-none hover:bg-n-slate-3 hover:text-n-slate-12 focus-visible:ring-2 focus-visible:ring-n-brand"
        :aria-label="t('CALENDAR.SETTINGS.OPEN')"
        :title="t('CALENDAR.SETTINGS.OPEN')"
        @click="openSettings"
      >
        <i class="i-lucide-settings-2 size-4" aria-hidden="true" />
      </button>
    </header>

    <div class="flex min-h-0 flex-1">
      <!-- Lateral do Google: mini-calendário e as agendas em caixas de seleção -->
      <aside
        data-testid="calendar-sidebar"
        class="hidden w-56 shrink-0 flex-col gap-4 overflow-y-auto border-e border-n-weak px-3 py-3 lg:flex"
      >
        <div>
          <p class="mb-2 text-xs font-semibold capitalize text-n-slate-12">
            {{ miniMonthLabel }}
          </p>
          <div class="grid grid-cols-7 gap-0.5 text-center">
            <span
              v-for="weekday in miniWeekdayLabels"
              :key="weekday"
              class="py-0.5 text-micro text-n-slate-10"
            >
              {{ weekday }}
            </span>
            <button
              v-for="day in miniMonthDays"
              :key="day.toISOString()"
              type="button"
              :data-testid="isToday(day) ? 'calendar-mini-today' : null"
              class="flex size-6 items-center justify-center rounded-full text-micro tabular-nums outline-none hover:bg-n-alpha-2 focus-visible:ring-2 focus-visible:ring-n-brand"
              :class="[
                isSelectedDay(day)
                  ? 'bg-n-brand font-semibold text-white'
                  : isToday(day)
                    ? 'font-semibold text-n-brand'
                    : isOutsideMonth(day)
                      ? 'text-n-slate-9'
                      : 'text-n-slate-11',
              ]"
              :aria-current="isSelectedDay(day) ? 'date' : null"
              @click="pickMiniDay(day)"
            >
              {{ day.getDate() }}
            </button>
          </div>
        </div>

        <div data-testid="calendar-toolbar-filters" class="shrink-0">
          <p class="mb-1.5 text-xs font-semibold text-n-slate-12">
            {{ t('CALENDAR.MY_CALENDARS') }}
          </p>
          <label
            v-for="resource in resources"
            :key="resource.id"
            class="flex cursor-pointer items-center gap-2 rounded-lg px-1 py-1.5 text-xs text-n-slate-11 hover:bg-n-alpha-1"
          >
            <input
              type="checkbox"
              :data-testid="`calendar-resource-${resource.id}`"
              class="size-3.5 rounded border-n-strong text-n-brand focus-visible:ring-2 focus-visible:ring-n-brand"
              :checked="isResourceVisible(resource)"
              @change="toggleResourceVisibility(resource)"
            />
            <span class="min-w-0 truncate">{{ resource.name }}</span>
          </label>
          <p v-if="!resources.length" class="mb-0 px-1 text-xs text-n-slate-10">
            {{ t('CALENDAR.NO_RESOURCES_YET') }}
          </p>
        </div>

        <div class="shrink-0">
          <label
            class="mb-1.5 block text-xs font-semibold text-n-slate-12"
            for="calendar-status-filter"
          >
            {{ t('CALENDAR.STATUS_FILTER') }}
          </label>
          <select
            id="calendar-status-filter"
            v-model="selectedStatus"
            class="w-full"
            :class="RAEVO_SELECT_STANDALONE_CLASS"
          >
            <option value="all">{{ t('CALENDAR.ALL_STATUSES') }}</option>
            <option
              v-for="status in calendarStatuses"
              :key="status.value"
              :value="status.value"
            >
              {{ status.label }}
            </option>
          </select>
        </div>
      </aside>

      <section
        class="relative flex min-h-0 flex-1 overflow-hidden rounded-lg border border-n-weak bg-n-solid-1"
        :aria-label="t('CALENDAR.GRID_LABEL')"
      >
        <div
          v-if="view !== 'month'"
          class="grid w-full overflow-auto"
          :class="gridClass"
        >
          <div
            class="sticky left-0 z-10 border-b border-r border-n-weak bg-n-solid-1"
          />
          <div
            v-for="day in calendarDays"
            :key="day.toISOString()"
            data-testid="calendar-day-column"
            class="min-h-14 border-b border-r border-n-weak bg-n-solid-1 px-3 py-2 last:border-r-0"
          >
            <span class="text-xs font-medium text-n-slate-11">
              {{ formatDay(day) }}
            </span>
          </div>
          <template v-for="hour in hourSlots" :key="hour">
            <div
              class="sticky left-0 z-10 border-b border-r border-n-weak bg-n-solid-1 px-2 py-2 text-right text-xs text-n-slate-11"
            >
              {{ `${hour}:00` }}
            </div>
            <div
              v-for="day in calendarDays"
              :key="`${hour}-${day.toISOString()}`"
              class="relative h-20 border-b border-r border-n-weak bg-n-solid-1 last:border-r-0"
              @dragover.prevent
              @drop="assistedReschedule(day, hour)"
            >
              <button
                type="button"
                data-testid="calendar-slot"
                class="absolute inset-0 z-0 flex items-center justify-center text-lg font-medium text-n-slate-10 opacity-0 outline-none transition-opacity hover:bg-n-slate-2 hover:opacity-100 focus-visible:opacity-100 focus-visible:ring-2 focus-visible:ring-n-brand"
                :aria-label="
                  t('CALENDAR.BOOK_SLOT_LABEL', {
                    time: `${hour}:00`,
                    day: formatDay(day),
                  })
                "
                @click="startBookingAtSlot(day, hour, $event)"
              >
                <i class="i-lucide-plus size-4" aria-hidden="true" />
              </button>
              <button
                v-for="{ appointment, estilo, compacto } in appointmentsForSlot(
                  day,
                  hour
                )"
                :key="appointment.id"
                type="button"
                data-testid="calendar-appointment"
                draggable="true"
                class="raevo-card absolute z-10 flex flex-col overflow-hidden rounded-md border-s-[3px] px-2 py-1 text-left outline-none transition-colors focus-visible:ring-2 focus-visible:ring-n-brand"
                :class="appointmentToneClass(appointment)"
                :style="estilo"
                :aria-label="
                  t('CALENDAR.APPOINTMENT_LABEL', {
                    time: formatTime(appointment.starts_at),
                    contact: appointment.contact.name,
                    procedure: appointment.procedure.name,
                  })
                "
                @click="openAppointment(appointment, $event)"
                @dragstart="beginRescheduleDrag(appointment)"
                @dragend="draggedAppointment = null"
              >
                <span
                  class="block truncate text-xs font-semibold text-n-slate-12"
                >
                  {{
                    t('CALENDAR.APPOINTMENT_CARD_TITLE', {
                      time: formatTime(appointment.starts_at),
                      contact: appointment.contact.name,
                    })
                  }}
                </span>
                <span
                  v-if="!compacto"
                  class="block truncate text-xs text-n-slate-11"
                >
                  {{ appointment.procedure.name }}
                </span>
                <!--
                  Profissional e situação partilham a terceira linha: na largura
                  de uma coluna de semana, pô-los em linhas separadas fazia
                  quatro linhas e cortava o procedimento a meio da palavra.
                -->
                <span
                  v-if="!compacto"
                  class="block truncate text-micro text-n-slate-11"
                >
                  <span
                    v-if="appointment.resources?.length"
                    data-testid="calendar-appointment-resource"
                  >
                    {{
                      appointment.resources
                        .map(resource => resource.name)
                        .join(', ')
                    }}
                    ·
                  </span>
                  <span
                    data-testid="calendar-appointment-status"
                    class="font-medium"
                  >
                    {{ statusLabel(appointment.status) }}
                  </span>
                </span>
              </button>
            </div>
          </template>
        </div>
        <div v-else class="grid w-full grid-cols-7 overflow-auto">
          <div
            v-for="weekday in 7"
            :key="weekday"
            class="border-b border-r border-n-weak bg-n-solid-1 px-2 py-2 text-xs font-medium text-n-slate-11 last:border-r-0"
          >
            {{ monthWeekdayLabel(weekday - 1) }}
          </div>
          <div
            v-for="day in monthDays"
            :key="day.toISOString()"
            data-testid="calendar-month-day"
            class="min-h-28 border-b border-r border-n-weak p-1.5 last:border-r-0"
            :class="isCurrentMonth(day) ? 'bg-n-solid-1' : 'bg-n-surface-2'"
          >
            <span class="mb-1 block text-xs text-n-slate-11">
              {{ day.getDate() }}
            </span>
            <button
              v-for="appointment in appointmentsForDay(day)"
              :key="appointment.id"
              type="button"
              class="mb-1 block w-full truncate rounded border-s-[3px] px-1.5 py-1 text-left text-xs text-n-slate-12 outline-none transition-colors focus-visible:ring-2 focus-visible:ring-n-brand"
              :class="appointmentToneClass(appointment)"
              @click="openAppointment(appointment, $event)"
            >
              {{ formatTime(appointment.starts_at) }}
              {{ appointment.contact.name }}
            </button>
          </div>
        </div>

        <div
          v-if="isLoading"
          class="pointer-events-none absolute inset-0 flex items-center justify-center bg-n-solid-1/80"
        >
          <p class="text-sm text-n-slate-11">{{ t('CALENDAR.LOADING') }}</p>
        </div>
        <div
          v-else-if="loadError"
          class="absolute inset-0 flex items-center justify-center"
        >
          <div
            class="max-w-sm rounded-md border border-n-weak bg-n-solid-1 px-5 py-4 text-center shadow-sm"
          >
            <p class="mb-1 text-sm font-medium text-n-slate-12">
              {{ t('CALENDAR.LOAD_ERROR_TITLE') }}
            </p>
            <button
              type="button"
              class="text-sm font-medium text-n-brand outline-none focus-visible:ring-2 focus-visible:ring-n-brand"
              @click="loadAppointments"
            >
              {{ t('CALENDAR.RETRY') }}
            </button>
          </div>
        </div>
        <div
          v-else-if="appointments.length === 0"
          class="pointer-events-none absolute inset-0 flex items-center justify-center"
        >
          <div
            class="max-w-sm rounded-md border border-n-weak bg-n-solid-1 px-5 py-4 text-center shadow-sm"
          >
            <i
              class="i-lucide-calendar-plus mx-auto mb-2 size-5 text-n-brand"
              aria-hidden="true"
            />
            <p class="mb-1 text-sm font-medium text-n-slate-12">
              {{ t('CALENDAR.EMPTY_TITLE') }}
            </p>
            <p class="mb-0 text-sm text-n-slate-11">
              {{ emptyDescription }}
            </p>
          </div>
        </div>
      </section>
    </div>

    <KanbanCalendarBookingDialog
      ref="bookingDialog"
      select-contact
      @created="handleAppointmentCreated"
    />
    <CalendarQuickCreate
      :starts-at="quickSlot"
      :anchor="quickAnchor"
      :procedures="procedures"
      :resources="resources"
      @close="closeQuickCreate"
      @created="loadAppointments"
      @open-full-dialog="openFullDialogFromQuick"
    />
    <CalendarEventPopover
      :appointment="openedAppointment"
      :anchor="eventAnchor"
      :is-saving="isChangingStatus"
      @close="closeEventPopover"
      @action="changeAppointmentStatus"
      @cancel="openAppointmentDetails"
      @reschedule="rescheduleFromPopover"
      @open-details="openAppointmentDetails"
    />
    <CalendarAppointmentDetailsDialog
      ref="appointmentDetailsDialog"
      @updated="loadAppointments"
    />
  </main>
</template>
