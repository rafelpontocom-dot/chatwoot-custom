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
    class="rounded-xl border border-n-weak bg-n-solid-1 p-4 lg:p-5"
  >
    <div class="flex flex-wrap items-start justify-between gap-3">
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

    <div v-if="isLoading" class="mt-4 grid gap-3 sm:grid-cols-3" role="status">
      <div
        v-for="index in 3"
        :key="index"
        class="h-20 animate-pulse rounded-xl bg-n-alpha-2"
      />
    </div>

    <div
      v-else-if="error"
      data-testid="ai-knowledge-error"
      class="mt-4 flex items-start gap-3 rounded-xl border border-n-ruby-8 bg-n-ruby-2 p-4"
      role="alert"
    >
      <i
        class="i-lucide-circle-alert size-4 shrink-0 text-n-ruby-11"
        aria-hidden="true"
      />
      <p class="text-sm text-n-slate-12">{{ error }}</p>
    </div>

    <template v-else>
      <div
        data-testid="ai-knowledge-coverage"
        class="mt-4 flex items-center gap-3 rounded-xl border border-n-weak bg-n-alpha-1 p-4"
      >
        <span
          class="grid size-9 shrink-0 place-items-center rounded-lg bg-n-blue-3 text-n-blue-11"
        >
          <i class="i-lucide-library size-4" aria-hidden="true" />
        </span>
        <div class="min-w-0">
          <p class="text-micro font-semibold uppercase text-n-slate-10">
            {{ t('RAEVO_AI.KNOWLEDGE.COVERAGE_TITLE') }}
          </p>
          <p class="mt-1 text-sm text-n-slate-12">
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
      </div>

      <div
        v-if="temRascunhoPorPublicar"
        data-testid="ai-knowledge-draft-pending"
        class="mt-3 flex flex-wrap items-center justify-between gap-3 rounded-xl border border-n-amber-8 bg-n-amber-2 p-4"
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
        class="mt-3 rounded-xl border border-n-amber-8 bg-n-solid-1 p-4"
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
        <div class="mt-3 flex flex-wrap gap-2">
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
        class="mt-3 text-sm text-n-teal-11"
        role="status"
      >
        {{ notice }}
      </p>

      <div class="mt-4 grid gap-4 lg:grid-cols-[minmax(0,1fr)_minmax(0,1fr)]">
        <div class="min-w-0">
          <div class="flex flex-wrap gap-2">
            <label class="sr-only" for="knowledge-search">
              {{ t('RAEVO_AI.KNOWLEDGE.SEARCH_PLACEHOLDER') }}
            </label>
            <input
              id="knowledge-search"
              v-model="busca"
              type="search"
              :placeholder="t('RAEVO_AI.KNOWLEDGE.SEARCH_PLACEHOLDER')"
              class="min-w-0 flex-1 rounded-full border border-n-weak bg-n-solid-1 px-3 py-2 text-sm text-n-slate-12"
            />
            <label class="sr-only" for="knowledge-topic">
              {{ t('RAEVO_AI.KNOWLEDGE.FIELD_TOPIC') }}
            </label>
            <select
              id="knowledge-topic"
              v-model="assuntoFiltrado"
              class="rounded-full border border-n-weak bg-n-solid-1 px-3 py-2 text-sm text-n-slate-12"
            >
              <option value="">{{ t('RAEVO_AI.KNOWLEDGE.FILTER_ALL') }}</option>
              <option
                v-for="topic in topics"
                :key="topic.key"
                :value="topic.key"
              >
                {{ topic.label }}
              </option>
            </select>
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

          <ul v-else class="mt-3 flex flex-col gap-2">
            <li v-for="item in itensFiltrados" :key="item.id ?? item.title">
              <button
                type="button"
                class="w-full rounded-xl border border-n-weak bg-n-solid-1 p-3 text-left hover:bg-n-alpha-1"
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
                <span class="mt-1 block text-sm leading-6 text-n-slate-11">
                  {{ item.content }}
                </span>
              </button>
            </li>
          </ul>
        </div>

        <div v-if="emEdicao" data-testid="ai-knowledge-editor" class="min-w-0">
          <div
            class="flex flex-col gap-3 rounded-xl border border-n-weak bg-n-alpha-1 p-4"
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
                :label="t('RAEVO_AI.KNOWLEDGE.SENSITIVE_CANCEL')"
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
          class="mt-2 flex flex-col gap-2"
        >
          <li
            v-for="version in versions"
            :key="version.id"
            class="flex flex-wrap items-center justify-between gap-3 rounded-xl border border-n-weak bg-n-solid-1 p-3"
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
            <NextButton
              v-if="isAdmin && version.status === 'published'"
              size="sm"
              variant="faded"
              :label="t('RAEVO_AI.KNOWLEDGE.ROLLBACK')"
              @click="reporVersao(version.id)"
            />
          </li>
        </ul>
      </div>
    </template>
  </section>
</template>
