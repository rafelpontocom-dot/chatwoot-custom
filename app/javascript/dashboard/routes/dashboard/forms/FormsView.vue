<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { copyTextToClipboard } from 'shared/helpers/clipboard';
import FormsAPI from 'dashboard/api/forms';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import { getFormStarterSchema } from './starterTemplates';
import { FORM_FIELD_GROUPS, getFormFieldGroup } from './fieldGroups';

const { t } = useI18n();
const store = useStore();
const boards = useMapGetter('kanbanBoards/kanbanBoards');
const inboxes = useMapGetter('inboxes/getAllInboxes');
const templates = ref([]);
const submissions = ref([]);
const activeTab = ref('templates');
const selectedTemplateId = ref(null);
const editor = ref(null);
const isLoading = ref(true);
const isSaving = ref(false);
const isLoadingSubmissions = ref(false);
const error = ref('');
const copied = ref(false);
const createDialog = ref(null);
const submissionDialog = ref(null);
const versionsDialog = ref(null);
const fieldGroupDialog = ref(null);
const duplicateDialog = ref(null);
const selectedSubmission = ref(null);
const versions = ref([]);
const isLoadingVersions = ref(false);
const newTemplate = ref({
  name: '',
  slug: '',
  category: 'lead_capture',
  starter: 'blank',
});
const duplicateForm = ref({ name: '', slug: '' });

const selectedTemplate = computed(() =>
  templates.value.find(template => template.id === selectedTemplateId.value)
);
const isSensitiveHealth = computed(
  () => editor.value?.accessClassification === 'sensitive_health'
);
const selectedBoard = computed(() =>
  boards.value.find(
    board => String(board.id) === String(editor.value?.crmDestination?.boardId)
  )
);
const stageOptions = computed(() => selectedBoard.value?.stages_summary || []);
const selectedBoardCustomFields = computed(
  () => selectedBoard.value?.custom_field_definitions || []
);
const formFields = computed(
  () => editor.value?.schema.sections.flatMap(section => section.fields) || []
);
const publicUrl = computed(() => {
  if (!editor.value?.publicEnabled || !editor.value?.publicToken) return '';

  return `${window.location.origin}/formularios/${editor.value.publicToken}`;
});
const categories = computed(() => [
  { value: 'lead_capture', label: t('FORMS.CATEGORIES.LEAD_CAPTURE') },
  { value: 'pre_consultation', label: t('FORMS.CATEGORIES.PRE_CONSULTATION') },
  { value: 'clinical', label: t('FORMS.CATEGORIES.CLINICAL') },
  { value: 'consent', label: t('FORMS.CATEGORIES.CONSENT') },
  { value: 'other', label: t('FORMS.CATEGORIES.OTHER') },
]);
const starterOptions = computed(() => [
  { value: 'blank', label: t('FORMS.STARTERS.BLANK.TITLE') },
  { value: 'lead_capture', label: t('FORMS.STARTERS.LEAD_CAPTURE.TITLE') },
  {
    value: 'pre_consultation',
    label: t('FORMS.STARTERS.PRE_CONSULTATION.TITLE'),
  },
  {
    value: 'clinical_intake',
    label: t('FORMS.STARTERS.CLINICAL_INTAKE.TITLE'),
  },
]);
const fieldGroupOptions = computed(() =>
  FORM_FIELD_GROUPS.map(group => ({
    id: group,
    ...getFormFieldGroup(group, t),
  }))
);
const fieldTypes = computed(() => [
  { value: 'text', label: t('FORMS.EDITOR.TYPE.TEXT') },
  { value: 'textarea', label: t('FORMS.EDITOR.TYPE.TEXTAREA') },
  { value: 'email', label: t('FORMS.EDITOR.TYPE.EMAIL') },
  { value: 'phone', label: t('FORMS.EDITOR.TYPE.PHONE') },
  { value: 'number', label: t('FORMS.EDITOR.TYPE.NUMBER') },
  { value: 'currency', label: t('FORMS.EDITOR.TYPE.CURRENCY') },
  { value: 'date', label: t('FORMS.EDITOR.TYPE.DATE') },
  { value: 'datetime', label: t('FORMS.EDITOR.TYPE.DATETIME') },
  { value: 'select', label: t('FORMS.EDITOR.TYPE.SELECT') },
  { value: 'multi_select', label: t('FORMS.EDITOR.TYPE.MULTI_SELECT') },
  { value: 'checkbox', label: t('FORMS.EDITOR.TYPE.CHECKBOX') },
  { value: 'consent', label: t('FORMS.EDITOR.TYPE.CONSENT') },
]);
const contactMappings = computed(() => [
  { value: '', label: t('FORMS.EDITOR.NO_MAPPING') },
  { value: 'name', label: t('FORMS.EDITOR.NAME_MAPPING') },
  { value: 'email', label: t('FORMS.EDITOR.EMAIL_MAPPING') },
  { value: 'phone_number', label: t('FORMS.EDITOR.PHONE_MAPPING') },
  { value: 'custom', label: t('FORMS.EDITOR.CUSTOM_MAPPING') },
]);

const clone = value => JSON.parse(JSON.stringify(value));
const slugify = value =>
  value
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');

function defaultField(index = 1) {
  return {
    key: `campo_${index}`,
    label: '',
    helpText: '',
    type: 'text',
    required: false,
    options: [],
    contactTarget: '',
    customAttribute: '',
    opportunityTarget: '',
    visibleWhenField: '',
    visibleWhenValue: '',
  };
}

function defaultSection(index = 1) {
  return {
    key: `etapa_${index}`,
    title: '',
    description: '',
    fields: [defaultField()],
  };
}

function hydrateEditor(template) {
  const schema = clone(
    template.active_version?.schema || { sections: [defaultSection()] }
  );
  const contactMapping = schema.crm_mapping?.contact || {};
  const reverseContactMapping = Object.entries(contactMapping).reduce(
    (result, [target, fieldKey]) => ({ ...result, [fieldKey]: target }),
    {}
  );
  const customMapping = contactMapping.custom_attributes || {};
  const opportunityMapping =
    schema.crm_mapping?.kanban_card?.custom_field_values || {};
  const reverseOpportunityMapping = Object.entries(opportunityMapping).reduce(
    (result, [target, fieldKey]) => ({ ...result, [fieldKey]: target }),
    {}
  );

  schema.sections = (schema.sections || [defaultSection()]).map(section => ({
    ...section,
    fields: (section.fields || []).map(field => {
      const target = reverseContactMapping[field.key];
      const customAttribute = Object.entries(customMapping).find(
        ([, fieldKey]) => fieldKey === field.key
      )?.[0];
      return {
        ...field,
        options: field.options || [],
        helpText: field.help_text || '',
        contactTarget: customAttribute ? 'custom' : target || '',
        customAttribute: customAttribute || '',
        opportunityTarget: reverseOpportunityMapping[field.key] || '',
        visibleWhenField: field.visible_when?.field || '',
        visibleWhenValue: field.visible_when?.value ?? '',
      };
    }),
  }));

  const destination = schema.crm_destination || {};
  editor.value = {
    id: template.id,
    name: template.name,
    slug: template.slug,
    category: template.category,
    accessClassification: template.access_classification,
    publicEnabled:
      template.access_classification === 'sensitive_health'
        ? false
        : template.public_enabled,
    publicToken: template.public_token,
    settings: {
      locale: template.settings?.locale || 'pt_BR',
      description: template.settings?.description || '',
      brand_name: template.settings?.brand_name || '',
      theme: template.settings?.theme || 'calm',
    },
    schema,
    crmDestinationEnabled: Boolean(destination.kanban_board_id),
    crmDestination: {
      boardId: destination.kanban_board_id || '',
      stageId: destination.kanban_stage_id || '',
      inboxId: destination.inbox_id || '',
      policy: destination.opportunity_policy || 'reuse_open',
    },
  };
}

