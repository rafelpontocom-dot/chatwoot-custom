<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import RaevoAiAPI from 'dashboard/api/raevoAi';
import RaevoField from 'dashboard/components-next/raevo/RaevoField.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

// O que a Elis sabe, editável pela clínica.
//
// A regra que manda no ecrã inteiro: EDITAR NÃO PUBLICA. Guardar mexe num
// rascunho; a base que a Elis consulta só muda no botão de publicar. Por isso
// há dois botões e não um, e por isso o aviso de "alterações por publicar"
// existe — sem ele o cliente guardava e ia embora a pensar que estava no ar.

defineProps({
  isAdmin: { type: Boolean, default: false },
});

const { t } = useI18n();

const topics = ref([]);
const published = ref([]);
const draft = ref(null);
const versions = ref([]);
const isLoading = ref(true);
const isSaving = ref(false);
const error = ref(null);
const notice = ref(null);
const busca = ref('');
const assuntoFiltrado = ref('');
const emEdicao = ref(null);
const temasPorConfirmar = ref([]);

const itensVisiveis = computed(() =>
  draft.value ? draft.value.items : published.value
);

const revisao = computed(() => (draft.value ? draft.value.revision : null));

const temRascunhoPorPublicar = computed(() => draft.value !== null);

// A cobertura é o número que ninguém via: um assunto sem conteúdo é
// exactamente o que faz a Elis não saber responder na conversa.
const assuntosCobertos = computed(() => {
  const comConteudo = new Set(itensVisiveis.value.map(item => item.topic_key));
  return topics.value.filter(topic => comConteudo.has(topic.key)).length;
});

const itensFiltrados = computed(() => {
  const termo = busca.value.trim().toLowerCase();
  return itensVisiveis.value.filter(item => {
    const bateAssunto =
      !assuntoFiltrado.value || item.topic_key === assuntoFiltrado.value;
    const bateTermo =
      !termo ||
      item.title.toLowerCase().includes(termo) ||
      item.content.toLowerCase().includes(termo);
    return bateAssunto && bateTermo;
  });
});

// Cobertura por assunto, não só quantos estão preenchidos. Uma pastilha por
// assunto com a contagem: o que está vazio é o que faz a Elis não saber
// responder, e ver isso de relance é o ponto do bloco.
const coberturaPorAssunto = computed(() =>
  topics.value.map(topic => ({
    key: topic.key,
    label: topic.label,
    count: itensVisiveis.value.filter(item => item.topic_key === topic.key)
      .length,
    sensitive: topic.sensitive === true,
  }))
);

const versaoActiva = computed(
  () => versions.value.find(v => v.status === 'published') ?? null
);

const proximaVersao = computed(() => {
  const maior = versions.value.reduce(
    (max, v) => Math.max(max, v.version_number ?? 0),
    0
  );
  return maior + 1;
});

const historico = computed(() =>
  versions.value.filter(v => v.status === 'published')
);

// Filtros em pastilha, como no artefato: todos, só rascunho, ou um assunto.
const filtroActivo = ref('todos');

const filtros = computed(() => [
  { key: 'todos', label: t('RAEVO_AI.KNOWLEDGE.FILTER_ALL') },
  ...coberturaPorAssunto.value
    .filter(a => a.count > 0)
    .map(a => ({ key: a.key, label: a.label })),
]);

const aplicarFiltro = chave => {
  filtroActivo.value = chave;
  assuntoFiltrado.value = chave === 'todos' ? '' : chave;
};

// Os avisos de impacto. Os dois primeiros são reais; o de contradição entre
// itens não existe como serviço — os guardrails de hoje validam a resposta que
// a Elis escreve, não um item de base. Fica visivelmente por implementar em vez
// de fingir que passou.
const avisos = computed(() => {
  if (!emEdicao.value) return [];
  const item = emEdicao.value;
  const tocaAssuntoDelicado =
    topics.value.find(tp => tp.key === item.topic_key)?.sensitive === true;

  return [
    {
      key: 'format',
      state: item.title?.trim() && item.content?.trim() ? 'pass' : 'fail',
      label: t('RAEVO_AI.KNOWLEDGE.CHECK_FORMAT'),
    },
    {
      key: 'contradiction',
      state: 'pending',
      label: t('RAEVO_AI.KNOWLEDGE.CHECK_CONTRADICTION'),
    },
    ...(tocaAssuntoDelicado
      ? [
          {
            key: 'impact',
            state: 'warn',
            label: t('RAEVO_AI.KNOWLEDGE.CHECK_IMPACT'),
          },
        ]
      : []),
  ];
});

