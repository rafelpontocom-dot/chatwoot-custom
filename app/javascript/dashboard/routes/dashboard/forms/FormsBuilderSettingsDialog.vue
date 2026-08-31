<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import FormRichTextEditor from './FormRichTextEditor.vue';
import FormsDesignPanel from './FormsDesignPanel.vue';
import FormsLogicPanel from './FormsLogicPanel.vue';

// A mesma definição serve às duas superfícies. Em `inline` ela é a terceira
// coluna do editor, sempre presente: deixa de haver um modal a tapar o
// formulário que a pessoa está a escrever.
const props = defineProps({
  inline: { type: Boolean, default: false },
  contentBlock: { type: Object, default: null },
  field: { type: Object, default: null },
  section: { type: Object, default: null },
  sectionIndex: { type: Number, default: -1 },
  sectionCount: { type: Number, default: 0 },
  fieldIndex: { type: Number, default: -1 },
  fieldCount: { type: Number, default: 0 },
  fieldTypes: { type: Array, default: () => [] },
  contactMappings: { type: Array, default: () => [] },
  conditionFields: { type: Array, default: () => [] },
  conditionValues: { type: Array, default: () => [] },
  opportunityFields: { type: Array, default: () => [] },
  canMapToCrm: { type: Boolean, default: false },
  isUploadingContentImage: { type: Boolean, default: false },
  fields: { type: Array, default: () => [] },
  logics: { type: Array, default: () => [] },
  variables: { type: Array, default: () => [] },
  endings: { type: Array, default: () => [] },
  hiddenFields: { type: Array, default: () => [] },
  settings: { type: Object, default: () => ({}) },
  formName: { type: String, default: '' },
  brandLogoUrl: { type: String, default: '' },
  isUploadingBrandLogo: { type: Boolean, default: false },
});

const emit = defineEmits([
  'uploadContentImage',
  'removeContentBlock',
  'updateContentBlock',
  'updateField',
  'updateSection',
  'fieldTypeChanged',
  'moveSection',
  'removeSection',
  'moveField',
  'duplicateField',
  'removeField',
  'updateLogics',
  'updateVariables',
  'updateSettings',
  'uploadBrandLogo',
  'removeBrandLogo',
]);

const { t } = useI18n();
const dialog = ref(null);
const dialogTitle = computed(() => {
  if (props.contentBlock) return t('FORMS.CONTENT_BLOCKS.SETTINGS');
  if (props.field) return t('FORMS.BUILDER.QUESTION_SETTINGS');

  return t('FORMS.BUILDER.SETTINGS');
});
// A lógica é de uma pergunta; num bloco de conteúdo ou numa secção não há o
// que condicionar, por isso a aba nem aparece.
const activeTab = ref('question');
const hasLogicTab = computed(() => props.inline && Boolean(props.field));
const showLogic = computed(
  () => hasLogicTab.value && activeTab.value === 'logic'
);
// O design é do formulário inteiro, por isso a aba existe mesmo sem pergunta
// selecionada — ao contrário da lógica, que é sempre de uma pergunta.
const showDesign = computed(() => props.inline && activeTab.value === 'design');

watch(
  () => props.field?.key,
  () => {
    if (!props.field) activeTab.value = 'question';
  }
);

const canRemoveField = computed(() => (props.section?.fields?.length || 0) > 1);
const canRemoveSection = computed(() => props.sectionCount > 1);

const open = () => {
  if (props.inline) return;
  dialog.value?.open();
};
const close = () => dialog.value?.close();
const updateOptions = event => {
  emit('updateField', {
    key: 'options',
    value: event.target.value
      .split('\n')
      .map(option => option.trim())
      .filter(Boolean),
  });
};
const updateContentBlock = (key, value) =>
  emit('updateContentBlock', { key, value });
const updateField = (key, value) => emit('updateField', { key, value });
const updateSection = (key, value) => emit('updateSection', { key, value });
const updateConditionField = value => {
  updateField('visibleWhenField', value);
  updateField('visibleWhenValue', '');
};

defineExpose({ open, close });
</script>

