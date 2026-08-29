<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import FormRichTextContent from '../../../../public_form/FormRichTextContent.vue';

const props = defineProps({
  editor: { type: Object, required: true },
  activeSectionIndex: { type: Number, default: 0 },
  selectedFieldKey: { type: String, default: '' },
  device: { type: String, default: 'desktop' },
});

const emit = defineEmits(['selectField', 'selectSection']);
const { t } = useI18n();
const requiredMarker = '*';
const previewAnswers = ref({});
const previewDevice = ref(props.device);

const sections = computed(() => props.editor.schema?.sections || []);
const activeSectionIndex = computed(() =>
  sections.value[props.activeSectionIndex] ? props.activeSectionIndex : 0
);
const activeSection = computed(
  () => sections.value[activeSectionIndex.value] || sections.value[0]
);
const brandName = computed(
  () => props.editor.settings?.brand_name || props.editor.name
);

const fieldType = field => {
  if (field.type === 'textarea') return 'textarea';
  if (field.type === 'email') return 'email';
  if (field.type === 'phone') return 'tel';
  if (field.type === 'number' || field.type === 'currency') return 'number';
  if (field.type === 'date') return 'date';
  if (field.type === 'datetime') return 'datetime-local';
  return 'text';
};

const selectField = field => emit('selectField', field.key);
const optionValue = option =>
  typeof option === 'object' ? option.value : option;
const optionLabel = option =>
  typeof option === 'object' ? option.label || option.value : option;
const conditionMatches = (answer, value) =>
  typeof answer === 'boolean' && ['true', 'false'].includes(value)
    ? answer === (value === 'true')
    : answer === value;
const isFieldVisible = field => {
  const condition =
    field.visibleWhen ||
    field.visible_when ||
    (field.visibleWhenField
      ? {
          field: field.visibleWhenField,
          operator: 'equals',
          value: field.visibleWhenValue,
        }
      : null);
  if (!condition) return true;

  return (
    condition.operator === 'equals' &&
    conditionMatches(previewAnswers.value[condition.field], condition.value)
  );
};
const visibleFields = computed(
  () => activeSection.value?.fields?.filter(isFieldVisible) || []
);
const contentBlocks = computed(() => activeSection.value?.content_blocks || []);
const resetPreview = () => {
  previewAnswers.value = {};
};
</script>