const rotuloDoAssunto = chave => {
  const topic = topics.value.find(item => item.key === chave);
  return topic ? topic.label : chave;
};

const carregar = async () => {
  isLoading.value = true;
  error.value = null;
  try {
    const { data } = await RaevoAiAPI.getKnowledge();
    topics.value = data.topics ?? [];
    published.value = data.published ?? [];
    draft.value = data.draft ?? null;
    versions.value = data.versions ?? [];
  } catch {
    error.value = t('RAEVO_AI.KNOWLEDGE.UNAVAILABLE');
  } finally {
    isLoading.value = false;
  }
};

const novoFacto = () => {
  emEdicao.value = {
    id: null,
    topic_key: topics.value[0]?.key ?? '',
    title: '',
    content: '',
    commercial_profile: 'private',
  };
};

const editar = item => {
  emEdicao.value = { ...item };
};

const cancelarEdicao = () => {
  emEdicao.value = null;
};

const guardarRascunho = async () => {
  if (!emEdicao.value) return;
  isSaving.value = true;
  error.value = null;
  notice.value = null;
  try {
    const { data } = await RaevoAiAPI.saveKnowledgeDraft({
      item: emEdicao.value,
      expected_revision: revisao.value,
    });
    draft.value = data.draft;
    emEdicao.value = null;
    notice.value = t('RAEVO_AI.KNOWLEDGE.SAVED');
  } catch (e) {
    error.value =
      e?.response?.status === 409
        ? t('RAEVO_AI.KNOWLEDGE.CONFLICT')
        : t('RAEVO_AI.KNOWLEDGE.INVALID');
  } finally {
    isSaving.value = false;
  }
};

const publicar = async (confirmados = []) => {
  isSaving.value = true;
  error.value = null;
  notice.value = null;
  try {
    await RaevoAiAPI.publishKnowledge({
      expected_revision: revisao.value,
      confirmed_sensitive_keys: confirmados,
    });
    temasPorConfirmar.value = [];
    notice.value = t('RAEVO_AI.KNOWLEDGE.PUBLISHED');
    await carregar();
  } catch (e) {
    // 428 não é falha: é o serviço a dizer o que a clínica ainda não confirmou.
    if (e?.response?.status === 428) {
      temasPorConfirmar.value = e.response.data?.topics ?? [];
    } else if (e?.response?.status === 409) {
      error.value = t('RAEVO_AI.KNOWLEDGE.CONFLICT');
    } else {
      error.value = t('RAEVO_AI.KNOWLEDGE.UNAVAILABLE');
    }
  } finally {
    isSaving.value = false;
  }
};

const reporVersao = async versionId => {
  // Repor apaga a base inteira e reinsere: exige confirmação, ao contrário de
  // publicar, que só troca o que já foi revisto.
  // eslint-disable-next-line no-alert
  if (!window.confirm(t('RAEVO_AI.KNOWLEDGE.ROLLBACK_CONFIRM'))) return;
  isSaving.value = true;
  error.value = null;
  try {
    await RaevoAiAPI.rollbackKnowledge({ version_id: versionId });
    notice.value = t('RAEVO_AI.KNOWLEDGE.ROLLBACK_DONE');
    await carregar();
  } catch {
    error.value = t('RAEVO_AI.KNOWLEDGE.UNAVAILABLE');
  } finally {
    isSaving.value = false;
  }
};

onMounted(carregar);
</script>