function selectTemplate(template) {
  selectedTemplateId.value = template.id;
  hydrateEditor(template);
  activeTab.value = 'templates';
  error.value = '';
}

function normalizedConditionValue(field) {
  const source = formFields.value.find(
    candidate => candidate.key === field.visibleWhenField
  );
  if (!['checkbox', 'consent'].includes(source?.type)) {
    return field.visibleWhenValue;
  }

  return field.visibleWhenValue === true || field.visibleWhenValue === 'true';
}

function buildSchema() {
  const schema = clone(editor.value.schema);
  const contact = {};
  const customAttributes = {};
  const opportunityCustomFields = {};

  schema.sections = schema.sections.map(section => {
    const { description, ...publishedSection } = section;
    return {
      ...publishedSection,
      ...(description?.trim() ? { description: description.trim() } : {}),
      fields: section.fields.map(field => {
        if (
          !isSensitiveHealth.value &&
          field.contactTarget === 'custom' &&
          field.customAttribute.trim()
        ) {
          customAttributes[field.customAttribute.trim()] = field.key;
        } else if (!isSensitiveHealth.value && field.contactTarget) {
          contact[field.contactTarget] = field.key;
        }
        if (
          !isSensitiveHealth.value &&
          editor.value.crmDestinationEnabled &&
          field.opportunityTarget
        ) {
          opportunityCustomFields[field.opportunityTarget] = field.key;
        }
        const {
          contactTarget,
          customAttribute,
          opportunityTarget,
          helpText,
          visibleWhenField,
          visibleWhenValue,
          ...publishedField
        } = field;
        if (helpText.trim()) publishedField.help_text = helpText.trim();
        else delete publishedField.help_text;
        return {
          ...publishedField,
          options: ['select', 'multi_select'].includes(publishedField.type)
            ? publishedField.options.filter(Boolean)
            : [],
          ...(visibleWhenField
            ? {
                visible_when: {
                  field: visibleWhenField,
                  operator: 'equals',
                  value: normalizedConditionValue(field),
                },
              }
            : {}),
        };
      }),
    };
  });

  if (Object.keys(customAttributes).length)
    contact.custom_attributes = customAttributes;
  const crmMapping = {};
  if (Object.keys(contact).length) crmMapping.contact = contact;
  if (Object.keys(opportunityCustomFields).length) {
    crmMapping.kanban_card = { custom_field_values: opportunityCustomFields };
  }
  if (Object.keys(crmMapping).length) schema.crm_mapping = crmMapping;
  else delete schema.crm_mapping;

  if (!isSensitiveHealth.value && editor.value.crmDestinationEnabled) {
    schema.crm_destination = {
      kanban_board_id: Number(editor.value.crmDestination.boardId),
      kanban_stage_id: Number(editor.value.crmDestination.stageId),
      inbox_id: Number(editor.value.crmDestination.inboxId),
      opportunity_policy: editor.value.crmDestination.policy,
    };
  } else {
    delete schema.crm_destination;
  }

  return schema;
}

function fieldIsValid(field) {
  if (!field.key.trim() || !field.label.trim()) return false;
  if (
    ['select', 'multi_select'].includes(field.type) &&
    !field.options.filter(Boolean).length
  ) {
    return false;
  }
  if (!field.visibleWhenField) return true;

  const source = formFields.value.find(
    candidate => candidate.key === field.visibleWhenField
  );
  const hasConditionValue =
    field.visibleWhenValue !== '' &&
    field.visibleWhenValue !== null &&
    field.visibleWhenValue !== undefined;

  return Boolean(source && hasConditionValue);
}

const opportunityFieldTypes = {
  text: ['text', 'textarea', 'url'],
  textarea: ['text', 'textarea'],
  email: ['text', 'textarea'],
  phone: ['text', 'textarea'],
  number: ['integer', 'decimal', 'currency'],
  currency: ['decimal', 'currency'],
  date: ['date'],
  datetime: ['datetime'],
  select: ['select'],
  multi_select: ['multiselect'],
  checkbox: ['boolean'],
  consent: ['boolean'],
};

function opportunityFieldOptions(field) {
  const compatibleTypes = opportunityFieldTypes[field.type] || [];
  return selectedBoardCustomFields.value.filter(definition => {
    if (definition.key === field.opportunityTarget) return true;
    if (!compatibleTypes.includes(definition.field_type)) return false;
    if (!['select', 'multi_select'].includes(field.type)) return true;

    return field.options.every(option =>
      (definition.options || []).includes(option)
    );
  });
}

function opportunityMappingIsValid(field) {
  if (!editor.value.crmDestinationEnabled || !field.opportunityTarget) {
    return true;
  }

  return opportunityFieldOptions(field).some(
    definition => definition.key === field.opportunityTarget
  );
}

function editorIsValid() {
  return Boolean(
    editor.value?.name.trim() &&
      editor.value.slug.trim() &&
      editor.value.schema.sections.length &&
      editor.value.schema.sections.every(
        section =>
          section.key.trim() &&
          section.fields.every(
            field => fieldIsValid(field) && opportunityMappingIsValid(field)
          )
      ) &&
      (!editor.value.crmDestinationEnabled ||
        (editor.value.crmDestination.boardId &&
          editor.value.crmDestination.stageId &&
          editor.value.crmDestination.inboxId))
  );
}

async function loadTemplates() {
  isLoading.value = true;
  error.value = '';
  try {
    const { data } = await FormsAPI.getTemplates();
    templates.value = data;
    if (!selectedTemplateId.value && data[0]) selectTemplate(data[0]);
  } catch (loadError) {
    error.value = loadError.response?.data?.message || t('FORMS.ERROR.LOAD');
  } finally {
    isLoading.value = false;
  }
}

async function loadSubmissions() {
  isLoadingSubmissions.value = true;
  error.value = '';
  try {
    const { data } = await FormsAPI.getSubmissions();
    submissions.value = data;
  } catch (loadError) {
    error.value = loadError.response?.data?.message || t('FORMS.ERROR.LOAD');
  } finally {
    isLoadingSubmissions.value = false;
  }
}

async function openSubmission(submission) {
  selectedSubmission.value = null;
  submissionDialog.value?.open();
  try {
    const { data } = await FormsAPI.getSubmission(submission.id);
    selectedSubmission.value = data;
  } catch (loadError) {
    error.value = loadError.response?.data?.message || t('FORMS.ERROR.LOAD');
    submissionDialog.value?.close();
  }
}

async function openVersions() {
  if (!editor.value) return;

  versions.value = [];
  versionsDialog.value?.open();
  isLoadingVersions.value = true;
  try {
    const { data } = await FormsAPI.getVersions(editor.value.id);
    versions.value = data;
  } catch (loadError) {
    error.value = loadError.response?.data?.message || t('FORMS.ERROR.LOAD');
    versionsDialog.value?.close();
  } finally {
    isLoadingVersions.value = false;
  }
}