<template>
  <section
    data-test="forms-live-preview"
    class="flex min-h-0 flex-col rounded-lg border border-n-slate-4 bg-n-slate-2 p-4"
    :aria-label="t('FORMS.BUILDER.PREVIEW')"
  >
    <div class="mb-4 flex items-center justify-between gap-3">
      <span
        class="text-xs font-semibold uppercase tracking-wide text-n-slate-10"
      >
        {{ t('FORMS.BUILDER.PREVIEW') }}
      </span>
      <div class="flex items-center gap-1 text-xs text-n-slate-10">
        <div
          class="inline-flex rounded border border-n-slate-4 bg-n-solid-1 p-0.5"
          :aria-label="t('FORMS.BUILDER.PREVIEW')"
        >
          <button
            type="button"
            class="inline-flex size-7 items-center justify-center rounded focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-teal-6"
            :class="
              previewDevice === 'desktop'
                ? 'bg-n-teal-3 text-n-teal-11'
                : 'text-n-slate-10 hover:bg-n-slate-3'
            "
            :aria-label="t('FORMS.BUILDER.DESKTOP')"
            :title="t('FORMS.BUILDER.DESKTOP')"
            :aria-pressed="previewDevice === 'desktop'"
            @click="previewDevice = 'desktop'"
          >
            <span class="i-lucide-monitor size-3.5" aria-hidden="true" />
          </button>
          <button
            type="button"
            class="inline-flex size-7 items-center justify-center rounded focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-teal-6"
            :class="
              previewDevice === 'mobile'
                ? 'bg-n-teal-3 text-n-teal-11'
                : 'text-n-slate-10 hover:bg-n-slate-3'
            "
            :aria-label="t('FORMS.BUILDER.MOBILE')"
            :title="t('FORMS.BUILDER.MOBILE')"
            :aria-pressed="previewDevice === 'mobile'"
            @click="previewDevice = 'mobile'"
          >
            <span class="i-lucide-smartphone size-3.5" aria-hidden="true" />
          </button>
        </div>
        <span
          :class="
            previewDevice === 'mobile'
              ? 'i-lucide-smartphone'
              : 'i-lucide-monitor'
          "
          class="size-3.5"
          aria-hidden="true"
        />
        {{
          previewDevice === 'mobile'
            ? t('FORMS.BUILDER.MOBILE')
            : t('FORMS.BUILDER.DESKTOP')
        }}
        <button
          type="button"
          class="ml-1 inline-flex size-7 items-center justify-center rounded hover:bg-n-slate-3 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-teal-6"
          :aria-label="t('FORMS.BUILDER.RESET_PREVIEW')"
          :title="t('FORMS.BUILDER.RESET_PREVIEW')"
          @click="resetPreview"
        >
          <span class="i-lucide-rotate-ccw size-3.5" aria-hidden="true" />
        </button>
      </div>
    </div>

    <div
      class="min-h-0 flex-1 overflow-y-auto rounded-md bg-n-solid-1 p-4 shadow-sm transition-[max-width] duration-200 motion-reduce:transition-none sm:p-7"
      :class="previewDevice === 'mobile' ? 'mx-auto max-w-[24rem]' : 'w-full'"
    >
      <header class="border-b border-n-slate-4 pb-4">
        <p class="text-sm font-semibold text-n-slate-12">{{ brandName }}</p>
        <p class="mt-1 text-xs text-n-slate-10">{{ editor.name }}</p>
      </header>

      <div
        v-if="sections.length > 1"
        class="mt-4 flex gap-2 overflow-x-auto pb-1"
        role="tablist"
        :aria-label="t('FORMS.BUILDER.SECTIONS')"
      >
        <button
          v-for="(section, index) in sections"
          :key="section.key || index"
          type="button"
          class="min-h-9 shrink-0 rounded px-3 text-xs font-medium transition focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-teal-6"
          :class="
            index === activeSectionIndex
              ? 'bg-n-teal-3 text-n-teal-11'
              : 'bg-n-slate-3 text-n-slate-11 hover:bg-n-slate-4'
          "
          role="tab"
          :aria-selected="index === activeSectionIndex"
          :data-test="`forms-preview-section-${index}`"
          @click="emit('selectSection', index)"
        >
          {{ section.title || t('FORMS.BUILDER.UNTITLED_SECTION') }}
        </button>
      </div>

      <div v-if="activeSection" class="mx-auto mt-7 max-w-xl">
        <p class="text-xs font-medium uppercase tracking-wide text-n-teal-11">
          {{
            t('FORMS.BUILDER.STEP', {
              current: activeSectionIndex + 1,
              total: sections.length,
            })
          }}
        </p>
        <h2 class="mt-2 text-2xl font-semibold text-n-slate-12">
          {{ activeSection.title || t('FORMS.BUILDER.UNTITLED_SECTION') }}
        </h2>
        <p
          v-if="activeSection.description || editor.settings?.description"
          class="mt-2 text-sm leading-6 text-n-slate-10"
        >
          {{ activeSection.description || editor.settings?.description }}
        </p>

        <div v-if="contentBlocks.length" class="mt-6 space-y-4">
          <template v-for="block in contentBlocks" :key="block.id">
            <h3
              v-if="block.type === 'heading'"
              class="text-lg font-semibold text-n-slate-12"
            >
              {{ block.content }}
            </h3>
            <p
              v-else-if="
                block.type === 'rich_text' && typeof block.content === 'string'
              "
              class="whitespace-pre-wrap text-sm leading-6 text-n-slate-11"
            >
              {{ block.content }}
            </p>
            <FormRichTextContent
              v-else-if="block.type === 'rich_text'"
              :content="block.content"
            />
            <figure v-else-if="block.type === 'image' && block.url">
              <img
                :src="block.url"
                :alt="block.alt || ''"
                class="max-h-64 w-full rounded object-cover"
              />
              <figcaption
                v-if="block.caption"
                class="mt-2 text-xs text-n-slate-10"
              >
                {{ block.caption }}
              </figcaption>
            </figure>
            <hr v-else-if="block.type === 'divider'" class="border-n-slate-4" />
          </template>
        </div>

        <div v-if="visibleFields.length" class="mt-7 space-y-4">
          <div
            v-for="field in visibleFields"
            :key="field.key"
            class="rounded-md border p-3 transition duration-200 motion-reduce:transition-none"
            :class="
              field.key === selectedFieldKey
                ? 'border-n-teal-8 bg-n-teal-2 ring-1 ring-n-teal-6'
                : 'border-transparent hover:border-n-slate-5'
            "
          >
            <button
              type="button"
              class="w-full text-left focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-teal-6"
              :data-test="`forms-preview-field-${field.key}`"
              :aria-label="
                t('FORMS.BUILDER.SELECT_FIELD', {
                  label: field.label || t('FORMS.BUILDER.UNTITLED_FIELD'),
                })
              "
              @click="selectField(field)"
              @keydown.enter.prevent="selectField(field)"
              @keydown.space.prevent="selectField(field)"
            >
              <span class="block text-sm font-medium text-n-slate-12">
                {{ field.label || t('FORMS.BUILDER.UNTITLED_FIELD') }}
                <span
                  v-if="field.required"
                  class="text-n-ruby-10"
                  aria-hidden="true"
                >
                  {{ requiredMarker }}
                </span>
              </span>
              <span
                v-if="field.helpText || field.help_text"
                class="mt-1 block text-xs leading-5 text-n-slate-10"
              >
                {{ field.helpText || field.help_text }}
              </span>
            </button>

            <div class="mt-2">
              <textarea
                v-if="field.type === 'textarea'"
                :id="`forms-preview-${field.key}`"
                v-model="previewAnswers[field.key]"
                rows="3"
                class="w-full resize-none rounded border border-n-slate-5 bg-n-solid-1 px-3 py-2 text-sm"
                @focus="selectField(field)"
              />
              <select
                v-else-if="['select', 'multi_select'].includes(field.type)"
                :id="`forms-preview-${field.key}`"
                v-model="previewAnswers[field.key]"
                :multiple="field.type === 'multi_select'"
                class="w-full rounded border border-n-slate-5 bg-n-solid-1 px-3 py-2 text-sm text-n-slate-12"
                @focus="selectField(field)"
              >
                <option v-if="field.type === 'select'" value="">
                  {{ t('FORMS.BUILDER.SELECT_PLACEHOLDER') }}
                </option>
                <option
                  v-for="option in field.options || []"
                  :key="optionValue(option)"
                  :value="optionValue(option)"
                >
                  {{ optionLabel(option) }}
                </option>
              </select>
              <label
                v-else-if="['checkbox', 'consent'].includes(field.type)"
                class="flex items-center gap-2 rounded border border-n-slate-5 bg-n-solid-1 px-3 py-2 text-sm text-n-slate-10"
              >
                <input
                  v-model="previewAnswers[field.key]"
                  type="checkbox"
                  class="size-4"
                  @focus="selectField(field)"
                />
                {{ field.label || t('FORMS.BUILDER.UNTITLED_FIELD') }}
              </label>
              <div v-else-if="field.type === 'attachment'">
                <input
                  :id="`forms-preview-${field.key}`"
                  type="file"
                  class="w-full cursor-pointer rounded border border-dashed border-n-slate-5 bg-n-slate-2 px-3 py-2 text-sm text-n-slate-10"
                  @focus="selectField(field)"
                />
              </div>
              <div v-else-if="field.type === 'signature'">
                <input
                  :id="`forms-preview-${field.key}`"
                  v-model="previewAnswers[field.key]"
                  type="text"
                  autocomplete="name"
                  class="w-full border-x-0 border-b border-t-0 border-n-slate-8 bg-transparent px-1 py-2 font-serif text-lg italic text-n-slate-12 outline-none focus:border-n-teal-9 focus:ring-0"
                  @focus="selectField(field)"
                />
                <p class="mt-1 text-xs text-n-slate-10">
                  {{ t('FORMS.EDITOR.SIGNATURE_HINT') }}
                </p>
              </div>
              <input
                v-else
                :id="`forms-preview-${field.key}`"
                v-model="previewAnswers[field.key]"
                :type="fieldType(field)"
                class="w-full rounded border border-n-slate-5 bg-n-solid-1 px-3 py-2 text-sm"
                @focus="selectField(field)"
              />
            </div>
          </div>
        </div>
        <div
          v-else
          class="mt-7 rounded border border-dashed border-n-slate-5 px-4 py-8 text-center text-sm text-n-slate-10"
        >
          {{ t('FORMS.BUILDER.EMPTY_SECTION') }}
        </div>
      </div>
    </div>
  </section>
</template>