<template>
  <section
    data-testid="ai-knowledge"
    class="rounded-xl border border-n-weak bg-n-solid-1 p-4 lg:p-6"
  >
    <div class="flex flex-wrap items-start justify-between gap-4">
      <div class="min-w-0">
        <h2 class="text-base font-semibold text-n-slate-12">
          {{ t('RAEVO_AI.KNOWLEDGE.TITLE') }}
        </h2>
        <p class="mt-1 text-sm leading-6 text-n-slate-11">
          {{ t('RAEVO_AI.KNOWLEDGE.DESCRIPTION') }}
        </p>
      </div>
      <NextButton
        v-if="isAdmin && !isLoading && !error"
        data-testid="ai-knowledge-add"
        size="sm"
        :label="t('RAEVO_AI.KNOWLEDGE.ADD')"
        @click="novoFacto"
      />
    </div>

    <div v-if="isLoading" class="mt-4 grid gap-4 sm:grid-cols-3" role="status">
      <div
        v-for="index in 3"
        :key="index"
        class="h-20 animate-pulse rounded-xl bg-n-alpha-2"
      />
    </div>

    <div
      v-else-if="error"
      data-testid="ai-knowledge-error"
      class="mt-4 flex items-start gap-4 rounded-xl border border-n-ruby-8 bg-n-ruby-2 p-4"
      role="alert"
    >
      <i
        class="i-lucide-circle-alert size-4 shrink-0 text-n-ruby-11"
        aria-hidden="true"
      />
      <p class="text-sm text-n-slate-12">{{ error }}</p>
    </div>

    <template v-else>
      <!-- Editar não publica. É a regra central do artefato, e tem de estar
           visível antes de qualquer campo — não escondida num aviso. -->
      <section
        data-testid="ai-knowledge-versions"
        class="mt-4 rounded-xl border border-n-weak bg-n-solid-1 p-4"
      >
        <p class="text-micro font-semibold uppercase text-n-slate-10">
          {{ t('RAEVO_AI.KNOWLEDGE.VERSIONS_EYEBROW') }}
        </p>
        <h3 class="mt-1 text-sm font-semibold text-n-slate-12">
          {{ t('RAEVO_AI.KNOWLEDGE.VERSIONS_TITLE') }}
        </h3>
        <p class="mt-1 max-w-2xl text-sm leading-6 text-n-slate-11">
          {{ t('RAEVO_AI.KNOWLEDGE.VERSIONS_DESCRIPTION') }}
        </p>

        <div
          class="mt-4 grid gap-px overflow-hidden rounded-xl bg-n-weak sm:grid-cols-2"
        >
          <div class="bg-n-teal-2 p-4">
            <span class="text-micro font-semibold uppercase text-n-slate-10">
              {{ t('RAEVO_AI.KNOWLEDGE.ACTIVE_BASE') }}
            </span>
            <strong class="mt-1 block text-sm font-semibold text-n-slate-12">
              {{
                versaoActiva
                  ? t('RAEVO_AI.KNOWLEDGE.VERSION_NUMBER', {
                      number: versaoActiva.version_number,
                    })
                  : '—'
              }}
            </strong>
            <small
              v-if="versaoActiva"
              class="mt-1 block text-xs text-n-slate-10"
            >
              {{
                t('RAEVO_AI.KNOWLEDGE.PUBLISHED_BY', {
                  who: versaoActiva.published_by || '—',
                })
              }}
            </small>
          </div>

          <div class="flex items-center gap-4 bg-n-solid-1 p-4">
            <span class="min-w-0 flex-1">
              <span class="text-micro font-semibold uppercase text-n-slate-10">
                {{ t('RAEVO_AI.KNOWLEDGE.DRAFT') }}
              </span>
              <strong class="mt-1 block text-sm font-semibold text-n-slate-12">
                {{
                  temRascunhoPorPublicar
                    ? t('RAEVO_AI.KNOWLEDGE.VERSION_NUMBER', {
                        number: proximaVersao,
                      })
                    : t('RAEVO_AI.KNOWLEDGE.NO_DRAFT')
                }}
              </strong>
              <small
                v-if="temRascunhoPorPublicar"
                class="mt-1 block text-xs text-n-slate-10"
              >
                {{ t('RAEVO_AI.KNOWLEDGE.DRAFT_NOT_LIVE') }}
              </small>
            </span>
          </div>
        </div>

        <!-- Cobertura por assunto. Um assunto vazio é o que faz a Elis não
             saber responder, e é isso que a pastilha tracejada mostra. -->
        <div class="mt-4">
          <div class="flex flex-wrap items-baseline justify-between gap-2">
            <p class="text-micro font-semibold uppercase text-n-slate-10">
              {{ t('RAEVO_AI.KNOWLEDGE.COVERAGE_TITLE') }}
            </p>
            <p class="text-xs text-n-slate-10">
              {{
                topics.length
                  ? t('RAEVO_AI.KNOWLEDGE.COVERAGE_SUMMARY', {
                      covered: assuntosCobertos,
                      total: topics.length,
                    })
                  : t('RAEVO_AI.KNOWLEDGE.COVERAGE_EMPTY')
              }}
            </p>
          </div>

          <ul
            data-testid="ai-knowledge-coverage"
            class="mt-2 flex list-none flex-wrap gap-2 p-0"
          >
            <li
              v-for="assunto in coberturaPorAssunto"
              :key="assunto.key"
              data-testid="ai-knowledge-topic"
              class="rounded-full border px-3 py-1 text-xs font-semibold"
              :class="
                assunto.count
                  ? 'border-n-teal-8 bg-n-teal-2 text-n-teal-11'
                  : 'border-dashed border-n-amber-8 bg-n-amber-2 text-n-amber-11'
              "
            >
              {{ assunto.label }}
              <span class="ml-1 font-normal tabular-nums">
                {{ assunto.count || '—' }}
              </span>
            </li>
          </ul>

          <p class="mt-2 text-xs leading-5 text-n-slate-10">
            {{ t('RAEVO_AI.KNOWLEDGE.TAXONOMY_NOTE') }}
          </p>
        </div>
      </section>

      <div
        v-if="temRascunhoPorPublicar"
        data-testid="ai-knowledge-draft-pending"
        class="mt-4 flex flex-wrap items-center justify-between gap-4 rounded-xl border border-n-amber-8 bg-n-amber-2 p-4"
        role="status"
      >
        <span class="flex items-center gap-2 text-sm text-n-slate-12">
          <i
            class="i-lucide-file-pen size-4 text-n-amber-11"
            aria-hidden="true"
          />
          {{ t('RAEVO_AI.KNOWLEDGE.DRAFT_PENDING') }}
        </span>
        <NextButton
          v-if="isAdmin"
          data-testid="ai-knowledge-publish"
          size="sm"
          :is-loading="isSaving"
          :label="t('RAEVO_AI.KNOWLEDGE.PUBLISH')"
          @click="publicar()"
        />
      </div>

      <div
        v-if="temasPorConfirmar.length"
        data-testid="ai-knowledge-sensitive"
        class="mt-4 rounded-xl border border-n-amber-8 bg-n-solid-1 p-4"
        role="alertdialog"
        :aria-label="t('RAEVO_AI.KNOWLEDGE.SENSITIVE_TITLE')"
      >
        <h3 class="text-sm font-semibold text-n-slate-12">
          {{ t('RAEVO_AI.KNOWLEDGE.SENSITIVE_TITLE') }}
        </h3>
        <p class="mt-1 text-sm text-n-slate-11">
          {{ t('RAEVO_AI.KNOWLEDGE.SENSITIVE_DESCRIPTION') }}
        </p>
        <ul class="mt-2 flex flex-wrap gap-2">
          <li
            v-for="tema in temasPorConfirmar"
            :key="tema"
            class="rounded-full bg-n-amber-3 px-3 py-1 text-xs text-n-amber-11"
          >
            {{ rotuloDoAssunto(tema) }}
          </li>
        </ul>
        <div class="mt-4 flex flex-wrap gap-2">
          <NextButton
            data-testid="ai-knowledge-sensitive-confirm"
            size="sm"
            :is-loading="isSaving"
            :label="t('RAEVO_AI.KNOWLEDGE.SENSITIVE_CONFIRM')"
            @click="publicar(temasPorConfirmar)"
          />
          <NextButton
            size="sm"
            variant="faded"
            :label="t('RAEVO_AI.KNOWLEDGE.SENSITIVE_CANCEL')"
            @click="temasPorConfirmar = []"
          />
        </div>
      </div>

      <p
        v-if="notice"
        data-testid="ai-knowledge-notice"
        class="mt-4 text-sm text-n-teal-11"
        role="status"
      >
        {{ notice }}
      </p>

      <div
        class="mt-4 grid gap-4"
        :class="emEdicao ? 'lg:grid-cols-[minmax(0,1fr)_minmax(0,1fr)]' : ''"
      >
        <div class="min-w-0">
          <label class="sr-only" for="knowledge-search">
            {{ t('RAEVO_AI.KNOWLEDGE.SEARCH_PLACEHOLDER') }}
          </label>
          <input
            id="knowledge-search"
            v-model="busca"
            type="search"
            :placeholder="t('RAEVO_AI.KNOWLEDGE.SEARCH_PLACEHOLDER')"
            class="w-full rounded-full border border-n-weak bg-n-solid-1 px-3 py-2 text-sm text-n-slate-12"
          />

          <!-- Filtros em pastilha, como no artefato. O select escondia os
               assuntos atrás de um clique; assim vê-se o que há. -->
          <div
            data-testid="ai-knowledge-filters"
            class="mt-2 flex flex-wrap gap-2"
            role="group"
            :aria-label="t('RAEVO_AI.KNOWLEDGE.FIELD_TOPIC')"
          >
            <button
              v-for="filtro in filtros"
              :key="filtro.key"
              type="button"
              :aria-pressed="filtroActivo === filtro.key"
              class="border border-solid px-3 py-1 text-xs font-semibold"
              :class="
                filtroActivo === filtro.key
                  ? 'border-n-blue-9 bg-n-blue-2 text-n-blue-11'
                  : 'border-n-weak bg-n-solid-1 text-n-slate-11'
              "
              @click="aplicarFiltro(filtro.key)"
            >
              {{ filtro.label }}
            </button>
          </div>

          <p
            v-if="!itensFiltrados.length"
            data-testid="ai-knowledge-empty"
            class="mt-4 rounded-xl border border-n-weak bg-n-alpha-1 p-4 text-sm text-n-slate-11"
          >
            <span class="block font-semibold text-n-slate-12">
              {{ t('RAEVO_AI.KNOWLEDGE.EMPTY_TITLE') }}
            </span>
            {{ t('RAEVO_AI.KNOWLEDGE.EMPTY_DESCRIPTION') }}
          </p>

          <!-- Fora de edição a lista ocupa a largura toda, e uma coluna só dava
               linhas de texto com o dobro da medida legível. Em duas colunas a
               medida volta ao sítio e vê-se o dobro dos factos sem rolar. A
               editar volta a uma coluna, porque o editor ocupa a outra. -->
          <ul
            v-else
            class="mt-4 grid list-none gap-2 p-0"
            :class="emEdicao ? '' : 'lg:grid-cols-2'"
          >
            <li v-for="item in itensFiltrados" :key="item.id ?? item.title">
              <button
                type="button"
                class="raevo-card h-full w-full bg-n-alpha-1 p-4 text-left hover:bg-n-alpha-2"
                @click="editar(item)"
              >
                <span
                  class="text-micro font-semibold uppercase text-n-slate-10"
                >
                  {{ rotuloDoAssunto(item.topic_key) }}
                </span>
                <span class="mt-1 block text-sm font-semibold text-n-slate-12">
                  {{ item.title }}
                </span>
                <!-- Duas linhas, como no artefato: a lista é para percorrer, e
                     um facto comprido despejado por inteiro afogava os outros. -->
                <span
                  class="mt-1 line-clamp-2 block text-sm leading-6 text-n-slate-11"
                >
                  {{ item.content }}
                </span>
              </button>
            </li>
          </ul>
        </div>

        <div v-if="emEdicao" data-testid="ai-knowledge-editor" class="min-w-0">
          <div
            class="flex flex-col gap-4 rounded-xl border border-n-weak bg-n-alpha-1 p-4"
          >
            <RaevoField :label="t('RAEVO_AI.KNOWLEDGE.FIELD_TITLE')">
              <template #default="{ controlClass, fieldId }">
                <input
                  :id="fieldId"
                  v-model="emEdicao.title"
                  type="text"
                  :class="controlClass"
                />
              </template>
            </RaevoField>

            <RaevoField
              :label="t('RAEVO_AI.KNOWLEDGE.FIELD_TOPIC')"
              variant="select"
            >
              <template #default="{ controlClass, fieldId }">
                <select
                  :id="fieldId"
                  v-model="emEdicao.topic_key"
                  :class="controlClass"
                >
                  <option
                    v-for="topic in topics"
                    :key="topic.key"
                    :value="topic.key"
                  >
                    {{ topic.label }}
                  </option>
                </select>
              </template>
            </RaevoField>

            <RaevoField
              :label="t('RAEVO_AI.KNOWLEDGE.FIELD_CONTENT')"
              variant="textarea"
            >
              <template #default="{ controlClass, fieldId }">
                <textarea
                  :id="fieldId"
                  v-model="emEdicao.content"
                  rows="6"
                  :class="controlClass"
                />
              </template>
            </RaevoField>

            <RaevoField :label="t('RAEVO_AI.KNOWLEDGE.FIELD_PROFILE')">
              <template #default="{ controlClass, fieldId }">
                <input
                  :id="fieldId"
                  v-model="emEdicao.commercial_profile"
                  type="text"
                  :class="controlClass"
                />
              </template>
            </RaevoField>

            <!-- Avisos de impacto. Os dois primeiros são reais; o de
                 contradição entre itens não existe como serviço — os guardrails
                 de hoje validam a resposta que a Elis escreve, não um item de
                 base. Fica visivelmente por implementar em vez de fingir que
                 passou, que seria pior. -->
            <ul
              data-testid="ai-knowledge-checks"
              class="mb-3 flex list-none flex-col gap-2 rounded-lg border border-n-amber-8 bg-n-amber-2 p-4"
            >
              <li
                v-for="aviso in avisos"
                :key="aviso.key"
                class="grid grid-cols-[auto_minmax(0,1fr)] items-start gap-2 text-xs leading-5"
              >
                <i
                  class="mt-1 size-3.5"
                  :class="{
                    'i-lucide-check text-n-teal-11': aviso.state === 'pass',
                    'i-lucide-circle-alert text-n-ruby-11':
                      aviso.state === 'fail',
                    'i-lucide-triangle-alert text-n-amber-11':
                      aviso.state === 'warn',
                    'i-lucide-circle-dashed text-n-slate-10':
                      aviso.state === 'pending',
                  }"
                  aria-hidden="true"
                />
                <span class="text-n-slate-12">{{ aviso.label }}</span>
              </li>
            </ul>

            <div class="flex flex-wrap gap-2">
              <NextButton
                data-testid="ai-knowledge-save-draft"
                size="sm"
                :is-loading="isSaving"
                :label="t('RAEVO_AI.KNOWLEDGE.SAVE_DRAFT')"
                @click="guardarRascunho"
              />
              <NextButton
                size="sm"
                variant="faded"
                :label="t('RAEVO_AI.KNOWLEDGE.CANCEL')"
                @click="cancelarEdicao"
              />
            </div>
          </div>
        </div>
      </div>

      <div class="mt-5 border-t border-n-weak pt-4">
        <h3 class="text-sm font-semibold text-n-slate-12">
          {{ t('RAEVO_AI.KNOWLEDGE.HISTORY_TITLE') }}
        </h3>
        <p v-if="!versions.length" class="mt-2 text-sm text-n-slate-11">
          {{ t('RAEVO_AI.KNOWLEDGE.HISTORY_EMPTY') }}
        </p>
        <ul
          v-else
          data-testid="ai-knowledge-versions"
          class="mt-2 flex list-none flex-col gap-2 p-0"
        >
          <li
            v-for="version in historico"
            :key="version.id"
            class="flex flex-wrap items-center justify-between gap-4 rounded-xl border border-n-weak bg-n-solid-1 p-4"
          >
            <div class="min-w-0">
              <p class="text-sm font-semibold text-n-slate-12">
                {{
                  t('RAEVO_AI.KNOWLEDGE.HISTORY_VERSION', {
                    number: version.version_number,
                  })
                }}
              </p>
              <p class="mt-1 text-sm text-n-slate-11">
                {{
                  t('RAEVO_AI.KNOWLEDGE.HISTORY_ITEMS', {
                    count: version.item_count,
                  })
                }}
                <span v-if="version.published_by">
                  {{ `· ${version.published_by}` }}
                </span>
              </p>
            </div>
            <span
              v-if="version.id === versaoActiva?.id"
              data-testid="ai-knowledge-active-tag"
              class="rounded-full bg-n-teal-3 px-2 py-0.5 text-micro font-semibold uppercase text-n-teal-11"
            >
              {{ t('RAEVO_AI.KNOWLEDGE.ACTIVE_TAG') }}
            </span>
            <NextButton
              v-else-if="isAdmin && version.status === 'published'"
              data-testid="ai-knowledge-rollback"
              size="sm"
              variant="faded"
              color="ruby"
              :label="t('RAEVO_AI.KNOWLEDGE.ROLLBACK')"
              @click="reporVersao(version.id)"
            />
          </li>
        </ul>

        <!-- Voltar não é desfazer uma edição: troca a base inteira pelo que
               estava naquela data. O aviso é vermelho de propósito. -->
        <p
          class="mt-4 rounded-lg border border-n-ruby-8 bg-n-ruby-2 px-3 py-2 text-xs leading-5 text-n-ruby-11"
        >
          {{ t('RAEVO_AI.KNOWLEDGE.ROLLBACK_WARNING') }}
        </p>
      </div>
    </template>
  </section>
</template>