function formatAnswer(value) {
  if (Array.isArray(value)) return value.join(', ');
  if (value === true) return t('FORMS.SUBMISSIONS.YES');
  if (value === false) return t('FORMS.SUBMISSIONS.NO');
  return value || t('FORMS.SUBMISSIONS.NO_ANSWER');
}

function openCreateDialog() {
  newTemplate.value = {
    name: '',
    slug: '',
    category: 'lead_capture',
    starter: 'blank',
  };
  createDialog.value?.open();
}

function openDuplicateDialog() {
  if (!editor.value) return;

  duplicateForm.value = {
    name: t('FORMS.DUPLICATE.DEFAULT_NAME', { name: editor.value.name }),
    slug: `${editor.value.slug}-copia`,
  };
  duplicateDialog.value?.open();
}

function updateStarterCategory() {
  if (newTemplate.value.starter === 'pre_consultation') {
    newTemplate.value.category = 'pre_consultation';
  }
  if (newTemplate.value.starter === 'lead_capture') {
    newTemplate.value.category = 'lead_capture';
  }
  if (newTemplate.value.starter === 'clinical_intake') {
    newTemplate.value.category = 'clinical';
  }
}

function starterAccessClassification() {
  return newTemplate.value.starter === 'clinical_intake'
    ? 'sensitive_health'
    : 'commercial';
}

async function createTemplate() {
  if (!newTemplate.value.name.trim() || !newTemplate.value.slug.trim()) return;

  isSaving.value = true;
  error.value = '';
  let createdTemplate = null;
  try {
    const { data } = await FormsAPI.createTemplate({
      form_template: {
        name: newTemplate.value.name.trim(),
        slug: newTemplate.value.slug.trim(),
        category: newTemplate.value.category,
        access_classification: starterAccessClassification(),
      },
    });
    createdTemplate = data;
    templates.value = [data, ...templates.value];
    const starterSchema = getFormStarterSchema(newTemplate.value.starter, t);
    const template = starterSchema
      ? (await FormsAPI.publishTemplate(data.id, starterSchema)).data
      : data;
    templates.value = templates.value.map(item =>
      item.id === template.id ? template : item
    );
    createDialog.value?.close();
    selectTemplate(template);
  } catch (saveError) {
    if (createdTemplate) {
      createDialog.value?.close();
      selectTemplate(createdTemplate);
    }
    error.value = saveError.response?.data?.message || t('FORMS.ERROR.SAVE');
  } finally {
    isSaving.value = false;
  }
}

async function duplicateTemplate() {
  if (
    !editor.value ||
    !duplicateForm.value.name.trim() ||
    !duplicateForm.value.slug.trim()
  ) {
    return;
  }

  isSaving.value = true;
  error.value = '';
  try {
    const { data } = await FormsAPI.duplicateTemplate(editor.value.id, {
      form_template: {
        name: duplicateForm.value.name.trim(),
        slug: duplicateForm.value.slug.trim(),
      },
    });
    templates.value = [data, ...templates.value];
    duplicateDialog.value?.close();
    selectTemplate(data);
  } catch (saveError) {
    error.value = saveError.response?.data?.message || t('FORMS.ERROR.SAVE');
  } finally {
    isSaving.value = false;
  }
}

async function saveAndPublish() {
  if (!editorIsValid()) {
    error.value = t('FORMS.ERROR.INVALID_CONFIGURATION');
    return;
  }

  isSaving.value = true;
  error.value = '';
  try {
    await FormsAPI.updateTemplate(editor.value.id, {
      form_template: {
        name: editor.value.name.trim(),
        slug: editor.value.slug.trim(),
        category: editor.value.category,
        access_classification: editor.value.accessClassification,
        public_enabled: isSensitiveHealth.value
          ? false
          : editor.value.publicEnabled,
        settings: editor.value.settings,
      },
    });
    const { data } = await FormsAPI.publishTemplate(
      editor.value.id,
      buildSchema()
    );
    templates.value = templates.value.map(template =>
      template.id === data.id ? data : template
    );
    selectTemplate(data);
  } catch (saveError) {
    error.value = saveError.response?.data?.message || t('FORMS.ERROR.SAVE');
  } finally {
    isSaving.value = false;
  }
}

function addSection() {
  editor.value.schema.sections.push(
    defaultSection(editor.value.schema.sections.length + 1)
  );
}

function addField(section) {
  section.fields.push(defaultField(section.fields.length + 1));
}

function uniqueFieldKey(key, usedKeys) {
  let index = 2;
  let candidate = key;
  while (usedKeys.has(candidate)) {
    candidate = `${key}_${index}`;
    index += 1;
  }
  usedKeys.add(candidate);
  return candidate;
}

function addFieldGroup(group) {
  const fieldGroup = getFormFieldGroup(group, t);
  if (!fieldGroup) return;

  const usedSectionKeys = new Set(
    editor.value.schema.sections.map(section => section.key)
  );
  const usedFieldKeys = new Set(formFields.value.map(field => field.key));
  editor.value.schema.sections.push({
    ...fieldGroup,
    key: uniqueFieldKey(fieldGroup.key, usedSectionKeys),
    fields: fieldGroup.fields.map(field => ({
      ...field,
      key: uniqueFieldKey(field.key, usedFieldKeys),
    })),
  });
  fieldGroupDialog.value?.close();
}

function removeSection(index) {
  if (editor.value.schema.sections.length === 1) return;
  editor.value.schema.sections.splice(index, 1);
}

function removeField(section, index) {
  section.fields.splice(index, 1);
}

function moveItem(items, index, direction) {
  const targetIndex = index + direction;
  if (targetIndex < 0 || targetIndex >= items.length) return;

  const [item] = items.splice(index, 1);
  items.splice(targetIndex, 0, item);
}

function moveSection(index, direction) {
  moveItem(editor.value.schema.sections, index, direction);
}

function moveField(section, index, direction) {
  moveItem(section.fields, index, direction);
}

function onFieldTypeChanged(field) {
  if (!['select', 'multi_select'].includes(field.type)) field.options = [];
}

function conditionFieldOptions(field) {
  return formFields.value.filter(candidate => candidate.key !== field.key);
}

function conditionValueOptions(field) {
  const source = formFields.value.find(
    candidate => candidate.key === field.visibleWhenField
  );
  if (!source) return [];
  if (['select', 'multi_select'].includes(source.type)) return source.options;
  if (['checkbox', 'consent'].includes(source.type)) {
    return [
      { value: true, label: t('FORMS.EDITOR.CONDITION_TRUE') },
      { value: false, label: t('FORMS.EDITOR.CONDITION_FALSE') },
    ];
  }
  return [];
}

async function copyPublicLink() {
  if (!publicUrl.value) return;
  await copyTextToClipboard(publicUrl.value);
  copied.value = true;
  window.setTimeout(() => {
    copied.value = false;
  }, 2000);
}

function formatSubmissionDate(value) {
  return new Intl.DateTimeFormat(undefined, {
    dateStyle: 'short',
    timeStyle: 'short',
  }).format(new Date(value));
}

onMounted(async () => {
  await Promise.all([
    loadTemplates(),
    store.dispatch('kanbanBoards/fetchBoards'),
    store.dispatch('inboxes/get'),
  ]);
});
</script>