<template>
  <component
    :is="inline ? 'div' : Dialog"
    ref="dialog"
    v-bind="
      inline
        ? {}
        : {
            width: 'lg',
            title: dialogTitle,
            showConfirmButton: false,
            overflowYAuto: true,
          }
    "
    :class="
      inline
        ? 'flex min-h-0 flex-col rounded-xl border border-n-weak bg-n-solid-1'
        : ''
    "
    data-test="forms-builder-settings"
  >
    <div v-if="inline" class="border-b border-n-weak">
      <div v-if="inline" class="flex gap-1 px-3" role="tablist">
        <button
          v-for="tab in [
            { id: 'question', label: t('FORMS.LOGIC.TABS.QUESTION') },
            { id: 'design', label: t('FORMS.LOGIC.TABS.DESIGN') },
            ...(hasLogicTab
              ? [{ id: 'logic', label: t('FORMS.LOGIC.TABS.LOGIC') }]
              : []),
          ]"
          :key="tab.id"
          type="button"
          role="tab"
          class="border-b-2 px-2 py-2.5 text-sm font-semibold outline-none transition"
          :class="
            activeTab === tab.id
              ? 'border-n-slate-12 text-n-slate-12'
              : 'border-transparent text-n-slate-10 hover:text-n-slate-12'
          "
          :aria-selected="activeTab === tab.id"
          :data-test="`forms-settings-tab-${tab.id}`"
          @click="activeTab = tab.id"
        >
          {{ tab.label }}
        </button>
      </div>
      <h2 v-else class="px-4 py-3 text-sm font-semibold text-n-slate-12">
        {{ dialogTitle }}
      </h2>
    </div>
    <div
      class="overflow-y-auto pr-1"
      :class="inline ? 'flex-1 px-4 py-3' : 'max-h-[70vh]'"
    >
      <FormsDesignPanel
        v-if="showDesign"
        :settings="settings"
        :form-name="formName"
        :brand-logo-url="brandLogoUrl"
        :is-uploading-brand-logo="isUploadingBrandLogo"
        @update="emit('updateSettings', $event)"
        @upload-brand-logo="emit('uploadBrandLogo', $event)"
        @remove-brand-logo="emit('removeBrandLogo')"
      />
      <FormsLogicPanel
        v-else-if="showLogic"
        :field="field"
        :fields="fields"
        :logics="logics"
        :variables="variables"
        :endings="endings"
        :hidden-fields="hiddenFields"
        @update-logics="emit('updateLogics', $event)"
        @update-variables="emit('updateVariables', $event)"
      />
      <template v-else>
        <template v-if="contentBlock">
          <h3 v-if="!inline" class="text-sm font-semibold text-n-slate-12">
            {{ t('FORMS.CONTENT_BLOCKS.SETTINGS') }}
          </h3>
          <div class="mt-4 grid gap-4">
            <label
              v-if="contentBlock.type === 'heading'"
              class="grid gap-1.5 text-sm font-medium text-n-slate-11"
            >
              {{ t('FORMS.CONTENT_BLOCKS.HEADING') }}
              <input
                :value="contentBlock.content"
                class="min-h-10 rounded border border-n-slate-5 bg-n-solid-1 px-3 text-n-slate-12 outline-none focus:border-n-teal-9 focus:ring-2 focus:ring-n-teal-6"
                @input="updateContentBlock('content', $event.target.value)"
              />
            </label>
            <FormRichTextEditor
              v-else-if="contentBlock.type === 'rich_text'"
              :model-value="contentBlock.content"
              data-test="forms-rich-text-editor"
              @update:model-value="updateContentBlock('content', $event)"
            />
            <template v-else-if="contentBlock.type === 'image'">
              <img
                v-if="contentBlock.url"
                data-test="forms-content-image-preview"
                :src="contentBlock.url"
                :alt="contentBlock.alt || ''"
                class="max-h-40 w-full rounded border border-n-slate-4 object-cover"
              />
              <div class="grid gap-1.5 text-sm text-n-slate-11">
                <p class="font-medium">
                  {{ t('FORMS.CONTENT_BLOCKS.IMAGE_UPLOAD') }}
                </p>
                <label
                  class="inline-flex min-h-10 w-fit cursor-pointer items-center rounded border border-n-slate-5 bg-n-solid-1 px-3 text-sm font-medium text-n-slate-12 transition hover:bg-n-slate-2 focus-within:ring-2 focus-within:ring-n-teal-6"
                >
                  <input
                    data-test="forms-content-image-upload"
                    type="file"
                    accept="image/png,image/jpeg,image/webp"
                    class="sr-only"
                    :disabled="isUploadingContentImage"
                    @change="emit('uploadContentImage', $event)"
                  />
                  {{
                    isUploadingContentImage
                      ? t('FORMS.CONTENT_BLOCKS.IMAGE_UPLOADING')
                      : t('FORMS.CONTENT_BLOCKS.IMAGE_UPLOAD_ACTION')
                  }}
                </label>
                <p class="text-xs leading-5 text-n-slate-10">
                  {{ t('FORMS.CONTENT_BLOCKS.IMAGE_UPLOAD_HINT') }}
                </p>
              </div>
              <label class="grid gap-1.5 text-sm font-medium text-n-slate-11">
                {{ t('FORMS.CONTENT_BLOCKS.IMAGE_URL') }}
                <input
                  :value="contentBlock.url"
                  data-test="forms-content-image-url"
                  type="url"
                  class="min-h-10 rounded border border-n-slate-5 bg-n-solid-1 px-3 text-n-slate-12 outline-none focus:border-n-teal-9 focus:ring-2 focus:ring-n-teal-6"
                  @input="updateContentBlock('url', $event.target.value)"
                />
              </label>
              <label class="grid gap-1.5 text-sm font-medium text-n-slate-11">
                {{ t('FORMS.CONTENT_BLOCKS.IMAGE_ALT') }}
                <input
                  :value="contentBlock.alt"
                  class="min-h-10 rounded border border-n-slate-5 bg-n-solid-1 px-3 text-n-slate-12 outline-none focus:border-n-teal-9 focus:ring-2 focus:ring-n-teal-6"
                  @input="updateContentBlock('alt', $event.target.value)"
                />
              </label>
              <label class="grid gap-1.5 text-sm font-medium text-n-slate-11">
                {{ t('FORMS.CONTENT_BLOCKS.IMAGE_CAPTION') }}
                <input
                  :value="contentBlock.caption"
                  class="min-h-10 rounded border border-n-slate-5 bg-n-solid-1 px-3 text-n-slate-12 outline-none focus:border-n-teal-9 focus:ring-2 focus:ring-n-teal-6"
                  @input="updateContentBlock('caption', $event.target.value)"
                />
              </label>
            </template>
            <p v-else class="text-sm leading-6 text-n-slate-10">
              {{ t('FORMS.CONTENT_BLOCKS.DIVIDER_DESCRIPTION') }}
            </p>
            <button
              type="button"
              class="inline-flex min-h-9 items-center gap-2 self-start rounded px-2 text-sm font-medium text-n-ruby-11 transition hover:bg-n-ruby-2 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-ruby-6"
              @click="emit('removeContentBlock')"
            >
              <span class="i-lucide-trash-2 size-4" aria-hidden="true" />
              {{ t('FORMS.CONTENT_BLOCKS.REMOVE') }}
            </button>
          </div>
        </template>

        <template v-else-if="field">
          <h3 v-if="!inline" class="text-sm font-semibold text-n-slate-12">
            {{ t('FORMS.BUILDER.QUESTION_SETTINGS') }}
          </h3>
          <div class="mt-4 grid gap-4">
            <label class="grid gap-1.5 text-sm font-medium text-n-slate-11">
              {{ t('FORMS.BUILDER.QUESTION') }}
              <input
                :value="field.label"
                data-test="forms-builder-question-label"
                class="min-h-10 rounded border border-n-slate-5 bg-n-solid-1 px-3 text-n-slate-12 outline-none focus:border-n-teal-9 focus:ring-2 focus:ring-n-teal-6"
                @input="updateField('label', $event.target.value)"
              />
            </label>
            <label class="grid gap-1.5 text-sm font-medium text-n-slate-11">
              {{ t('FORMS.EDITOR.FIELD_TYPE') }}
              <select
                :value="field.type"
                class="min-h-10 rounded border border-n-slate-5 bg-n-solid-1 px-3 text-n-slate-12 outline-none focus:border-n-teal-9 focus:ring-2 focus:ring-n-teal-6"
                @change="emit('fieldTypeChanged', $event.target.value)"
              >
                <option
                  v-for="type in fieldTypes"
                  :key="type.value"
                  :value="type.value"
                >
                  {{ type.label }}
                </option>
              </select>
            </label>
            <label class="grid gap-1.5 text-sm font-medium text-n-slate-11">
              {{ t('FORMS.BUILDER.HELP_TEXT') }}
              <textarea
                :value="field.helpText"
                rows="2"
                class="rounded border border-n-slate-5 bg-n-solid-1 px-3 py-2 text-n-slate-12 outline-none focus:border-n-teal-9 focus:ring-2 focus:ring-n-teal-6"
                @input="updateField('helpText', $event.target.value)"
              />
            </label>
            <label
              v-if="['select', 'multi_select'].includes(field.type)"
              class="grid gap-1.5 text-sm font-medium text-n-slate-11"
            >
              {{ t('FORMS.BUILDER.OPTIONS') }}
              <textarea
                :value="field.options.join('\n')"
                data-test="forms-builder-field-options"
                rows="4"
                class="rounded border border-n-slate-5 bg-n-solid-1 px-3 py-2 text-n-slate-12 outline-none focus:border-n-teal-9 focus:ring-2 focus:ring-n-teal-6"
                @input="updateOptions"
              />
              <span class="text-xs font-normal leading-5 text-n-slate-10">
                {{ t('FORMS.BUILDER.OPTIONS_ONE_PER_LINE') }}
              </span>
            </label>
            <label
              class="flex min-h-10 items-center gap-2 text-sm font-medium text-n-slate-11"
            >
              <input
                :checked="field.required"
                type="checkbox"
                class="size-4 accent-n-teal-9"
                @change="updateField('required', $event.target.checked)"
              />
              {{ t('FORMS.EDITOR.FIELD_REQUIRED') }}
            </label>
            <details
              v-if="canMapToCrm || conditionFields.length"
              class="group rounded border border-n-slate-4 bg-n-slate-2"
            >
              <summary
                class="flex min-h-10 cursor-pointer list-none items-center justify-between gap-3 px-3 text-sm font-medium text-n-slate-11 outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-n-teal-6 [&::-webkit-details-marker]:hidden"
              >
                {{ t('FORMS.BUILDER.ADVANCED') }}
                <span
                  class="i-lucide-chevron-down size-4 text-n-slate-10 transition group-open:rotate-180"
                  aria-hidden="true"
                />
              </summary>
              <div class="grid gap-4 border-t border-n-slate-4 p-3">
                <template v-if="canMapToCrm">
                  <label
                    class="grid gap-1.5 text-sm font-medium text-n-slate-11"
                  >
                    {{ t('FORMS.EDITOR.FIELD_MAPPING') }}
                    <select
                      :value="field.contactTarget"
                      data-test="forms-builder-contact-target"
                      class="min-h-10 rounded border border-n-slate-5 bg-n-solid-1 px-3 text-n-slate-12 outline-none focus:border-n-teal-9 focus:ring-2 focus:ring-n-teal-6"
                      @change="
                        updateField('contactTarget', $event.target.value)
                      "
                    >
                      <option
                        v-for="mapping in contactMappings"
                        :key="mapping.value"
                        :value="mapping.value"
                      >
                        {{ mapping.label }}
                      </option>
                    </select>
                  </label>
                  <label
                    v-if="field.contactTarget === 'custom'"
                    class="grid gap-1.5 text-sm font-medium text-n-slate-11"
                  >
                    {{ t('FORMS.EDITOR.CUSTOM_MAPPING') }}
                    <input
                      :value="field.customAttribute"
                      class="min-h-10 rounded border border-n-slate-5 bg-n-solid-1 px-3 text-n-slate-12 outline-none focus:border-n-teal-9 focus:ring-2 focus:ring-n-teal-6"
                      :placeholder="
                        t('FORMS.EDITOR.CUSTOM_MAPPING_PLACEHOLDER')
                      "
                      @input="
                        updateField('customAttribute', $event.target.value)
                      "
                    />
                  </label>
                  <label
                    v-if="opportunityFields.length || field.opportunityTarget"
                    class="grid gap-1.5 text-sm font-medium text-n-slate-11"
                  >
                    {{ t('FORMS.EDITOR.OPPORTUNITY_MAPPING') }}
                    <select
                      :value="field.opportunityTarget"
                      data-test="forms-builder-opportunity-target"
                      class="min-h-10 rounded border border-n-slate-5 bg-n-solid-1 px-3 text-n-slate-12 outline-none focus:border-n-teal-9 focus:ring-2 focus:ring-n-teal-6"
                      @change="
                        updateField('opportunityTarget', $event.target.value)
                      "
                    >
                      <option value="">
                        {{ t('FORMS.EDITOR.NO_OPPORTUNITY_MAPPING') }}
                      </option>
                      <option
                        v-for="definition in opportunityFields"
                        :key="definition.key"
                        :value="definition.key"
                      >
                        {{ definition.label || definition.key }}
                      </option>
                    </select>
                  </label>
                </template>
                <label
                  v-if="conditionFields.length"
                  class="grid gap-1.5 text-sm font-medium text-n-slate-11"
                >
                  {{ t('FORMS.EDITOR.CONDITION_FIELD') }}
                  <select
                    :value="field.visibleWhenField"
                    data-test="forms-builder-condition-field"
                    class="min-h-10 rounded border border-n-slate-5 bg-n-solid-1 px-3 text-n-slate-12 outline-none focus:border-n-teal-9 focus:ring-2 focus:ring-n-teal-6"
                    @change="updateConditionField($event.target.value)"
                  >
                    <option value="">
                      {{ t('FORMS.EDITOR.CONDITION_NONE') }}
                    </option>
                    <option
                      v-for="conditionField in conditionFields"
                      :key="conditionField.key"
                      :value="conditionField.key"
                    >
                      {{ conditionField.label || conditionField.key }}
                    </option>
                  </select>
                </label>
                <label
                  v-if="field.visibleWhenField"
                  class="grid gap-1.5 text-sm font-medium text-n-slate-11"
                >
                  {{ t('FORMS.EDITOR.CONDITION_VALUE') }}
                  <select
                    v-if="conditionValues.length"
                    :value="field.visibleWhenValue"
                    class="min-h-10 rounded border border-n-slate-5 bg-n-solid-1 px-3 text-n-slate-12 outline-none focus:border-n-teal-9 focus:ring-2 focus:ring-n-teal-6"
                    @change="
                      updateField('visibleWhenValue', $event.target.value)
                    "
                  >
                    <option value="" disabled />
                    <option
                      v-for="option in conditionValues"
                      :key="option.value ?? option"
                      :value="option.value ?? option"
                    >
                      {{ option.label ?? option }}
                    </option>
                  </select>
                  <input
                    v-else
                    :value="field.visibleWhenValue"
                    class="min-h-10 rounded border border-n-slate-5 bg-n-solid-1 px-3 text-n-slate-12 outline-none focus:border-n-teal-9 focus:ring-2 focus:ring-n-teal-6"
                    @input="
                      updateField('visibleWhenValue', $event.target.value)
                    "
                  />
                </label>
              </div>
            </details>
            <div class="flex items-center gap-2 border-t border-n-slate-4 pt-4">
              <button
                type="button"
                class="inline-flex size-9 items-center justify-center rounded text-n-slate-11 transition hover:bg-n-slate-3 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-teal-6 disabled:cursor-not-allowed disabled:opacity-50"
                :aria-label="t('FORMS.ACTIONS.MOVE_UP')"
                :title="t('FORMS.ACTIONS.MOVE_UP')"
                :disabled="fieldIndex <= 0"
                @click="emit('moveField', -1)"
              >
                <span class="i-lucide-arrow-up size-4" aria-hidden="true" />
              </button>
              <button
                type="button"
                class="inline-flex size-9 items-center justify-center rounded text-n-slate-11 transition hover:bg-n-slate-3 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-teal-6 disabled:cursor-not-allowed disabled:opacity-50"
                :aria-label="t('FORMS.ACTIONS.MOVE_DOWN')"
                :title="t('FORMS.ACTIONS.MOVE_DOWN')"
                :disabled="fieldIndex < 0 || fieldIndex === fieldCount - 1"
                @click="emit('moveField', 1)"
              >
                <span class="i-lucide-arrow-down size-4" aria-hidden="true" />
              </button>
              <button
                type="button"
                class="inline-flex min-h-9 items-center gap-2 rounded px-2 text-sm font-medium text-n-slate-11 transition hover:bg-n-slate-3 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-teal-6"
                :aria-label="t('FORMS.BUILDER.DUPLICATE_QUESTION')"
                :title="t('FORMS.BUILDER.DUPLICATE_QUESTION')"
                data-test="forms-builder-duplicate-question"
                @click="emit('duplicateField')"
              >
                <span class="i-lucide-copy size-4" aria-hidden="true" />
                {{ t('FORMS.BUILDER.DUPLICATE') }}
              </button>
              <button
                type="button"
                class="inline-flex min-h-9 items-center gap-2 rounded px-2 text-sm font-medium text-n-ruby-11 transition hover:bg-n-ruby-2 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-ruby-6 disabled:cursor-not-allowed disabled:opacity-50"
                :aria-label="t('FORMS.BUILDER.DELETE_QUESTION')"
                :title="t('FORMS.BUILDER.DELETE_QUESTION')"
                :disabled="!canRemoveField"
                data-test="forms-builder-delete-question"
                @click="emit('removeField')"
              >
                <span class="i-lucide-trash-2 size-4" aria-hidden="true" />
                {{ t('FORMS.ACTIONS.REMOVE') }}
              </button>
            </div>
          </div>
        </template>

        <template v-else-if="section">
          <h3 v-if="!inline" class="text-sm font-semibold text-n-slate-12">
            {{ t('FORMS.BUILDER.SETTINGS') }}
          </h3>
          <div class="mt-4 grid gap-4">
            <label class="grid gap-1.5 text-sm font-medium text-n-slate-11">
              {{ t('FORMS.EDITOR.SECTION_TITLE') }}
              <input
                :value="section.title"
                class="min-h-10 rounded border border-n-slate-5 bg-n-solid-1 px-3 text-n-slate-12 outline-none focus:border-n-teal-9 focus:ring-2 focus:ring-n-teal-6"
                @input="updateSection('title', $event.target.value)"
              />
            </label>
            <label class="grid gap-1.5 text-sm font-medium text-n-slate-11">
              {{ t('FORMS.EDITOR.SECTION_DESCRIPTION') }}
              <textarea
                :value="section.description"
                data-test="forms-builder-section-description"
                rows="3"
                class="rounded border border-n-slate-5 bg-n-solid-1 px-3 py-2 text-n-slate-12 outline-none focus:border-n-teal-9 focus:ring-2 focus:ring-n-teal-6"
                @input="updateSection('description', $event.target.value)"
              />
            </label>
            <label class="grid gap-1.5 text-sm font-medium text-n-slate-11">
              {{ t('FORMS.CONTENT_BLOCKS.LAYOUT') }}
              <select
                :value="section.layout"
                class="min-h-10 rounded border border-n-slate-5 bg-n-solid-1 px-3 text-n-slate-12 outline-none focus:border-n-teal-9 focus:ring-2 focus:ring-n-teal-6"
                @change="updateSection('layout', $event.target.value)"
              >
                <option value="single">
                  {{ t('FORMS.CONTENT_BLOCKS.LAYOUT_SINGLE') }}
                </option>
                <option value="two_columns">
                  {{ t('FORMS.CONTENT_BLOCKS.LAYOUT_TWO_COLUMNS') }}
                </option>
              </select>
            </label>
            <div class="flex items-center gap-2 border-t border-n-slate-4 pt-4">
              <button
                type="button"
                class="inline-flex size-9 items-center justify-center rounded text-n-slate-11 transition hover:bg-n-slate-3 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-teal-6 disabled:cursor-not-allowed disabled:opacity-50"
                :aria-label="t('FORMS.ACTIONS.MOVE_UP')"
                :title="t('FORMS.ACTIONS.MOVE_UP')"
                :disabled="sectionIndex <= 0"
                data-test="forms-builder-move-section-up"
                @click="emit('moveSection', -1)"
              >
                <span class="i-lucide-arrow-up size-4" aria-hidden="true" />
              </button>
              <button
                type="button"
                class="inline-flex size-9 items-center justify-center rounded text-n-slate-11 transition hover:bg-n-slate-3 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-teal-6 disabled:cursor-not-allowed disabled:opacity-50"
                :aria-label="t('FORMS.ACTIONS.MOVE_DOWN')"
                :title="t('FORMS.ACTIONS.MOVE_DOWN')"
                :disabled="
                  sectionIndex < 0 || sectionIndex === sectionCount - 1
                "
                @click="emit('moveSection', 1)"
              >
                <span class="i-lucide-arrow-down size-4" aria-hidden="true" />
              </button>
              <button
                type="button"
                class="inline-flex min-h-9 items-center gap-2 rounded px-2 text-sm font-medium text-n-ruby-11 transition hover:bg-n-ruby-2 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-ruby-6 disabled:cursor-not-allowed disabled:opacity-50"
                :disabled="!canRemoveSection"
                @click="emit('removeSection')"
              >
                <span class="i-lucide-trash-2 size-4" aria-hidden="true" />
                {{ t('FORMS.ACTIONS.REMOVE') }}
              </button>
            </div>
          </div>
        </template>

        <p v-else class="text-sm leading-6 text-n-slate-10">
          {{ t('FORMS.BUILDER.NO_FIELD_SELECTED') }}
        </p>
      </template>
    </div>
  </component>
</template>
