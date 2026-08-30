<script setup>
import { computed, nextTick, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';

/**
 * Raevo — construtor de formulário com o canvas em primeiro plano.
 *
 * O editor anterior era uma tela de configuração com uma miniatura do
 * formulário dentro: oito molduras aninhadas, 36% da largura para o conteúdo, e
 * a biblioteca de tipos como porta de entrada — obrigando a escolher o tipo
 * antes de escrever a pergunta.
 *
 * Aqui a ordem é a do Typeform: escreve-se a pergunta no tamanho em que o
 * paciente vai lê-la, e o tipo é aplicado depois, numa faixa que não rouba
 * largura. O avançado (lógica, destino no CRM, consentimento) continua no
 * diálogo de configurações, aberto sob demanda.
 */
const props = defineProps({
  editor: { type: Object, required: true },
  activeSectionIndex: { type: Number, default: 0 },
  selectedFieldKey: { type: String, default: '' },
  fieldTypes: { type: Array, default: () => [] },
});

const emit = defineEmits([
  'selectField',
  'selectSection',
  'addSection',
  'addField',
  'removeField',
  'duplicateField',
  'moveField',
  'openSettings',
]);

const { t } = useI18n();
const questionInput = ref(null);

const sections = computed(() => props.editor.schema?.sections || []);
const sectionIndex = computed(() =>
  sections.value[props.activeSectionIndex] ? props.activeSectionIndex : 0
);
const section = computed(() => sections.value[sectionIndex.value] || null);
const fields = computed(() => section.value?.fields || []);

const currentIndex = computed(() => {
  const found = fields.value.findIndex(
    field => field.key === props.selectedFieldKey
  );
  return found === -1 ? 0 : found;
});
const field = computed(() => fields.value[currentIndex.value] || null);

const typeLabel = value =>
  props.fieldTypes.find(option => option.value === value)?.label || value;

/** O que o paciente digita, na altura real — não uma miniatura. */
const answerKind = computed(() => {
  const type = field.value?.type;
  if (['select', 'multi_select'].includes(type)) return 'choices';
  if (['checkbox', 'consent'].includes(type)) return 'confirm';
  if (type === 'textarea') return 'long';
  if (type === 'signature') return 'signature';
  if (type === 'attachment') return 'attachment';
  return 'line';
});

const answerHint = computed(() => {
  const type = field.value?.type;
  const map = {
    email: 'nome@exemplo.com',
    phone: '+351 000 000 000',
    number: '0',
    currency: '0,00',
    date: 'dd/mm/aaaa',
    datetime: 'dd/mm/aaaa --:--',
  };
  return map[type] || t('FORMS.CANVAS.ANSWER_HINT');
});

const optionLabel = option =>
  typeof option === 'object' ? option.label || option.value : option;

const isChoiceType = type => ['select', 'multi_select'].includes(type);

/**
 * As opções são editadas no canvas, no formato em que já estão gravadas: string
 * continua string; objeto tem só o `label` alterado, porque o `value` é a chave
 * guardada nas respostas já enviadas e trocá-la quebraria o histórico.
 */
const setOption = (index, text) => {
  const options = field.value?.options;
  if (!options || !options[index]) return;
  if (typeof options[index] === 'object') {
    options[index].label = text;
    if (!options[index].value) options[index].value = text;
  } else {
    options[index] = text;
  }
};

const addOption = () => {
  if (!field.value) return;
  if (!Array.isArray(field.value.options)) field.value.options = [];
  field.value.options.push('');
};

const removeOption = index => {
  const options = field.value?.options;
  if (!options || options.length <= 1) return;
  options.splice(index, 1);
};

const applyType = type => {
  if (!field.value) return;
  field.value.type = type;
  // Trocar para um tipo de escolha sem opções deixaria o campo inválido no
  // backend (`selection fields must include options`).
  if (isChoiceType(type) && !(field.value.options || []).length) {
    field.value.options = ['', ''];
  }
};

const duplicateQuestion = () => {
  if (!field.value) return;
  emit('duplicateField', field.value.key);
};

const moveQuestion = direction => {
  const target = currentIndex.value + direction;
  if (target < 0 || target >= fields.value.length) return;
  emit('moveField', { from: currentIndex.value, to: target });
};

const focusQuestion = async () => {
  await nextTick();
  questionInput.value?.focus();
};

const goToField = async index => {
  const target = fields.value[index];
  if (!target) return;
  emit('selectField', target.key);
  await focusQuestion();
};

const onQuestionKeydown = event => {
  if (event.key !== 'Enter' || event.shiftKey) return;
  event.preventDefault();
  if (currentIndex.value < fields.value.length - 1) {
    goToField(currentIndex.value + 1);
  } else {
    emit('addField', field.value?.type || 'text');
  }
};

// A pergunta cresce com o texto: caixa de altura fixa em tipografia grande
// esconde metade da frase.
const autosize = element => {
  if (!element) return;
  element.style.height = 'auto';
  element.style.height = `${element.scrollHeight}px`;
};

watch(
  () => [field.value?.key, field.value?.label],
  () => nextTick(() => autosize(questionInput.value)),
  { immediate: true }
);
</script>

<template>
  <section
    data-test="forms-canvas-editor"
    class="flex min-h-[34rem] flex-col overflow-hidden rounded-xl border border-n-weak bg-n-solid-1"
  >
    <p
      v-if="!section || !field"
      class="flex flex-1 items-center justify-center px-6 text-sm text-n-slate-10"
    >
      {{ t('FORMS.CANVAS.EMPTY') }}
    </p>
    <template v-else>
      <!-- Etapa: título editável no lugar, sem painel intermediário -->
      <div
        class="flex items-center gap-3 border-b border-n-weak px-6 py-3"
        data-test="forms-canvas-section"
      >
        <!--
          Navegar e criar etapa vivem aqui: com a biblioteca recolhida, esses
          controles ficariam inalcançáveis se dependessem só dela.
        -->
        <div class="flex flex-shrink-0 items-center gap-1">
          <button
            type="button"
            data-test="forms-canvas-prev-section"
            class="flex size-7 items-center justify-center rounded-full text-n-slate-10 outline-none hover:bg-n-alpha-2 hover:text-n-slate-12 focus-visible:ring-2 focus-visible:ring-n-brand disabled:opacity-40"
            :disabled="sectionIndex === 0"
            :aria-label="t('FORMS.CANVAS.PREV_SECTION')"
            @click="emit('selectSection', sectionIndex - 1)"
          >
            <i class="i-lucide-chevron-left size-4" aria-hidden="true" />
          </button>
          <span class="whitespace-nowrap text-xs font-medium text-n-slate-10">
            {{
              t('FORMS.CANVAS.SECTION_OF', {
                current: sectionIndex + 1,
                total: sections.length,
              })
            }}
          </span>
          <button
            type="button"
            data-test="forms-canvas-next-section"
            class="flex size-7 items-center justify-center rounded-full text-n-slate-10 outline-none hover:bg-n-alpha-2 hover:text-n-slate-12 focus-visible:ring-2 focus-visible:ring-n-brand disabled:opacity-40"
            :disabled="sectionIndex >= sections.length - 1"
            :aria-label="t('FORMS.CANVAS.NEXT_SECTION')"
            @click="emit('selectSection', sectionIndex + 1)"
          >
            <i class="i-lucide-chevron-right size-4" aria-hidden="true" />
          </button>
        </div>
        <input
          v-model="section.title"
          data-test="forms-canvas-section-title"
          class="reset-base min-w-0 flex-1 rounded-lg border-0 bg-transparent px-2 py-1 text-sm font-semibold text-n-slate-12 outline-none hover:bg-n-alpha-1 focus:bg-n-alpha-1 focus:ring-2 focus:ring-n-brand/30"
          :placeholder="t('FORMS.CANVAS.SECTION_PLACEHOLDER')"
          :aria-label="t('FORMS.CANVAS.SECTION_PLACEHOLDER')"
        />
        <button
          type="button"
          data-test="forms-canvas-add-section"
          class="flex-shrink-0 whitespace-nowrap rounded-full px-3 py-1.5 text-xs font-semibold text-n-slate-11 outline-none hover:bg-n-alpha-2 hover:text-n-slate-12 focus-visible:ring-2 focus-visible:ring-n-brand"
          @click="emit('addSection')"
        >
          {{ t('FORMS.CANVAS.ADD_SECTION') }}
        </button>
        <button
          type="button"
          data-test="forms-canvas-open-settings"
          class="flex size-8 flex-shrink-0 items-center justify-center rounded-full text-n-slate-10 outline-none hover:bg-n-alpha-2 hover:text-n-slate-12 focus-visible:ring-2 focus-visible:ring-n-brand"
          :aria-label="t('FORMS.CANVAS.ADVANCED')"
          :title="t('FORMS.CANVAS.ADVANCED')"
          @click="emit('openSettings')"
        >
          <i class="i-lucide-sliders-horizontal size-4" aria-hidden="true" />
        </button>
      </div>

      <!-- Canvas: a pergunta é editada no tamanho em que será lida -->
      <div class="flex flex-1 flex-col justify-center px-6 py-10 sm:px-10">
        <div class="mx-auto w-full max-w-2xl">
          <p class="mb-3 font-mono text-xs text-n-brand">
            {{
              t('FORMS.CANVAS.QUESTION_OF', {
                current: currentIndex + 1,
                total: fields.length,
              })
            }}
          </p>

          <textarea
            ref="questionInput"
            v-model="field.label"
            rows="1"
            data-test="forms-canvas-question"
            class="reset-base w-full resize-none overflow-hidden border-0 bg-transparent p-0 text-2xl font-semibold leading-tight tracking-tight text-n-slate-12 outline-none placeholder:text-n-slate-9 focus:ring-0 sm:text-3xl"
            :placeholder="t('FORMS.CANVAS.QUESTION_PLACEHOLDER')"
            :aria-label="t('FORMS.CANVAS.QUESTION_PLACEHOLDER')"
            @input="autosize($event.target)"
            @keydown="onQuestionKeydown"
          />

          <input
            v-model="field.helpText"
            data-test="forms-canvas-help"
            class="reset-base mt-2 w-full border-0 bg-transparent p-0 text-base text-n-slate-11 outline-none placeholder:text-n-slate-9 focus:ring-0"
            :placeholder="t('FORMS.CANVAS.HELP_PLACEHOLDER')"
            :aria-label="t('FORMS.CANVAS.HELP_PLACEHOLDER')"
          />

          <!-- Prévia da resposta: é o que o paciente vê, não um retângulo cinza -->
          <div class="mt-8" data-test="forms-canvas-answer">
            <div v-if="answerKind === 'choices'" class="grid max-w-md gap-2">
              <div
                v-for="(option, index) in field.options || []"
                :key="index"
                class="flex items-center gap-2 rounded-lg border border-n-weak bg-n-solid-1 px-3 py-2"
              >
                <span
                  class="flex-shrink-0 rounded border border-n-weak px-1.5 font-mono text-micro text-n-slate-10"
                >
                  {{ String.fromCharCode(65 + index) }}
                </span>
                <input
                  :value="optionLabel(option)"
                  :data-test="`forms-canvas-option-${index}`"
                  class="reset-base min-w-0 flex-1 border-0 bg-transparent px-1 py-1 text-sm text-n-slate-12 outline-none placeholder:text-n-slate-9 focus:ring-0"
                  :placeholder="t('FORMS.CANVAS.OPTION_PLACEHOLDER')"
                  :aria-label="
                    t('FORMS.CANVAS.OPTION_NUMBER', { number: index + 1 })
                  "
                  @input="setOption(index, $event.target.value)"
                />
                <button
                  v-if="(field.options || []).length > 1"
                  type="button"
                  :data-test="`forms-canvas-remove-option-${index}`"
                  class="flex size-6 flex-shrink-0 items-center justify-center rounded-full text-n-slate-10 outline-none hover:bg-n-alpha-2 hover:text-n-slate-12 focus-visible:ring-2 focus-visible:ring-n-brand"
                  :aria-label="t('FORMS.CANVAS.REMOVE_OPTION')"
                  @click="removeOption(index)"
                >
                  <i class="i-lucide-x size-3.5" aria-hidden="true" />
                </button>
              </div>
              <button
                type="button"
                data-test="forms-canvas-add-option"
                class="w-fit rounded-full px-3 py-1.5 text-xs font-semibold text-n-brand outline-none hover:bg-n-blue-3 focus-visible:ring-2 focus-visible:ring-n-brand"
                @click="addOption"
              >
                {{ t('FORMS.CANVAS.ADD_OPTION') }}
              </button>
            </div>

            <div
              v-else-if="answerKind === 'confirm'"
              class="flex max-w-md items-center gap-3 rounded-lg border border-n-weak bg-n-solid-1 px-4 py-3 text-sm text-n-slate-11"
            >
              <span class="size-4 rounded border border-n-strong" />
              {{ field.label || t('FORMS.CANVAS.ANSWER_HINT') }}
            </div>

            <div
              v-else-if="answerKind === 'long'"
              class="max-w-xl rounded-lg border border-n-weak bg-n-solid-1 px-4 py-3 text-base text-n-slate-9"
            >
              {{ t('FORMS.CANVAS.ANSWER_HINT') }}
            </div>

            <div
              v-else-if="
                answerKind === 'signature' || answerKind === 'attachment'
              "
              class="flex max-w-md items-center justify-center rounded-lg border border-dashed border-n-strong px-4 py-8 text-sm text-n-slate-10"
            >
              {{
                answerKind === 'signature'
                  ? t('FORMS.CANVAS.SIGNATURE_HINT')
                  : t('FORMS.CANVAS.ATTACHMENT_HINT')
              }}
            </div>

            <p
              v-else
              class="max-w-md border-b-2 border-n-weak pb-2 text-xl text-n-slate-9"
            >
              {{ answerHint }}
            </p>
          </div>

          <p class="mt-8 font-mono text-xs text-n-slate-10">
            {{ t('FORMS.CANVAS.ENTER_HINT') }}
          </p>
        </div>
      </div>

      <!-- Tipos: faixa de 40px no lugar de uma coluna de 260px -->
      <div
        class="flex flex-wrap items-center gap-1.5 border-t border-n-weak px-6 py-3"
        data-test="forms-canvas-types"
      >
        <span class="me-1 text-xs font-medium text-n-slate-10">
          {{ t('FORMS.CANVAS.ANSWER_TYPE') }}
        </span>
        <button
          v-for="option in fieldTypes"
          :key="option.value"
          type="button"
          :data-test="`forms-canvas-type-${option.value}`"
          class="rounded-full border px-3 py-1 text-xs outline-none focus-visible:ring-2 focus-visible:ring-n-brand"
          :class="
            field.type === option.value
              ? 'border-transparent bg-n-blue-3 font-semibold text-n-brand'
              : 'border-n-weak text-n-slate-11 hover:text-n-slate-12'
          "
          :aria-pressed="field.type === option.value"
          @click="applyType(option.value)"
        >
          {{ option.label }}
        </button>
        <span class="sr-only">{{ typeLabel(field.type) }}</span>
        <label
          class="ms-auto flex flex-shrink-0 cursor-pointer items-center gap-2 whitespace-nowrap text-xs text-n-slate-11"
        >
          <input
            v-model="field.required"
            type="checkbox"
            data-test="forms-canvas-required"
            class="size-4 rounded border-n-strong text-n-brand focus-visible:ring-2 focus-visible:ring-n-brand"
          />
          {{ t('FORMS.CANVAS.REQUIRED') }}
        </label>
      </div>

      <!-- Trilha de perguntas: substitui a árvore "Estrutura do formulário" -->
      <div
        class="flex flex-wrap items-center gap-1.5 border-t border-n-weak px-6 py-3"
        data-test="forms-canvas-rail"
      >
        <div class="flex min-w-0 flex-wrap items-center gap-1.5">
          <button
            v-for="(item, index) in fields"
            :key="item.key"
            type="button"
            :data-test="`forms-canvas-rail-${index}`"
            class="flex size-7 items-center justify-center rounded-full border text-xs tabular-nums outline-none focus-visible:ring-2 focus-visible:ring-n-brand"
            :class="
              index === currentIndex
                ? 'border-transparent bg-n-brand text-white'
                : 'border-n-weak text-n-slate-11 hover:text-n-slate-12'
            "
            :aria-current="index === currentIndex"
            :aria-label="
              item.label ||
              t('FORMS.CANVAS.QUESTION_NUMBER', { number: index + 1 })
            "
            :title="item.label"
            @click="goToField(index)"
          >
            {{ index + 1 }}
          </button>
        </div>
        <div class="ms-auto flex flex-shrink-0 items-center gap-1">
          <button
            v-if="fields.length > 1"
            type="button"
            data-test="forms-canvas-move-up"
            class="flex size-7 items-center justify-center rounded-full text-n-slate-10 outline-none hover:bg-n-alpha-2 hover:text-n-slate-12 focus-visible:ring-2 focus-visible:ring-n-brand disabled:opacity-40"
            :disabled="currentIndex === 0"
            :aria-label="t('FORMS.CANVAS.MOVE_UP')"
            :title="t('FORMS.CANVAS.MOVE_UP')"
            @click="moveQuestion(-1)"
          >
            <i class="i-lucide-arrow-left size-4" aria-hidden="true" />
          </button>
          <button
            v-if="fields.length > 1"
            type="button"
            data-test="forms-canvas-move-down"
            class="flex size-7 items-center justify-center rounded-full text-n-slate-10 outline-none hover:bg-n-alpha-2 hover:text-n-slate-12 focus-visible:ring-2 focus-visible:ring-n-brand disabled:opacity-40"
            :disabled="currentIndex >= fields.length - 1"
            :aria-label="t('FORMS.CANVAS.MOVE_DOWN')"
            :title="t('FORMS.CANVAS.MOVE_DOWN')"
            @click="moveQuestion(1)"
          >
            <i class="i-lucide-arrow-right size-4" aria-hidden="true" />
          </button>
          <button
            type="button"
            data-test="forms-canvas-duplicate-question"
            class="flex size-7 items-center justify-center rounded-full text-n-slate-10 outline-none hover:bg-n-alpha-2 hover:text-n-slate-12 focus-visible:ring-2 focus-visible:ring-n-brand"
            :aria-label="t('FORMS.CANVAS.DUPLICATE_QUESTION')"
            :title="t('FORMS.CANVAS.DUPLICATE_QUESTION')"
            @click="duplicateQuestion"
          >
            <i class="i-lucide-copy size-4" aria-hidden="true" />
          </button>
          <button
            v-if="fields.length > 1"
            type="button"
            data-test="forms-canvas-remove-question"
            class="flex size-7 items-center justify-center rounded-full text-n-slate-10 outline-none hover:bg-n-ruby-3 hover:text-n-ruby-11 focus-visible:ring-2 focus-visible:ring-n-brand"
            :aria-label="t('FORMS.CANVAS.REMOVE_QUESTION')"
            :title="t('FORMS.CANVAS.REMOVE_QUESTION')"
            @click="emit('removeField', field.key)"
          >
            <i class="i-lucide-trash-2 size-4" aria-hidden="true" />
          </button>
          <button
            type="button"
            data-test="forms-canvas-add-question"
            class="rounded-full px-3 py-1.5 text-xs font-semibold text-n-brand outline-none hover:bg-n-blue-3 focus-visible:ring-2 focus-visible:ring-n-brand"
            @click="emit('addField', 'text')"
          >
            {{ t('FORMS.CANVAS.ADD_QUESTION') }}
          </button>
        </div>
      </div>
    </template>
  </section>
</template>