<template>
  <main class="flex h-full min-h-0 flex-col bg-n-solid-2">
    <header
      class="flex shrink-0 items-center justify-between gap-4 border-b border-n-slate-4 bg-n-solid-1 px-6 py-4"
    >
      <div>
        <h1 class="text-lg font-semibold text-n-slate-12">
          {{ t('FORMS.TITLE') }}
        </h1>
        <p class="mt-1 text-sm text-n-slate-10">{{ t('FORMS.SUBTITLE') }}</p>
      </div>
      <Button
        :label="t('FORMS.ACTIONS.NEW')"
        icon="i-lucide-plus"
        @click="openCreateDialog"
      />
    </header>

    <div
      v-if="error"
      role="alert"
      class="mx-6 mt-4 rounded border border-n-ruby-6 bg-n-ruby-2 px-3 py-2 text-sm text-n-ruby-11"
    >
      {{ error }}
    </div>

    <div
      class="grid min-h-0 flex-1 grid-cols-[15rem_minmax(0,1fr)] overflow-hidden"
    >
      <aside
        class="flex min-h-0 flex-col border-r border-n-slate-4 bg-n-solid-1 p-3"
      >
        <nav class="grid gap-1" :aria-label="t('FORMS.TITLE')">
          <button
            type="button"
            class="flex min-h-10 items-center gap-2 rounded px-3 text-sm font-medium text-n-slate-11 transition hover:bg-n-slate-3"
            :class="{ 'bg-n-teal-3 text-n-teal-11': activeTab === 'templates' }"
            @click="activeTab = 'templates'"
          >
            <span class="i-lucide-file-text size-4" aria-hidden="true" />
            {{ t('FORMS.TABS.TEMPLATES') }}
          </button>
          <button
            type="button"
            class="flex min-h-10 items-center gap-2 rounded px-3 text-sm font-medium text-n-slate-11 transition hover:bg-n-slate-3"
            :class="{
              'bg-n-teal-3 text-n-teal-11': activeTab === 'submissions',
            }"
            @click="
              activeTab = 'submissions';
              loadSubmissions();
            "
          >
            <span class="i-lucide-inbox size-4" aria-hidden="true" />
            {{ t('FORMS.TABS.SUBMISSIONS') }}
          </button>
        </nav>

        <div
          v-if="activeTab === 'templates'"
          class="mt-4 min-h-0 flex-1 overflow-y-auto"
        >
          <div v-if="isLoading" class="space-y-2 px-2 py-3">
            <div
              v-for="index in 4"
              :key="index"
              class="h-12 animate-pulse rounded bg-n-slate-3"
            />
          </div>
          <template v-else>
            <button
              v-for="template in templates"
              :key="template.id"
              type="button"
              class="mb-1 flex w-full flex-col rounded px-3 py-2 text-left transition hover:bg-n-slate-3"
              :class="{ 'bg-n-slate-3': selectedTemplateId === template.id }"
              @click="selectTemplate(template)"
            >
              <span class="break-words text-sm font-medium text-n-slate-12">{{
                template.name
              }}</span>
              <span class="mt-0.5 text-xs text-n-slate-10">{{
                template.active_version
                  ? `v${template.active_version.version_number}`
                  : t('FORMS.STATUS.DRAFT')
              }}</span>
            </button>
          </template>
        </div>
      </aside>

      <section
        v-if="activeTab === 'submissions'"
        class="min-h-0 overflow-y-auto p-6"
      >
        <div v-if="isLoadingSubmissions" class="space-y-3">
          <div
            v-for="index in 5"
            :key="index"
            class="h-14 animate-pulse rounded bg-n-slate-3"
          />
        </div>
        <div
          v-else-if="!submissions.length"
          class="mx-auto mt-20 max-w-md text-center"
        >
          <span
            class="i-lucide-clipboard-list mx-auto size-8 text-n-slate-9"
            aria-hidden="true"
          />
          <h2 class="mt-4 text-base font-semibold text-n-slate-12">
            {{ t('FORMS.EMPTY.SUBMISSIONS_TITLE') }}
          </h2>
          <p class="mt-2 text-sm leading-6 text-n-slate-10">
            {{ t('FORMS.EMPTY.SUBMISSIONS_DESCRIPTION') }}
          </p>
        </div>
        <div
          v-else
          class="overflow-hidden rounded border border-n-slate-4 bg-n-solid-1"
        >
          <table class="w-full text-left text-sm">
            <thead class="bg-n-slate-2 text-xs font-medium text-n-slate-10">
              <tr>
                <th class="px-4 py-3">{{ t('FORMS.SUBMISSIONS.FORM') }}</th>
                <th class="px-4 py-3">{{ t('FORMS.SUBMISSIONS.CONTACT') }}</th>
                <th class="px-4 py-3">
                  {{ t('FORMS.SUBMISSIONS.OPPORTUNITY') }}
                </th>
                <th class="px-4 py-3">
                  {{ t('FORMS.SUBMISSIONS.RECEIVED_AT') }}
                </th>
                <th class="px-4 py-3">
                  <span class="sr-only">{{ t('FORMS.SUBMISSIONS.OPEN') }}</span>
                </th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="submission in submissions"
                :key="submission.id"
                class="border-t border-n-slate-4 text-n-slate-11"
              >
                <td class="px-4 py-3 font-medium text-n-slate-12">
                  {{ submission.form_name }}
                </td>
                <td class="px-4 py-3">
                  {{
                    submission.contact?.name ||
                    t('FORMS.SUBMISSIONS.NO_CONTACT')
                  }}
                </td>
                <td class="px-4 py-3">
                  {{
                    submission.opportunity?.subject ||
                    t('FORMS.SUBMISSIONS.NO_OPPORTUNITY')
                  }}
                </td>
                <td class="px-4 py-3">
                  {{ formatSubmissionDate(submission.submitted_at) }}
                </td>
                <td class="px-4 py-3 text-right">
                  <Button
                    size="sm"
                    variant="faded"
                    color="slate"
                    :label="t('FORMS.SUBMISSIONS.OPEN')"
                    @click="openSubmission(submission)"
                  />
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>

      <section v-else-if="editor" class="min-h-0 overflow-y-auto p-6">
        <div class="mx-auto max-w-5xl space-y-6 pb-10">
          <div class="flex items-start justify-between gap-4">
            <div>
              <h2 class="text-xl font-semibold text-n-slate-12">
                {{ editor.name }}
              </h2>
              <p class="mt-1 text-sm text-n-slate-10">
                {{
                  selectedTemplate?.active_version
                    ? `v${selectedTemplate.active_version.version_number}`
                    : t('FORMS.STATUS.DRAFT')
                }}
              </p>
            </div>
            <div class="flex shrink-0 items-center gap-2">
              <Button
                variant="faded"
                color="slate"
                :label="t('FORMS.ACTIONS.DUPLICATE')"
                data-test="forms-duplicate"
                @click="openDuplicateDialog"
              />
              <Button
                variant="faded"
                color="slate"
                :label="t('FORMS.ACTIONS.VERSIONS')"
                @click="openVersions"
              />
              <Button
                :label="t('FORMS.ACTIONS.SAVE')"
                :is-loading="isSaving"
                @click="saveAndPublish"
              />
            </div>
          </div>

          <section class="rounded border border-n-slate-4 bg-n-solid-1 p-5">
            <h3 class="text-sm font-semibold text-n-slate-12">
              {{ t('FORMS.EDITOR.DETAILS') }}
            </h3>
            <div class="mt-4 grid gap-4 md:grid-cols-2">
              <label class="grid gap-1.5 text-sm font-medium text-n-slate-11">
                {{ t('FORMS.NEW_DIALOG.NAME') }}
                <input
                  v-model="editor.name"
                  class="min-h-10 rounded border border-n-slate-5 bg-n-solid-1 px-3 text-n-slate-12 outline-none focus:border-n-teal-9 focus:ring-2 focus:ring-n-teal-6"
                />
              </label>
              <label class="grid gap-1.5 text-sm font-medium text-n-slate-11">
                {{ t('FORMS.NEW_DIALOG.SLUG') }}
                <input
                  v-model="editor.slug"
                  class="min-h-10 rounded border border-n-slate-5 bg-n-solid-1 px-3 text-n-slate-12 outline-none focus:border-n-teal-9 focus:ring-2 focus:ring-n-teal-6"
                />
              </label>
              <label class="grid gap-1.5 text-sm font-medium text-n-slate-11">
                {{ t('FORMS.NEW_DIALOG.CATEGORY') }}
                <select
                  v-model="editor.category"
                  class="min-h-10 rounded border border-n-slate-5 bg-n-solid-1 px-3 text-n-slate-12 outline-none focus:border-n-teal-9 focus:ring-2 focus:ring-n-teal-6"
                >
                  <option
                    v-for="category in categories"
                    :key="category.value"
                    :value="category.value"
                  >
                    {{ category.label }}
                  </option>
                </select>
              </label>
              <label class="grid gap-1.5 text-sm font-medium text-n-slate-11">
                {{ t('FORMS.EDITOR.LOCALE') }}
                <select
                  v-model="editor.settings.locale"
                  class="min-h-10 rounded border border-n-slate-5 bg-n-solid-1 px-3 text-n-slate-12 outline-none focus:border-n-teal-9 focus:ring-2 focus:ring-n-teal-6"
                >
                  <option value="pt_BR">{{ t('FORMS.LOCALES.PT_BR') }}</option>
                  <option value="pt_PT">{{ t('FORMS.LOCALES.PT_PT') }}</option>
                </select>
              </label>
              <label class="grid gap-1.5 text-sm font-medium text-n-slate-11">
                {{ t('FORMS.EDITOR.BRAND_NAME') }}
                <input
                  v-model="editor.settings.brand_name"
                  :placeholder="t('FORMS.EDITOR.BRAND_NAME_PLACEHOLDER')"
                  class="min-h-10 rounded border border-n-slate-5 bg-n-solid-1 px-3 text-n-slate-12 outline-none focus:border-n-teal-9 focus:ring-2 focus:ring-n-teal-6"
                />
              </label>
              <label class="grid gap-1.5 text-sm font-medium text-n-slate-11">
                {{ t('FORMS.EDITOR.THEME') }}
                <select
                  v-model="editor.settings.theme"
                  class="min-h-10 rounded border border-n-slate-5 bg-n-solid-1 px-3 text-n-slate-12 outline-none focus:border-n-teal-9 focus:ring-2 focus:ring-n-teal-6"
                >
                  <option value="calm">
                    {{ t('FORMS.EDITOR.THEMES.CALM') }}
                  </option>
                  <option value="warm">
                    {{ t('FORMS.EDITOR.THEMES.WARM') }}
                  </option>
                  <option value="contrast">
                    {{ t('FORMS.EDITOR.THEMES.CONTRAST') }}
                  </option>
                </select>
              </label>
            </div>
            <label
              class="mt-4 grid gap-1.5 text-sm font-medium text-n-slate-11"
            >
              {{ t('FORMS.EDITOR.PUBLIC_DESCRIPTION') }}
              <textarea
                v-model="editor.settings.description"
                rows="2"
                class="rounded border border-n-slate-5 bg-n-solid-1 px-3 py-2 text-n-slate-12 outline-none focus:border-n-teal-9 focus:ring-2 focus:ring-n-teal-6"
              />
            </label>
            <label
              v-if="!isSensitiveHealth"
              class="mt-4 flex min-h-10 items-center gap-3 text-sm font-medium text-n-slate-11"
            >
              <input
                v-model="editor.publicEnabled"
                type="checkbox"
                class="size-4 accent-n-teal-9"
              />
              {{ t('FORMS.EDITOR.PUBLIC_ENABLED') }}
            </label>
            <p
              v-else
              class="mt-4 rounded border border-n-amber-6 bg-n-amber-2 px-3 py-2 text-sm text-n-amber-11"
            >
              {{ t('FORMS.EDITOR.SENSITIVE_HEALTH_NOTICE') }}
            </p>
            <div
              v-if="publicUrl"
              class="mt-3 flex items-center gap-2 rounded bg-n-slate-2 p-2"
            >
              <input
                :value="publicUrl"
                readonly
                class="min-w-0 flex-1 bg-transparent px-2 text-sm text-n-slate-11 outline-none"
              />
              <Button
                size="sm"
                variant="faded"
                color="slate"
                :label="
                  copied
                    ? t('FORMS.ACTIONS.COPIED')
                    : t('FORMS.ACTIONS.COPY_LINK')
                "
                @click="copyPublicLink"
              />
              <a
                :href="publicUrl"
                target="_blank"
                rel="noopener noreferrer"
                data-test="forms-public-preview"
                class="inline-flex min-h-8 shrink-0 items-center rounded px-2 text-sm font-medium text-n-teal-11 transition hover:bg-n-teal-3 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-teal-6"
              >
                {{ t('FORMS.ACTIONS.PREVIEW') }}
              </a>
            </div>
          </section>

          <section
            v-if="!isSensitiveHealth"
            class="rounded border border-n-slate-4 bg-n-solid-1 p-5"
          >
            <label
              class="flex min-h-10 items-center gap-3 text-sm font-semibold text-n-slate-12"
            >
              <input
                v-model="editor.crmDestinationEnabled"
                type="checkbox"
                class="size-4 accent-n-teal-9"
              />
              {{ t('FORMS.EDITOR.DESTINATION') }}
            </label>
            <div
              v-if="editor.crmDestinationEnabled"
              class="mt-4 grid gap-4 md:grid-cols-2"
            >
              <label class="grid gap-1.5 text-sm font-medium text-n-slate-11">
                {{ t('FORMS.EDITOR.BOARD') }}
                <select
                  v-model="editor.crmDestination.boardId"
                  class="min-h-10 rounded border border-n-slate-5 bg-n-solid-1 px-3 text-n-slate-12 outline-none focus:border-n-teal-9 focus:ring-2 focus:ring-n-teal-6"
                  @change="editor.crmDestination.stageId = ''"
                >
                  <option value="" disabled />
                  <option
                    v-for="board in boards"
                    :key="board.id"
                    :value="board.id"
                  >
                    {{ board.name }}
                  </option>
                </select>
              </label>
              <label class="grid gap-1.5 text-sm font-medium text-n-slate-11">
                {{ t('FORMS.EDITOR.STAGE') }}
                <select
                  v-model="editor.crmDestination.stageId"
                  class="min-h-10 rounded border border-n-slate-5 bg-n-solid-1 px-3 text-n-slate-12 outline-none focus:border-n-teal-9 focus:ring-2 focus:ring-n-teal-6"
                >
                  <option value="" disabled />
                  <option
                    v-for="stage in stageOptions"
                    :key="stage.id"
                    :value="stage.id"
                  >
                    {{ stage.name }}
                  </option>
                </select>
              </label>
              <label class="grid gap-1.5 text-sm font-medium text-n-slate-11">
                {{ t('FORMS.EDITOR.INBOX') }}
                <select
                  v-model="editor.crmDestination.inboxId"
                  class="min-h-10 rounded border border-n-slate-5 bg-n-solid-1 px-3 text-n-slate-12 outline-none focus:border-n-teal-9 focus:ring-2 focus:ring-n-teal-6"
                >
                  <option value="" disabled />
                  <option
                    v-for="inbox in inboxes"
                    :key="inbox.id"
                    :value="inbox.id"
                  >
                    {{ inbox.name }}
                  </option>
                </select>
              </label>
              <label class="grid gap-1.5 text-sm font-medium text-n-slate-11">
                {{ t('FORMS.EDITOR.POLICY') }}
                <select
                  v-model="editor.crmDestination.policy"
                  class="min-h-10 rounded border border-n-slate-5 bg-n-solid-1 px-3 text-n-slate-12 outline-none focus:border-n-teal-9 focus:ring-2 focus:ring-n-teal-6"
                >
                  <option value="reuse_open">
                    {{ t('FORMS.EDITOR.POLICY_REUSE') }}
                  </option>
                  <option value="create_new">
                    {{ t('FORMS.EDITOR.POLICY_CREATE') }}
                  </option>
                </select>
              </label>
            </div>
            <p
              v-if="
                editor.crmDestinationEnabled && selectedBoardCustomFields.length
              "
              class="mt-3 text-sm leading-6 text-n-slate-10"
            >
              {{ t('FORMS.EDITOR.OPPORTUNITY_MAPPING_HELP') }}
            </p>
          </section>

          <section class="rounded border border-n-slate-4 bg-n-solid-1 p-5">
            <div class="flex items-center justify-between gap-3">
              <h3 class="text-sm font-semibold text-n-slate-12">
                {{ t('FORMS.EDITOR.FIELDS') }}
              </h3>
              <div class="flex items-center gap-2">
                <Button
                  size="sm"
                  variant="faded"
                  color="slate"
                  :label="t('FORMS.ACTIONS.ADD_GROUP')"
                  icon="i-lucide-library-big"
                  @click="fieldGroupDialog?.open()"
                />
                <Button
                  size="sm"
                  variant="faded"
                  color="slate"
                  :label="t('FORMS.ACTIONS.ADD_SECTION')"
                  icon="i-lucide-plus"
                  @click="addSection"
                />
              </div>
            </div>
            <div
              v-for="(section, sectionIndex) in editor.schema.sections"
              :key="sectionIndex"
              class="mt-5 rounded border border-n-slate-4 bg-n-slate-2 p-4"
            >
              <div
                class="grid gap-3 md:grid-cols-[minmax(0,1fr)_12rem_auto] md:items-end"
              >
                <label class="grid gap-1.5 text-sm font-medium text-n-slate-11">
                  {{ t('FORMS.EDITOR.SECTION_TITLE') }}
                  <input
                    v-model="section.title"
                    class="min-h-10 rounded border border-n-slate-5 bg-n-solid-1 px-3 text-n-slate-12 outline-none focus:border-n-teal-9 focus:ring-2 focus:ring-n-teal-6"
                  />
                </label>
                <label class="grid gap-1.5 text-sm font-medium text-n-slate-11">
                  {{ t('FORMS.EDITOR.SECTION_KEY') }}
                  <input
                    v-model="section.key"
                    class="min-h-10 rounded border border-n-slate-5 bg-n-solid-1 px-3 text-n-slate-12 outline-none focus:border-n-teal-9 focus:ring-2 focus:ring-n-teal-6"
                  />
                </label>
                <div class="flex items-center gap-2">
                  <Button
                    size="sm"
                    variant="faded"
                    color="slate"
                    :label="t('FORMS.ACTIONS.MOVE_UP')"
                    icon="i-lucide-arrow-up"
                    :disabled="sectionIndex === 0"
                    :data-test="`forms-move-section-up-${sectionIndex}`"
                    @click="moveSection(sectionIndex, -1)"
                  />
                  <Button
                    size="sm"
                    variant="faded"
                    color="slate"
                    :label="t('FORMS.ACTIONS.MOVE_DOWN')"
                    icon="i-lucide-arrow-down"
                    :disabled="
                      sectionIndex === editor.schema.sections.length - 1
                    "
                    :data-test="`forms-move-section-down-${sectionIndex}`"
                    @click="moveSection(sectionIndex, 1)"
                  />
                  <Button
                    size="sm"
                    variant="faded"
                    color="slate"
                    :label="t('FORMS.ACTIONS.REMOVE')"
                    :disabled="editor.schema.sections.length === 1"
                    @click="removeSection(sectionIndex)"
                  />
                </div>
              </div>
              <label
                class="mt-3 grid gap-1.5 text-sm font-medium text-n-slate-11"
              >
                {{ t('FORMS.EDITOR.SECTION_DESCRIPTION') }}
                <input
                  v-model="section.description"
                  :data-test="`forms-section-description-${sectionIndex}`"
                  :placeholder="
                    t('FORMS.EDITOR.SECTION_DESCRIPTION_PLACEHOLDER')
                  "
                  class="min-h-10 rounded border border-n-slate-5 bg-n-solid-1 px-3 text-n-slate-12 outline-none focus:border-n-teal-9 focus:ring-2 focus:ring-n-teal-6"
                />
              </label>
              <div
                v-for="(field, fieldIndex) in section.fields"
                :key="fieldIndex"
                class="mt-3 grid gap-3 border-t border-n-slate-4 pt-3 lg:grid-cols-[minmax(0,1.3fr)_9rem_10rem_10rem_auto] lg:items-end"
              >
                <label class="grid gap-1.5 text-sm font-medium text-n-slate-11">
                  {{ t('FORMS.EDITOR.FIELD_LABEL') }}
                  <input
                    v-model="field.label"
                    class="min-h-10 rounded border border-n-slate-5 bg-n-solid-1 px-3 text-n-slate-12 outline-none focus:border-n-teal-9 focus:ring-2 focus:ring-n-teal-6"
                  />
                </label>
                <label
                  class="grid gap-1.5 text-sm font-medium text-n-slate-11 lg:col-span-2"
                >
                  {{ t('FORMS.EDITOR.FIELD_HELP') }}
                  <input
                    v-model="field.helpText"
                    :placeholder="t('FORMS.EDITOR.FIELD_HELP_PLACEHOLDER')"
                    class="min-h-10 rounded border border-n-slate-5 bg-n-solid-1 px-3 text-n-slate-12 outline-none focus:border-n-teal-9 focus:ring-2 focus:ring-n-teal-6"
                  />
                </label>
                <label class="grid gap-1.5 text-sm font-medium text-n-slate-11">
                  {{ t('FORMS.EDITOR.FIELD_KEY') }}
                  <input
                    v-model="field.key"
                    class="min-h-10 rounded border border-n-slate-5 bg-n-solid-1 px-3 text-n-slate-12 outline-none focus:border-n-teal-9 focus:ring-2 focus:ring-n-teal-6"
                  />
                </label>
                <label class="grid gap-1.5 text-sm font-medium text-n-slate-11">
                  {{ t('FORMS.EDITOR.FIELD_TYPE') }}
                  <select
                    v-model="field.type"
                    class="min-h-10 rounded border border-n-slate-5 bg-n-solid-1 px-3 text-n-slate-12 outline-none focus:border-n-teal-9 focus:ring-2 focus:ring-n-teal-6"
                    @change="onFieldTypeChanged(field)"
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
                <label
                  v-if="!isSensitiveHealth"
                  class="grid gap-1.5 text-sm font-medium text-n-slate-11"
                >
                  {{ t('FORMS.EDITOR.FIELD_MAPPING') }}
                  <select
                    v-model="field.contactTarget"
                    class="min-h-10 rounded border border-n-slate-5 bg-n-solid-1 px-3 text-n-slate-12 outline-none focus:border-n-teal-9 focus:ring-2 focus:ring-n-teal-6"
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
                <div class="flex items-center gap-2">
                  <Button
                    size="sm"
                    variant="faded"
                    color="slate"
                    :label="t('FORMS.ACTIONS.MOVE_UP')"
                    icon="i-lucide-arrow-up"
                    :disabled="fieldIndex === 0"
                    :data-test="`forms-move-field-up-${sectionIndex}-${fieldIndex}`"
                    @click="moveField(section, fieldIndex, -1)"
                  />
                  <Button
                    size="sm"
                    variant="faded"
                    color="slate"
                    :label="t('FORMS.ACTIONS.MOVE_DOWN')"
                    icon="i-lucide-arrow-down"
                    :disabled="fieldIndex === section.fields.length - 1"
                    :data-test="`forms-move-field-down-${sectionIndex}-${fieldIndex}`"
                    @click="moveField(section, fieldIndex, 1)"
                  />
                  <Button
                    size="sm"
                    variant="faded"
                    color="slate"
                    :label="t('FORMS.ACTIONS.REMOVE')"
                    :disabled="section.fields.length === 1"
                    @click="removeField(section, fieldIndex)"
                  />
                </div>
                <label
                  v-if="!isSensitiveHealth && field.contactTarget === 'custom'"
                  class="grid gap-1.5 text-sm font-medium text-n-slate-11 lg:col-span-2"
                >
                  {{ t('FORMS.EDITOR.CUSTOM_MAPPING') }}
                  <input
                    v-model="field.customAttribute"
                    :placeholder="t('FORMS.EDITOR.CUSTOM_MAPPING_PLACEHOLDER')"
                    class="min-h-10 rounded border border-n-slate-5 bg-n-solid-1 px-3 text-n-slate-12 outline-none focus:border-n-teal-9 focus:ring-2 focus:ring-n-teal-6"
                  />
                </label>
                <label
                  v-if="
                    !isSensitiveHealth &&
                    editor.crmDestinationEnabled &&
                    (opportunityFieldOptions(field).length ||
                      field.opportunityTarget)
                  "
                  class="grid gap-1.5 text-sm font-medium text-n-slate-11 lg:col-span-2"
                >
                  {{ t('FORMS.EDITOR.OPPORTUNITY_MAPPING') }}
                  <select
                    v-model="field.opportunityTarget"
                    :data-test="`forms-opportunity-target-${field.key}`"
                    class="min-h-10 rounded border border-n-slate-5 bg-n-solid-1 px-3 text-n-slate-12 outline-none focus:border-n-teal-9 focus:ring-2 focus:ring-n-teal-6"
                  >
                    <option value="">
                      {{ t('FORMS.EDITOR.NO_OPPORTUNITY_MAPPING') }}
                    </option>
                    <option
                      v-for="definition in opportunityFieldOptions(field)"
                      :key="definition.key"
                      :value="definition.key"
                    >
                      {{ definition.label || definition.key }}
                    </option>
                  </select>
                </label>
                <label
                  v-if="['select', 'multi_select'].includes(field.type)"
                  class="grid gap-1.5 text-sm font-medium text-n-slate-11 lg:col-span-3"
                >
                  {{ t('FORMS.EDITOR.FIELD_TYPE') }}
                  <input
                    :value="field.options.join(', ')"
                    class="min-h-10 rounded border border-n-slate-5 bg-n-solid-1 px-3 text-n-slate-12 outline-none focus:border-n-teal-9 focus:ring-2 focus:ring-n-teal-6"
                    @input="
                      field.options = $event.target.value
                        .split(',')
                        .map(option => option.trim())
                        .filter(Boolean)
                    "
                  />
                </label>
                <label
                  class="grid gap-1.5 text-sm font-medium text-n-slate-11 lg:col-span-2"
                >
                  {{ t('FORMS.EDITOR.CONDITION_FIELD') }}
                  <select
                    v-model="field.visibleWhenField"
                    class="min-h-10 rounded border border-n-slate-5 bg-n-solid-1 px-3 text-n-slate-12 outline-none focus:border-n-teal-9 focus:ring-2 focus:ring-n-teal-6"
                    @change="field.visibleWhenValue = ''"
                  >
                    <option value="">
                      {{ t('FORMS.EDITOR.CONDITION_NONE') }}
                    </option>
                    <option
                      v-for="conditionField in conditionFieldOptions(field)"
                      :key="conditionField.key"
                      :value="conditionField.key"
                    >
                      {{ conditionField.label || conditionField.key }}
                    </option>
                  </select>
                </label>
                <label
                  v-if="field.visibleWhenField"
                  class="grid gap-1.5 text-sm font-medium text-n-slate-11 lg:col-span-2"
                >
                  {{ t('FORMS.EDITOR.CONDITION_VALUE') }}
                  <select
                    v-if="conditionValueOptions(field).length"
                    v-model="field.visibleWhenValue"
                    class="min-h-10 rounded border border-n-slate-5 bg-n-solid-1 px-3 text-n-slate-12 outline-none focus:border-n-teal-9 focus:ring-2 focus:ring-n-teal-6"
                  >
                    <option value="" disabled />
                    <option
                      v-for="option in conditionValueOptions(field)"
                      :key="option.value ?? option"
                      :value="option.value ?? option"
                    >
                      {{ option.label ?? option }}
                    </option>
                  </select>
                  <input
                    v-else
                    v-model="field.visibleWhenValue"
                    class="min-h-10 rounded border border-n-slate-5 bg-n-solid-1 px-3 text-n-slate-12 outline-none focus:border-n-teal-9 focus:ring-2 focus:ring-n-teal-6"
                  />
                </label>
                <label
                  class="flex min-h-10 items-center gap-2 text-sm font-medium text-n-slate-11"
                >
                  <input
                    v-model="field.required"
                    type="checkbox"
                    class="size-4 accent-n-teal-9"
                  />
                  {{ t('FORMS.EDITOR.FIELD_REQUIRED') }}
                </label>
              </div>
              <Button
                class="mt-4"
                size="sm"
                variant="faded"
                color="slate"
                :label="t('FORMS.ACTIONS.ADD_FIELD')"
                icon="i-lucide-plus"
                @click="addField(section)"
              />
            </div>
          </section>
        </div>
      </section>

      <section v-else class="flex items-center justify-center p-6">
        <div class="max-w-md text-center">
          <span
            class="i-lucide-file-plus mx-auto size-8 text-n-slate-9"
            aria-hidden="true"
          />
          <h2 class="mt-4 text-base font-semibold text-n-slate-12">
            {{ t('FORMS.EMPTY.TEMPLATES_TITLE') }}
          </h2>
          <p class="mt-2 text-sm leading-6 text-n-slate-10">
            {{ t('FORMS.EMPTY.TEMPLATES_DESCRIPTION') }}
          </p>
        </div>
      </section>
    </div>
  </main>

  <Dialog
    ref="createDialog"
    :title="t('FORMS.NEW_DIALOG.TITLE')"
    :description="t('FORMS.NEW_DIALOG.DESCRIPTION')"
    :confirm-button-label="t('FORMS.NEW_DIALOG.CREATE')"
    :is-loading="isSaving"
    @confirm="createTemplate"
  >
    <label class="grid gap-1.5 text-sm font-medium text-n-slate-11">
      {{ t('FORMS.NEW_DIALOG.NAME') }}
      <input
        v-model="newTemplate.name"
        class="min-h-10 rounded border border-n-slate-5 bg-n-solid-1 px-3 text-n-slate-12 outline-none focus:border-n-teal-9 focus:ring-2 focus:ring-n-teal-6"
        @input="newTemplate.slug = slugify(newTemplate.name)"
      />
    </label>
    <label class="grid gap-1.5 text-sm font-medium text-n-slate-11">
      {{ t('FORMS.NEW_DIALOG.SLUG') }}
      <input
        v-model="newTemplate.slug"
        class="min-h-10 rounded border border-n-slate-5 bg-n-solid-1 px-3 text-n-slate-12 outline-none focus:border-n-teal-9 focus:ring-2 focus:ring-n-teal-6"
      />
    </label>
    <label class="grid gap-1.5 text-sm font-medium text-n-slate-11">
      {{ t('FORMS.NEW_DIALOG.CATEGORY') }}
      <select
        v-model="newTemplate.category"
        class="min-h-10 rounded border border-n-slate-5 bg-n-solid-1 px-3 text-n-slate-12 outline-none focus:border-n-teal-9 focus:ring-2 focus:ring-n-teal-6"
      >
        <option
          v-for="category in categories"
          :key="category.value"
          :value="category.value"
        >
          {{ category.label }}
        </option>
      </select>
    </label>
    <label class="grid gap-1.5 text-sm font-medium text-n-slate-11">
      {{ t('FORMS.NEW_DIALOG.STARTER') }}
      <select
        v-model="newTemplate.starter"
        class="min-h-10 rounded border border-n-slate-5 bg-n-solid-1 px-3 text-n-slate-12 outline-none focus:border-n-teal-9 focus:ring-2 focus:ring-n-teal-6"
        @change="updateStarterCategory"
      >
        <option
          v-for="starter in starterOptions"
          :key="starter.value"
          :value="starter.value"
        >
          {{ starter.label }}
        </option>
      </select>
      <span class="text-xs font-normal leading-5 text-n-slate-10">
        {{ t('FORMS.NEW_DIALOG.STARTER_HINT') }}
      </span>
    </label>
  </Dialog>

  <Dialog
    ref="submissionDialog"
    width="lg"
    :title="t('FORMS.SUBMISSIONS.DETAIL_TITLE')"
    :show-confirm-button="false"
    :cancel-button-label="t('FORMS.ACTIONS.CLOSE')"
  >
    <div
      v-if="!selectedSubmission"
      class="py-8 text-center text-sm text-n-slate-10"
    >
      {{ t('KANBAN.OPPORTUNITY_DETAILS.LOADING') }}
    </div>
    <dl v-else class="grid gap-4">
      <div
        v-for="field in selectedSubmission.fields"
        :key="field.key"
        class="border-b border-n-slate-4 pb-3 last:border-b-0 last:pb-0"
      >
        <dt class="text-xs font-medium uppercase tracking-wide text-n-slate-10">
          {{ field.label }}
        </dt>
        <dd
          class="mt-1 whitespace-pre-wrap break-words text-sm text-n-slate-12"
        >
          {{ formatAnswer(selectedSubmission.answers[field.key]) }}
        </dd>
      </div>
    </dl>
  </Dialog>

  <Dialog
    ref="versionsDialog"
    :title="t('FORMS.VERSIONS.TITLE')"
    :description="t('FORMS.VERSIONS.DESCRIPTION')"
    :show-confirm-button="false"
    :cancel-button-label="t('FORMS.ACTIONS.CLOSE')"
  >
    <div v-if="isLoadingVersions" class="space-y-2" aria-live="polite">
      <div
        v-for="index in 3"
        :key="index"
        class="h-12 animate-pulse rounded bg-n-slate-3"
      />
    </div>
    <ul
      v-else
      class="divide-y divide-n-slate-4 rounded border border-n-slate-4"
    >
      <li
        v-for="version in versions"
        :key="version.id"
        class="flex min-h-12 items-center justify-between gap-3 px-3 py-2 text-sm"
      >
        <span class="font-medium text-n-slate-12">
          {{ t('FORMS.VERSIONS.ITEM', { version: version.version_number }) }}
        </span>
        <span class="text-n-slate-10">
          {{ formatSubmissionDate(version.published_at) }}
        </span>
      </li>
    </ul>
  </Dialog>

  <Dialog
    ref="fieldGroupDialog"
    width="lg"
    :title="t('FORMS.FIELD_GROUPS.TITLE')"
    :description="t('FORMS.FIELD_GROUPS.DESCRIPTION')"
    :show-confirm-button="false"
    :cancel-button-label="t('FORMS.ACTIONS.CLOSE')"
  >
    <div class="grid gap-3">
      <button
        v-for="group in fieldGroupOptions"
        :key="group.id"
        type="button"
        class="grid min-h-20 grid-cols-[2.25rem_minmax(0,1fr)_auto] items-center gap-3 rounded border border-n-slate-4 bg-n-solid-1 px-4 py-3 text-left transition hover:border-n-teal-7 hover:bg-n-teal-2 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-teal-6"
        :data-test="`forms-field-group-${group.id}`"
        @click="addFieldGroup(group.id)"
      >
        <span
          class="i-lucide-layout-template size-5 text-n-teal-10"
          aria-hidden="true"
        />
        <span class="min-w-0">
          <span class="block text-sm font-semibold text-n-slate-12">
            {{ group.title }}
          </span>
          <span class="mt-1 block text-sm leading-5 text-n-slate-10">
            {{ group.description }}
          </span>
        </span>
        <span class="i-lucide-plus size-4 text-n-slate-10" aria-hidden="true" />
      </button>
    </div>
  </Dialog>

  <Dialog
    ref="duplicateDialog"
    :title="t('FORMS.DUPLICATE.TITLE')"
    :description="t('FORMS.DUPLICATE.DESCRIPTION')"
    :confirm-button-label="t('FORMS.DUPLICATE.CREATE')"
    :is-loading="isSaving"
    @confirm="duplicateTemplate"
  >
    <label class="grid gap-1.5 text-sm font-medium text-n-slate-11">
      {{ t('FORMS.NEW_DIALOG.NAME') }}
      <input
        v-model="duplicateForm.name"
        data-test="forms-duplicate-name"
        class="min-h-10 rounded border border-n-slate-5 bg-n-solid-1 px-3 text-n-slate-12 outline-none focus:border-n-teal-9 focus:ring-2 focus:ring-n-teal-6"
      />
    </label>
    <label class="grid gap-1.5 text-sm font-medium text-n-slate-11">
      {{ t('FORMS.NEW_DIALOG.SLUG') }}
      <input
        v-model="duplicateForm.slug"
        data-test="forms-duplicate-slug"
        class="min-h-10 rounded border border-n-slate-5 bg-n-solid-1 px-3 text-n-slate-12 outline-none focus:border-n-teal-9 focus:ring-2 focus:ring-n-teal-6"
      />
    </label>
  </Dialog>
</template>
