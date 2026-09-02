<script setup>
import {
  computed,
  nextTick,
  onBeforeUnmount,
  onMounted,
  ref,
  watch,
} from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { copyTextToClipboard } from 'shared/helpers/clipboard';
import FormsAPI from 'dashboard/api/forms';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Draggable from 'vuedraggable';
import FormsBlockLibrary from './FormsBlockLibrary.vue';
import { OnClickOutside } from '@vueuse/components';
import { dynamicTime } from 'shared/helpers/timeHelper';
import { useRequestSidebarFocus } from 'dashboard/composables/useSidebarFocus';
import FormsCanvasEditor from './FormsCanvasEditor.vue';
import FormsSubmissionActions from './FormsSubmissionActions.vue';
import FormsBuilderSettingsDialog from './FormsBuilderSettingsDialog.vue';
import { getFormStarterSchema } from './starterTemplates';
import { FORM_FIELD_GROUPS, getFormFieldGroup } from './fieldGroups';

const { t } = useI18n();
const store = useStore();
const boards = useMapGetter('kanbanBoards/kanbanBoards');
const inboxes = useMapGetter('inboxes/getAllInboxes');
const agents = useMapGetter('agents/getAgents');
const teams = useMapGetter('teams/getTeams');
const templates = ref([]);
const customFieldGroups = ref([]);
const submissions = ref([]);
const activeTab = ref('templates');
const selectedTemplateId = ref(null);
const activeBuilderSectionIndex = ref(0);
const selectedBuilderFieldKey = ref('');
const showFormActionsMenu = ref(false);
const selectedBuilderContentBlockId = ref('');
const builderLibraryRef = ref(null);
const hasUnsavedChanges = ref(false);
const localDraftRestored = ref(false);
const localDraftUpdatedAt = ref(null);
const lastEditorSnapshot = ref('');
const editor = ref(null);
const isLoading = ref(true);
const isSaving = ref(false);
const createError = ref('');
const isLoadingSubmissions = ref(false);
const isExportingSubmission = ref(false);
const error = ref('');
const copied = ref(false);
const createDialog = ref(null);
const submissionDialog = ref(null);
const versionsDialog = ref(null);
const saveFieldGroupDialog = ref(null);
const deleteFieldGroupDialog = ref(null);
const builderSettingsDialog = ref(null);
const duplicateDialog = ref(null);
const selectedSubmission = ref(null);
const versions = ref([]);
const isLoadingVersions = ref(false);
const isUploadingBrandLogo = ref(false);
const isUploadingContentImage = ref(false);
const newTemplate = ref({
  name: '',
  slug: '',
  category: 'lead_capture',
  starter: 'blank',
});
const duplicateForm = ref({ name: '', slug: '' });
const fieldGroupForm = ref({ name: '' });
const fieldGroupPendingDeletion = ref(null);
const clinicalAccessSearch = ref('');

/** Editar é um modo, não uma secção: a lista sai da frente enquanto dura. */
const isEditing = computed(() => Boolean(editor.value));

// A navegação do CRM recolhe a ícones enquanto se edita: devolve 144px ao
// formulário sem tirar o acesso de um clique a Conversas ou Pipeline.
const { setSidebarFocus } = useRequestSidebarFocus();
watch(isEditing, setSidebarFocus);

/** Todas as perguntas do formulário, em ordem: é o universo da lógica. */
const allBuilderFields = computed(() =>
  (editor.value?.schema?.sections || []).flatMap(
    section => section.fields || []
  )
);

// `logics` e `variables` vivem na raiz do schema, não na secção: uma regra
// pode saltar de uma secção para outra, e uma variável atravessa o formulário.
const updateSchemaLogics = logics => {
  if (!editor.value) return;
  editor.value.schema.logics = logics;
};

const updateEditorSettings = patch => {
  if (!editor.value) return;
  Object.assign(editor.value.settings, patch);
};

const updateSubmissionActions = actions => {
  if (!editor.value) return;
  editor.value.schema.submission_actions = actions;
};

const updateSchemaVariables = variables => {
  if (!editor.value) return;
  editor.value.schema.variables = variables;
};

const selectedTemplate = computed(() =>
  templates.value.find(template => template.id === selectedTemplateId.value)
);

/**
 * O estado do formulário, sempre à vista: rascunho ou publicado, que versão,
 * quantas respostas já entraram e quando foi mexido pela última vez.
 *
 * Antes o subtítulo dizia só «v3» ou «Rascunho», e quem editava não sabia se
 * estava a mexer em algo que já tinha 128 respostas lá fora.
 */
const isPublished = computed(() =>
  Boolean(selectedTemplate.value?.active_version)
);

const submissionsCount = computed(
  () => selectedTemplate.value?.submissions_count || 0
);

const statusParts = computed(() => {
  const template = selectedTemplate.value;
  if (!template) return [];

  const parts = [];
  if (template.active_version) {
    parts.push(
      t('FORMS.STATUS.VERSION', {
        number: template.active_version.version_number,
      })
    );
  }
  parts.push(
    submissionsCount.value
      ? t('FORMS.STATUS.SUBMISSIONS', submissionsCount.value, {
          count: submissionsCount.value,
        })
      : t('FORMS.STATUS.NO_SUBMISSIONS')
  );
  if (template.updated_at) {
    parts.push(
      t('FORMS.STATUS.EDITED', {
        when: dynamicTime(new Date(template.updated_at).getTime() / 1000),
      })
    );
  }
  return parts;
});

// O separador é dado, não marcação: no template ele seria texto cru e o lint
// de i18n reclamaria com razão de uma pontuação solta.
const statusLine = computed(() => statusParts.value.join(' · '));

const isSensitiveHealth = computed(
  () => editor.value?.accessClassification === 'sensitive_health'
);

/**
 * As configurações em navegação lateral, uma secção de cada vez.
 *
 * O acordeão mostrava as cinco de uma vez e obrigava a rolar por marca,
 * publicação, automação e acesso clínico para chegar ao destino do CRM.
 */
const settingsSection = ref('identity');

const settingsSections = computed(() =>
  [
    'identity',
    'publishing',
    'automation',
    // Só existe em formulário clínico; noutro, a secção nem se oferece.
    ...(isSensitiveHealth.value ? ['clinical'] : []),
    ...(isSensitiveHealth.value ? [] : ['destination']),
  ].map(id => ({ id, label: t(`FORMS.SETTINGS_NAV.${id.toUpperCase()}`) }))
);

// Trocar de formulário pode tirar do ar a secção aberta.
watch(settingsSections, sections => {
  if (!sections.some(item => item.id === settingsSection.value)) {
    settingsSection.value = sections[0].id;
  }
});

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
const criticalResponseFields = computed(() =>
  formFields.value.filter(field => field.type !== 'hidden')
);
const criticalResponseField = computed(() =>
  criticalResponseFields.value.find(
    field => field.key === editor.value?.settings?.critical_response?.field_key
  )
);
const criticalResponseOptions = computed(() =>
  Array.isArray(criticalResponseField.value?.options)
    ? criticalResponseField.value.options.filter(Boolean)
    : []
);
const normalizedClinicalAccessSearch = computed(() =>
  clinicalAccessSearch.value.trim().toLocaleLowerCase()
);
const clinicalAccessAgents = computed(() => {
  const query = normalizedClinicalAccessSearch.value;
  if (!query) return agents.value;

  return agents.value.filter(agent =>
    String(agent.name).toLocaleLowerCase().includes(query)
  );
});
const clinicalAccessTeams = computed(() => {
  const query = normalizedClinicalAccessSearch.value;
  if (!query) return teams.value;

  return teams.value.filter(team =>
    String(team.name).toLocaleLowerCase().includes(query)
  );
});
const clinicalAccessSelectionCount = computed(() => {
  const access = editor.value?.settings?.clinical_access;

  return (access?.user_ids?.length || 0) + (access?.team_ids?.length || 0);
});
const activeBuilderSection = computed(
  () =>
    editor.value?.schema.sections[activeBuilderSectionIndex.value] ||
    editor.value?.schema.sections[0] ||
    null
);
const selectedBuilderField = computed(
  () =>
    activeBuilderSection.value?.fields.find(
      field => field.key === selectedBuilderFieldKey.value
    ) || null
);
const selectedBuilderContentBlock = computed(
  () =>
    activeBuilderSection.value?.content_blocks?.find(
      block => block.id === selectedBuilderContentBlockId.value
    ) || null
);
const selectedSubmissionSections = computed(() => {
  if (!selectedSubmission.value?.fields) return [];

  return selectedSubmission.value.fields.reduce((sections, field) => {
    const title =
      field.section_title || t('FORMS.SUBMISSIONS.UNTITLED_SECTION');
    const section = sections.find(item => item.title === title);
    if (section) {
      section.fields.push(field);
      return sections;
    }

    sections.push({ title, fields: [field] });
    return sections;
  }, []);
});
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
const fieldTypes = computed(() => {
  const types = [
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
    { value: 'signature', label: t('FORMS.EDITOR.TYPE.SIGNATURE') },
  ];

  if (isSensitiveHealth.value) {
    types.push({
      value: 'attachment',
      label: t('FORMS.EDITOR.TYPE.ATTACHMENT'),
    });
  }

  return types;
});
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
    layout: 'single',
    content_blocks: [],
    fields: [defaultField()],
  };
}

function formDraftKey(templateId) {
  return `raevo-form-builder-draft:${templateId}`;
}

function restoreLocalDraft(template, defaultEditor) {
  localDraftRestored.value = false;
  localDraftUpdatedAt.value = null;
  try {
    const stored = window.localStorage.getItem(formDraftKey(template.id));
    if (!stored) return defaultEditor;

    const draft = JSON.parse(stored);
    const serverUpdatedAt = new Date(template.updated_at || 0).getTime();
    if (!draft.editor || Number(draft.updatedAt) <= serverUpdatedAt) {
      return defaultEditor;
    }

    localDraftRestored.value = true;
    localDraftUpdatedAt.value = Number(draft.updatedAt);
    return draft.editor;
  } catch {
    return defaultEditor;
  }
}

function clearLocalDraft(templateId) {
  window.localStorage.removeItem(formDraftKey(templateId));
  localDraftRestored.value = false;
  localDraftUpdatedAt.value = null;
}

function hydrateEditor(template) {
  clinicalAccessSearch.value = '';
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
    layout: section.layout || 'single',
    content_blocks: section.content_blocks || [],
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
  const nextEditor = {
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
    brandLogoUrl: template.brand_logo_url || '',
    settings: {
      locale: template.settings?.locale || 'pt_BR',
      description: template.settings?.description || '',
      brand_name: template.settings?.brand_name || '',
      brand_logo_url: template.settings?.brand_logo_url || '',
      privacy_policy_url: template.settings?.privacy_policy_url || '',
      theme: template.settings?.theme || 'calm',
      presentation:
        template.settings?.presentation ||
        (template.access_classification === 'sensitive_health'
          ? 'sectioned'
          : 'guided'),
      clinical_access: {
        user_ids: template.settings?.clinical_access?.user_ids || [],
        team_ids: template.settings?.clinical_access?.team_ids || [],
      },
      clinical_retention_days:
        template.settings?.clinical_retention_days || null,
      captcha_provider: template.settings?.captcha_provider || '',
      captcha_site_key: template.settings?.captcha_site_key || '',
      abandonment_delay_hours:
        template.settings?.abandonment_delay_hours || null,
      critical_response: {
        field_key: template.settings?.critical_response?.field_key || '',
        value: template.settings?.critical_response?.value || '',
      },
    },
    schema,
    crmDestinationEnabled:
      template.access_classification !== 'sensitive_health',
    crmDestination: {
      boardId: destination.kanban_board_id || '',
      stageId: destination.kanban_stage_id || '',
      inboxId: destination.inbox_id || '',
      policy: destination.opportunity_policy || 'reuse_open',
    },
  };
  editor.value = restoreLocalDraft(template, nextEditor);
  hasUnsavedChanges.value = false;
  lastEditorSnapshot.value = JSON.stringify(editor.value);
}

function selectTemplate(template) {
  selectedTemplateId.value = template.id;
  hydrateEditor(template);
  activeBuilderSectionIndex.value = 0;
  selectedBuilderFieldKey.value =
    editor.value.schema.sections[0]?.fields[0]?.key || '';
  selectedBuilderContentBlockId.value = '';
  activeTab.value = 'templates';
  error.value = '';
}

/**
 * Sai do editor e devolve a lista.
 *
 * Sem isto não havia volta: ao entrar em Formulários o primeiro modelo abre
 * sozinho, e como o modo de edição recolhe a lista, quem tinha cinco
 * formulários só conseguia editar o primeiro.
 */
function closeEditor() {
  editor.value = null;
  selectedTemplateId.value = null;
  selectedBuilderFieldKey.value = '';
  selectedBuilderContentBlockId.value = '';
  error.value = '';
}

function selectBuilderSection(index) {
  activeBuilderSectionIndex.value = index;
  selectedBuilderContentBlockId.value = '';
  selectedBuilderFieldKey.value = '';
  builderSettingsDialog.value?.open();
}

function selectBuilderField(key) {
  const sectionIndex = editor.value?.schema.sections.findIndex(section =>
    section.fields.some(field => field.key === key)
  );
  if (sectionIndex === undefined || sectionIndex < 0) return;

  activeBuilderSectionIndex.value = sectionIndex;
  selectedBuilderFieldKey.value = key;
  selectedBuilderContentBlockId.value = '';
  builderSettingsDialog.value?.open();
}

function selectBuilderContentBlock(blockId) {
  selectedBuilderFieldKey.value = '';
  selectedBuilderContentBlockId.value = blockId;
  builderSettingsDialog.value?.open();
}

function syncBuilderSelection() {
  const sectionIndex = editor.value?.schema.sections.findIndex(section =>
    section.fields.some(field => field.key === selectedBuilderFieldKey.value)
  );
  if (sectionIndex === undefined || sectionIndex < 0) {
    selectBuilderSection(0);
    return;
  }

  activeBuilderSectionIndex.value = sectionIndex;
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

function previewPayload() {
  // The schema is assembled below alongside mapping and publishing rules.
  // eslint-disable-next-line no-use-before-define
  const schema = buildSchema();
  delete schema.crm_mapping;
  delete schema.crm_destination;
  schema.sections = schema.sections.map(section => ({
    ...section,
    fields: section.fields.filter(field => field.type !== 'hidden'),
  }));

  return {
    form: {
      name: editor.value.name.trim(),
      category: editor.value.category,
      locale: editor.value.settings.locale,
      description: editor.value.settings.description,
      brand_name: editor.value.settings.brand_name || editor.value.name.trim(),
      brand_logo_url:
        editor.value.brandLogoUrl || editor.value.settings.brand_logo_url,
      privacy_policy_url: editor.value.settings.privacy_policy_url,
      theme: editor.value.settings.theme,
      presentation: editor.value.settings.presentation,
      captcha_provider: '',
      captcha_site_key: '',
    },
    version: editor.value.activeVersionNumber || 0,
    schema,
  };
}

function openPrivatePreview() {
  if (!editor.value) return;

  const previewId = `${editor.value.id}-${Date.now()}-${Math.random()
    .toString(36)
    .slice(2, 8)}`;
  const previewUrl = `${window.location.origin}/formularios/previsao/${previewId}`;
  window.localStorage.setItem(
    `raevo-form-preview:${previewId}`,
    JSON.stringify({
      expiresAt: Date.now() + 15 * 60 * 1000,
      payload: previewPayload(),
    })
  );
  window.open(previewUrl, '_blank', 'noopener,noreferrer');
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
        if (!isSensitiveHealth.value && field.opportunityTarget) {
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

  if (!isSensitiveHealth.value) {
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

function contentBlockIsValid(block) {
  if (block.type === 'heading') return Boolean(block.content?.trim());
  if (block.type === 'rich_text') return Boolean(block.content);
  if (block.type === 'image') {
    try {
      const url = new URL(block.url);
      return ['http:', 'https:'].includes(url.protocol);
    } catch {
      return false;
    }
  }

  return block.type === 'divider';
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
  if (isSensitiveHealth.value || !field.opportunityTarget) {
    return true;
  }

  return opportunityFieldOptions(field).some(
    definition => definition.key === field.opportunityTarget
  );
}

function publicContactMappingIsComplete() {
  if (!editor.value?.publicEnabled || isSensitiveHealth.value) return true;

  const mappedTargets = new Set(
    formFields.value.map(field => field.contactTarget).filter(Boolean)
  );
  return (
    mappedTargets.has('name') &&
    (mappedTargets.has('email') || mappedTargets.has('phone_number'))
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
          (section.content_blocks || []).every(contentBlockIsValid) &&
          section.fields.every(
            field => fieldIsValid(field) && opportunityMappingIsValid(field)
          )
      ) &&
      (isSensitiveHealth.value ||
        (editor.value.crmDestination.boardId &&
          editor.value.crmDestination.stageId &&
          editor.value.crmDestination.inboxId)) &&
      publicContactMappingIsComplete()
  );
}

const publishingChecklist = computed(() => {
  const fields = formFields.value;
  const hasValidFields =
    fields.length > 0 && fields.every(field => fieldIsValid(field));
  const hasClinicalConsent = fields.some(
    field => field.type === 'consent' && field.required
  );
  const destinationConfigured =
    isSensitiveHealth.value ||
    Boolean(
      editor.value.crmDestination.boardId &&
        editor.value.crmDestination.stageId &&
        editor.value.crmDestination.inboxId
    );

  return [
    {
      complete: Boolean(editor.value?.name.trim() && editor.value?.slug.trim()),
      label: t('FORMS.BUILDER.CHECKLIST.IDENTITY'),
    },
    {
      complete: hasValidFields,
      label: t('FORMS.BUILDER.CHECKLIST.QUESTIONS'),
    },
    {
      complete: publicContactMappingIsComplete(),
      label: t('FORMS.BUILDER.CHECKLIST.PUBLIC_CONTACT_MAPPING'),
      visible: editor.value?.publicEnabled && !isSensitiveHealth.value,
    },
    {
      complete: !isSensitiveHealth.value || hasClinicalConsent,
      label: t('FORMS.BUILDER.CHECKLIST.CONSENT'),
      visible: isSensitiveHealth.value,
    },
    {
      complete: destinationConfigured,
      label: t('FORMS.BUILDER.CHECKLIST.DESTINATION'),
      visible: !isSensitiveHealth.value,
    },
  ].filter(item => item.visible !== false);
});

/**
 * O que ainda falta, por palavras.
 *
 * A mensagem de publicação era uma frase só — «reveja os campos obrigatórios,
 * as opções de seleção e as condições» — para oito causas diferentes. As
 * razões reais existiam, mas escondidas atrás do contador «Publicação 1/3»,
 * que ninguém tem motivo para abrir depois de um erro.
 */
const missingToPublish = computed(() =>
  publishingChecklist.value
    .filter(item => !item.complete)
    .map(item => item.label)
);

const completedPublishingChecks = computed(
  () => publishingChecklist.value.filter(item => item.complete).length
);

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

async function loadCustomFieldGroups() {
  try {
    const { data } = await FormsAPI.getFieldGroups();
    customFieldGroups.value = data;
  } catch (loadError) {
    error.value = loadError.response?.data?.message || t('FORMS.ERROR.LOAD');
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

async function downloadClinicalAttachment(attachment) {
  if (!selectedSubmission.value) return;

  try {
    const { data } = await FormsAPI.downloadSubmissionAttachment(
      selectedSubmission.value.id,
      attachment.id
    );
    const url = window.URL.createObjectURL(data);
    const link = document.createElement('a');
    link.href = url;
    link.download = attachment.filename;
    link.click();
    window.URL.revokeObjectURL(url);
  } catch (downloadError) {
    error.value =
      downloadError.response?.data?.message || t('FORMS.ERROR.LOAD');
  }
}

async function downloadSubmissionExport() {
  if (!selectedSubmission.value) return;

  isExportingSubmission.value = true;
  try {
    const { data } = await FormsAPI.downloadSubmissionExport(
      selectedSubmission.value.id
    );
    const url = window.URL.createObjectURL(data);
    const link = document.createElement('a');
    link.href = url;
    link.download = `formulario-${selectedSubmission.value.id}.json`;
    link.click();
    window.URL.revokeObjectURL(url);
  } catch (downloadError) {
    error.value =
      downloadError.response?.data?.message || t('FORMS.ERROR.LOAD');
  } finally {
    isExportingSubmission.value = false;
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

function formatAuditAction(action) {
  const labels = {
    view: t('FORMS.SUBMISSIONS.ACCESS_ACTIONS.VIEW'),
    attachment_view: t('FORMS.SUBMISSIONS.ACCESS_ACTIONS.ATTACHMENT_VIEW'),
    export: t('FORMS.SUBMISSIONS.ACCESS_ACTIONS.EXPORT'),
    retention_discarded: t(
      'FORMS.SUBMISSIONS.ACCESS_ACTIONS.RETENTION_DISCARDED'
    ),
  };

  return labels[action] || action;
}

function formatFileSize(value) {
  if (!value) return '';

  return new Intl.NumberFormat(undefined, {
    style: 'unit',
    unit: 'kilobyte',
    maximumFractionDigits: 1,
  }).format(value / 1024);
}

function formatAttachmentMeta(attachment) {
  return attachment.byte_size
    ? `${attachment.content_type} · ${formatFileSize(attachment.byte_size)}`
    : attachment.content_type;
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
  // Voltava sem dizer nada: quem deixasse o identificador vazio carregava em
  // «Criar formulário» e não acontecia rigorosamente nada.
  if (!newTemplate.value.name.trim() || !newTemplate.value.slug.trim()) {
    createError.value = t('FORMS.ERROR.CREATE_NEEDS_NAME_AND_SLUG');
    return;
  }
  createError.value = '';

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
    createDialog.value?.close();
    selectTemplate(data);
    if (starterSchema) {
      editor.value.schema = clone(starterSchema);
      editor.value.schema.sections = editor.value.schema.sections.map(
        section => ({
          ...section,
          layout: section.layout || 'single',
          content_blocks: section.content_blocks || [],
        })
      );
      editor.value.crmDestinationEnabled = !isSensitiveHealth.value;
      selectedBuilderFieldKey.value =
        editor.value.schema.sections[0]?.fields[0]?.key || '';
      hasUnsavedChanges.value = true;
    }
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
    error.value = missingToPublish.value.length
      ? `${t('FORMS.ERROR.MISSING_TO_PUBLISH')} ${missingToPublish.value.join(' · ')}`
      : t('FORMS.ERROR.INVALID_CONFIGURATION');
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
    clearLocalDraft(editor.value.id);
    selectTemplate(data);
  } catch (saveError) {
    error.value = saveError.response?.data?.message || t('FORMS.ERROR.SAVE');
  } finally {
    isSaving.value = false;
  }
}

async function uploadBrandLogo(event) {
  const file = event.target.files?.[0];
  if (!file || !editor.value) return;

  isUploadingBrandLogo.value = true;
  error.value = '';
  try {
    const { data } = await FormsAPI.uploadTemplateLogo(editor.value.id, file);
    templates.value = templates.value.map(template =>
      template.id === data.id ? data : template
    );
    editor.value.brandLogoUrl = data.brand_logo_url;
  } catch (uploadError) {
    error.value = uploadError.response?.data?.message || t('FORMS.ERROR.SAVE');
  } finally {
    event.target.value = '';
    isUploadingBrandLogo.value = false;
  }
}

async function removeBrandLogo() {
  if (!editor.value) return;

  isUploadingBrandLogo.value = true;
  error.value = '';
  try {
    const { data } = await FormsAPI.removeTemplateLogo(editor.value.id);
    templates.value = templates.value.map(template =>
      template.id === data.id ? data : template
    );
    editor.value.brandLogoUrl = data.brand_logo_url || '';
  } catch (removeError) {
    error.value = removeError.response?.data?.message || t('FORMS.ERROR.SAVE');
  } finally {
    isUploadingBrandLogo.value = false;
  }
}

async function uploadContentImage(event) {
  const file = event.target.files?.[0];
  const contentBlock = selectedBuilderContentBlock.value;
  if (!file || !editor.value || !contentBlock || contentBlock.type !== 'image')
    return;

  isUploadingContentImage.value = true;
  error.value = '';
  try {
    const { data } = await FormsAPI.uploadTemplateContentImage(
      editor.value.id,
      file
    );
    contentBlock.url = data.url;
  } catch (uploadError) {
    error.value = uploadError.response?.data?.message || t('FORMS.ERROR.SAVE');
  } finally {
    event.target.value = '';
    isUploadingContentImage.value = false;
  }
}

function discardLocalDraft() {
  if (!editor.value) return;

  clearLocalDraft(editor.value.id);
  const template = templates.value.find(item => item.id === editor.value.id);
  if (template) selectTemplate(template);
}

watch(
  editor,
  value => {
    if (!value) return;

    const snapshot = JSON.stringify(value);
    if (snapshot === lastEditorSnapshot.value) return;

    hasUnsavedChanges.value = true;
    localDraftUpdatedAt.value = Date.now();
    window.localStorage.setItem(
      formDraftKey(value.id),
      JSON.stringify({
        editor: clone(value),
        updatedAt: localDraftUpdatedAt.value,
      })
    );
  },
  { deep: true }
);

function warnBeforeLeaving(event) {
  if (!hasUnsavedChanges.value) return;

  event.preventDefault();
  event.returnValue = '';
}

function addSection() {
  editor.value.schema.sections.push(
    defaultSection(editor.value.schema.sections.length + 1)
  );
  selectBuilderSection(editor.value.schema.sections.length - 1);
}

function addField(section, type = 'text') {
  const field = defaultField(section.fields.length + 1);
  field.type = type;
  section.fields.push(field);
  const sectionIndex = editor.value.schema.sections.indexOf(section);
  activeBuilderSectionIndex.value = sectionIndex;
  selectedBuilderFieldKey.value = section.fields.at(-1).key;
}

function addBuilderField(type) {
  if (!activeBuilderSection.value) return;

  addField(activeBuilderSection.value, type);
  builderSettingsDialog.value?.open();
}

// Do canvas, adicionar pergunta não abre diálogo: a pessoa continua escrevendo.
function addBuilderFieldInline(type = 'text') {
  if (!activeBuilderSection.value) return;

  addField(activeBuilderSection.value, type);
}

// Escolher o tipo passou a ser uma só porta: a biblioteca da coluna esquerda.
// Havia dois caminhos para a mesma ação — um diálogo e a biblioteca — e um
// deles ia divergir. Aqui torna-se a secção ativa e leva-se a pessoa à busca.
function focusBuilderLibrary(section) {
  activeBuilderSectionIndex.value =
    editor.value.schema.sections.indexOf(section);
  nextTick(() => builderLibraryRef.value?.focusSearch());
}

const contentBlockTypes = computed(() => [
  {
    value: 'heading',
    icon: 'i-lucide-heading',
    label: t('FORMS.CONTENT_BLOCKS.HEADING'),
  },
  {
    value: 'rich_text',
    icon: 'i-lucide-text',
    label: t('FORMS.CONTENT_BLOCKS.RICH_TEXT'),
  },
  {
    value: 'image',
    icon: 'i-lucide-image',
    label: t('FORMS.CONTENT_BLOCKS.IMAGE'),
  },
  {
    value: 'divider',
    icon: 'i-lucide-minus',
    label: t('FORMS.CONTENT_BLOCKS.DIVIDER'),
  },
]);

function uniqueContentBlockId(type) {
  const usedIds = new Set(
    editor.value.schema.sections.flatMap(section =>
      (section.content_blocks || []).map(block => block.id)
    )
  );
  let index = 2;
  let candidate = type;
  while (usedIds.has(candidate)) {
    candidate = `${type}_${index}`;
    index += 1;
  }
  return candidate;
}

function newContentBlock(type) {
  const id = uniqueContentBlockId(type);
  if (type === 'heading') {
    return {
      id,
      type,
      content: t('FORMS.CONTENT_BLOCKS.DEFAULT_HEADING'),
    };
  }
  if (type === 'rich_text') {
    return {
      id,
      type,
      content: t('FORMS.CONTENT_BLOCKS.DEFAULT_RICH_TEXT'),
    };
  }
  if (type === 'image') {
    return { id, type, url: '', alt: '', caption: '' };
  }

  return { id, type };
}

function addBuilderContentBlock(type) {
  if (!activeBuilderSection.value) return;

  const block = newContentBlock(type);
  activeBuilderSection.value.content_blocks ||= [];
  activeBuilderSection.value.content_blocks.push(block);
  selectBuilderContentBlock(block.id);
}

function removeSelectedBuilderContentBlock() {
  if (!selectedBuilderContentBlock.value || !activeBuilderSection.value) return;

  const blocks = activeBuilderSection.value.content_blocks || [];
  const index = blocks.indexOf(selectedBuilderContentBlock.value);
  blocks.splice(index, 1);
  selectedBuilderContentBlockId.value = '';
}

function contentBlockLabel(block) {
  if (block.type === 'heading') return block.content;
  if (block.type === 'rich_text') return t('FORMS.CONTENT_BLOCKS.RICH_TEXT');
  return (
    contentBlockTypes.value.find(type => type.value === block.type)?.label ||
    block.type
  );
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

function duplicateSelectedBuilderField() {
  if (!selectedBuilderField.value || !activeBuilderSection.value) return;

  const fields = activeBuilderSection.value.fields;
  const sourceIndex = fields.indexOf(selectedBuilderField.value);
  const usedKeys = new Set(formFields.value.map(field => field.key));
  const duplicate = clone(selectedBuilderField.value);
  duplicate.key = uniqueFieldKey(duplicate.key, usedKeys);
  fields.splice(sourceIndex + 1, 0, duplicate);
  selectedBuilderFieldKey.value = duplicate.key;
}

function removeSelectedBuilderField() {
  if (!selectedBuilderField.value || !activeBuilderSection.value) return;
  if (activeBuilderSection.value.fields.length === 1) return;

  const fields = activeBuilderSection.value.fields;
  const index = fields.indexOf(selectedBuilderField.value);
  fields.splice(index, 1);
  selectedBuilderFieldKey.value =
    fields[index]?.key || fields.at(-1)?.key || '';
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
  selectBuilderSection(editor.value.schema.sections.length - 1);
}

function addCustomFieldGroup(group) {
  if (!group?.section) return;

  const usedSectionKeys = new Set(
    editor.value.schema.sections.map(section => section.key)
  );
  const usedFieldKeys = new Set(formFields.value.map(field => field.key));
  const section = group.section;
  editor.value.schema.sections.push({
    key: uniqueFieldKey(section.key, usedSectionKeys),
    title: section.title,
    description: section.description || '',
    layout: section.layout || 'single',
    content_blocks: section.content_blocks || [],
    fields: section.fields.map(field => ({
      ...field,
      key: uniqueFieldKey(field.key, usedFieldKeys),
      options: field.options || [],
      helpText: field.help_text || '',
      contactTarget: '',
      customAttribute: '',
      opportunityTarget: '',
      visibleWhenField: '',
      visibleWhenValue: '',
    })),
  });
  selectBuilderSection(editor.value.schema.sections.length - 1);
}

function serializableFieldGroupSection() {
  const section = activeBuilderSection.value;
  if (!section) return null;

  return {
    key: section.key.trim(),
    title: section.title.trim(),
    ...(section.description?.trim()
      ? { description: section.description.trim() }
      : {}),
    layout: section.layout || 'single',
    content_blocks: section.content_blocks || [],
    fields: section.fields.map(field => ({
      key: field.key.trim(),
      label: field.label.trim(),
      type: field.type,
      required: Boolean(field.required),
      options: ['select', 'multi_select'].includes(field.type)
        ? field.options.filter(Boolean)
        : [],
      ...(field.helpText?.trim() ? { help_text: field.helpText.trim() } : {}),
    })),
  };
}

function openSaveFieldGroupDialog() {
  if (!activeBuilderSection.value) return;

  const section = serializableFieldGroupSection();
  if (!section.title || !section.fields.every(fieldIsValid)) {
    error.value = t('FORMS.ERROR.INVALID_CONFIGURATION');
    return;
  }

  fieldGroupForm.value = { name: section.title };
  saveFieldGroupDialog.value?.open();
}

async function saveCustomFieldGroup() {
  const section = serializableFieldGroupSection();
  if (!section || !fieldGroupForm.value.name.trim()) return;

  isSaving.value = true;
  error.value = '';
  try {
    const { data } = await FormsAPI.createFieldGroup({
      form_field_group: { name: fieldGroupForm.value.name.trim(), section },
    });
    customFieldGroups.value = [...customFieldGroups.value, data].sort(
      (left, right) => left.name.localeCompare(right.name)
    );
    saveFieldGroupDialog.value?.close();
  } catch (saveError) {
    error.value = saveError.response?.data?.message || t('FORMS.ERROR.SAVE');
  } finally {
    isSaving.value = false;
  }
}

function openDeleteFieldGroupDialog(group) {
  fieldGroupPendingDeletion.value = group;
  deleteFieldGroupDialog.value?.open();
}

async function deleteCustomFieldGroup() {
  const group = fieldGroupPendingDeletion.value;
  if (!group) return;

  isSaving.value = true;
  error.value = '';
  try {
    await FormsAPI.deleteFieldGroup(group.id);
    customFieldGroups.value = customFieldGroups.value.filter(
      item => item.id !== group.id
    );
    fieldGroupPendingDeletion.value = null;
    deleteFieldGroupDialog.value?.close();
  } catch (deleteError) {
    error.value = deleteError.response?.data?.message || t('FORMS.ERROR.SAVE');
  } finally {
    isSaving.value = false;
  }
}

function updateSelectedBuilderContentBlock({ key, value }) {
  if (!selectedBuilderContentBlock.value) return;

  selectedBuilderContentBlock.value[key] = value;
}

function updateSelectedBuilderField({ key, value }) {
  if (!selectedBuilderField.value) return;

  selectedBuilderField.value[key] = value;
}

function updateActiveBuilderSection({ key, value }) {
  if (!activeBuilderSection.value) return;

  activeBuilderSection.value[key] = value;
}

function onFieldTypeChanged(type) {
  if (!selectedBuilderField.value) return;

  selectedBuilderField.value.type = type;
  if (!['select', 'multi_select'].includes(type)) {
    selectedBuilderField.value.options = [];
  }
}

function moveSelectedBuilderSection(direction) {
  const targetIndex = activeBuilderSectionIndex.value + direction;
  const sections = editor.value?.schema.sections;
  if (!sections || targetIndex < 0 || targetIndex >= sections.length) return;

  const [section] = sections.splice(activeBuilderSectionIndex.value, 1);
  sections.splice(targetIndex, 0, section);
  activeBuilderSectionIndex.value = targetIndex;
}

function removeSelectedBuilderSection() {
  const sections = editor.value?.schema.sections;
  if (!sections || sections.length === 1) return;

  sections.splice(activeBuilderSectionIndex.value, 1);
  selectBuilderSection(
    Math.min(activeBuilderSectionIndex.value, sections.length - 1)
  );
}

function moveSelectedBuilderField(direction) {
  const fields = activeBuilderSection.value?.fields;
  if (!fields || !selectedBuilderField.value) return;

  const fieldIndex = fields.indexOf(selectedBuilderField.value);
  const targetIndex = fieldIndex + direction;
  if (targetIndex < 0 || targetIndex >= fields.length) return;

  const [field] = fields.splice(fieldIndex, 1);
  fields.splice(targetIndex, 0, field);
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
  window.addEventListener('beforeunload', warnBeforeLeaving);
  await Promise.all([
    loadTemplates(),
    loadCustomFieldGroups(),
    store.dispatch('kanbanBoards/fetchBoards'),
    store.dispatch('inboxes/get'),
    store.dispatch('agents/get'),
    store.dispatch('teams/get'),
  ]);
});

onBeforeUnmount(() => {
  window.removeEventListener('beforeunload', warnBeforeLeaving);
});
</script>

<template>
  <main class="flex h-full w-full min-w-0 flex-1 min-h-0 flex-col bg-n-solid-2">
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

    <!--
      Enquanto se edita, a lista de modelos recolhe: as três colunas do
      construtor dividiam o que sobrava e o formulário — a coluna que importa —
      ficava com menos de um terço da largura.
    -->
    <div
      class="grid min-h-0 flex-1 overflow-hidden"
      :class="isEditing ? 'grid-cols-1' : 'grid-cols-[15rem_minmax(0,1fr)]'"
    >
      <!--
        Recolher a zero deixava uma lasca visível: uma pista de grelha não
        impede o item de transbordar. Editar remove mesmo a lista.
      -->
      <aside
        v-if="!isEditing"
        class="flex min-h-0 min-w-0 flex-col border-r border-n-slate-4 bg-n-solid-1 p-3"
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
        <!--
          A largura de leitura serve ao cabeçalho e às configurações; ao
          construtor de três colunas ela custava 360px, que é mais do que a
          coluna do formulário inteira.
        -->
        <div
          class="space-y-6 pb-10"
          :class="isEditing ? 'w-full' : 'mx-auto max-w-5xl'"
        >
          <div class="flex items-start justify-between gap-4">
            <div class="flex min-w-0 items-start gap-2">
              <button
                type="button"
                class="mt-0.5 flex p-0 size-8 shrink-0 items-center justify-center rounded text-n-slate-11 transition hover:bg-n-slate-3 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-teal-6"
                :aria-label="t('FORMS.ACTIONS.BACK_TO_LIST')"
                :title="t('FORMS.ACTIONS.BACK_TO_LIST')"
                data-test="forms-back-to-list"
                @click="closeEditor"
              >
                <span class="i-lucide-arrow-left size-4" aria-hidden="true" />
              </button>
              <div class="min-w-0">
                <h2 class="text-xl font-semibold text-n-slate-12">
                  {{ editor.name }}
                </h2>
                <div
                  class="mt-1 flex flex-wrap items-center gap-x-2 gap-y-1 text-sm text-n-slate-10"
                  data-test="forms-status-line"
                >
                  <span
                    class="inline-flex items-center gap-1.5 rounded-full px-2 py-0.5 text-xs font-semibold"
                    :class="
                      isPublished
                        ? 'bg-n-teal-3 text-n-teal-11'
                        : 'bg-n-amber-3 text-n-amber-11'
                    "
                  >
                    <span
                      class="size-1.5 rounded-full bg-current"
                      aria-hidden="true"
                    />
                    {{
                      isPublished
                        ? t('FORMS.STATUS.PUBLISHED')
                        : t('FORMS.STATUS.DRAFT')
                    }}
                  </span>
                  <span>{{ statusLine }}</span>
                </div>
                <div
                  v-if="hasUnsavedChanges || localDraftRestored"
                  class="mt-2 flex items-center gap-2 text-xs text-n-amber-11"
                  data-test="forms-local-draft-status"
                >
                  <span
                    class="i-lucide-cloud-check size-3.5"
                    aria-hidden="true"
                  />
                  <span>
                    {{
                      localDraftRestored
                        ? t('FORMS.BUILDER.DRAFT_RESTORED')
                        : t('FORMS.BUILDER.DRAFT_SAVED')
                    }}
                  </span>
                  <button
                    type="button"
                    class="rounded px-1 font-medium underline-offset-2 hover:underline focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-teal-6"
                    @click="discardLocalDraft"
                  >
                    {{ t('FORMS.BUILDER.DISCARD_DRAFT') }}
                  </button>
                </div>
                <div
                  class="mt-3 inline-flex rounded border border-n-slate-4 bg-n-slate-2 p-1"
                  role="radiogroup"
                  :aria-label="t('FORMS.EDITOR.PRESENTATION')"
                >
                  <button
                    type="button"
                    class="min-h-9 whitespace-nowrap rounded-full px-3 text-sm font-medium transition focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-brand"
                    :class="
                      editor.settings.presentation === 'guided'
                        ? 'bg-n-solid-1 text-n-slate-12 shadow-sm'
                        : 'text-n-slate-10 hover:text-n-slate-12'
                    "
                    role="radio"
                    :aria-checked="editor.settings.presentation === 'guided'"
                    :title="t('FORMS.EDITOR.PRESENTATIONS.GUIDED_HINT')"
                    @click="editor.settings.presentation = 'guided'"
                  >
                    {{ t('FORMS.EDITOR.PRESENTATIONS.GUIDED') }}
                  </button>
                  <button
                    type="button"
                    class="min-h-9 whitespace-nowrap rounded-full px-3 text-sm font-medium transition focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-brand"
                    :class="
                      editor.settings.presentation === 'sectioned'
                        ? 'bg-n-solid-1 text-n-slate-12 shadow-sm'
                        : 'text-n-slate-10 hover:text-n-slate-12'
                    "
                    role="radio"
                    :aria-checked="editor.settings.presentation === 'sectioned'"
                    :title="t('FORMS.EDITOR.PRESENTATIONS.SECTIONED_HINT')"
                    @click="editor.settings.presentation = 'sectioned'"
                  >
                    {{ t('FORMS.EDITOR.PRESENTATIONS.SECTIONED') }}
                  </button>
                </div>
              </div>
            </div>
            <div class="flex shrink-0 items-center gap-2">
              <details class="relative">
                <summary
                  class="flex min-h-9 cursor-pointer list-none items-center gap-2 rounded border border-n-slate-5 bg-n-solid-1 px-3 text-sm font-medium text-n-slate-11 outline-none hover:bg-n-slate-2 focus-visible:ring-2 focus-visible:ring-n-teal-6 [&::-webkit-details-marker]:hidden"
                >
                  <span
                    class="i-lucide-list-checks size-4"
                    aria-hidden="true"
                  />
                  {{
                    t('FORMS.BUILDER.PUBLISHING_STATUS', {
                      completed: completedPublishingChecks,
                      total: publishingChecklist.length,
                    })
                  }}
                </summary>
                <div
                  class="absolute right-0 z-20 mt-2 w-72 rounded border border-n-slate-4 bg-n-solid-1 p-3 shadow-lg"
                >
                  <p class="text-sm font-semibold text-n-slate-12">
                    {{ t('FORMS.BUILDER.PUBLISHING_CHECKLIST') }}
                  </p>
                  <ul class="mt-3 grid gap-2">
                    <li
                      v-for="item in publishingChecklist"
                      :key="item.label"
                      class="flex items-start gap-2 text-sm"
                      :class="
                        item.complete ? 'text-n-slate-11' : 'text-n-ruby-11'
                      "
                    >
                      <span
                        :class="
                          item.complete
                            ? 'i-lucide-circle-check-big text-n-teal-10'
                            : 'i-lucide-circle-alert text-n-ruby-10'
                        "
                        class="mt-0.5 size-4 shrink-0"
                        aria-hidden="true"
                      />
                      {{ item.label }}
                    </li>
                  </ul>
                </div>
              </details>
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
              <!--
                Duplicar, Histórico e Abrir prévia saíram da linha: com seis
                botões de mesmo peso, nenhum era a ação principal. A prévia
                perdeu urgência porque o canvas já mostra o resultado real.
              -->
              <OnClickOutside @trigger="showFormActionsMenu = false">
                <div class="relative">
                  <button
                    type="button"
                    data-test="forms-actions-menu"
                    class="flex p-0 size-10 items-center justify-center rounded-full text-n-slate-11 outline-none hover:bg-n-alpha-2 hover:text-n-slate-12 focus-visible:ring-2 focus-visible:ring-n-brand"
                    :aria-label="t('FORMS.ACTIONS.MORE')"
                    :aria-expanded="showFormActionsMenu"
                    @click="showFormActionsMenu = !showFormActionsMenu"
                  >
                    <i class="i-lucide-ellipsis size-4" aria-hidden="true" />
                  </button>
                  <div
                    v-if="showFormActionsMenu"
                    data-test="forms-actions-menu-panel"
                    class="absolute end-0 z-30 mt-2 grid min-w-52 gap-1 rounded-lg border border-n-weak bg-n-solid-1 p-1.5 shadow-lg"
                  >
                    <button
                      type="button"
                      data-test="forms-open-private-preview"
                      class="flex items-center gap-2 rounded-md px-2.5 py-2 text-left text-sm text-n-slate-12 outline-none hover:bg-n-alpha-2 focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-n-brand"
                      @click="
                        showFormActionsMenu = false;
                        openPrivatePreview();
                      "
                    >
                      <i
                        class="i-lucide-eye size-4 text-n-slate-10"
                        aria-hidden="true"
                      />
                      {{ t('FORMS.ACTIONS.OPEN_PREVIEW') }}
                    </button>
                  </div>
                </div>
              </OnClickOutside>
              <Button
                :label="t('FORMS.ACTIONS.SAVE')"
                :is-loading="isSaving"
                @click="saveAndPublish"
              />
            </div>
          </div>

          <!--
            O canvas é o protagonista. A biblioteca continua disponível, mas
            recolhida: como coluna fixa de 16rem ela roubava largura do
            formulário e virava a porta de entrada, obrigando a escolher o tipo
            antes de escrever a pergunta.
          -->
          <!--
            Três colunas persistentes: estrutura, formulário e propriedades.
            Antes a estrutura era um painel absoluto por cima do canvas e as
            propriedades eram um modal — nenhuma das duas era coluna, e as duas
            tapavam justamente o formulário que a pessoa estava a escrever.
          -->
          <section
            data-test="forms-visual-builder"
            class="grid min-h-[38rem] items-start gap-3 lg:grid-cols-[15rem_minmax(0,1fr)_21rem]"
          >
            <aside
              class="max-h-[38rem] overflow-y-auto rounded-xl border border-n-weak bg-n-solid-1 p-3"
            >
              <div class="flex items-center justify-between gap-2">
                <h3 class="text-sm font-semibold text-n-slate-12">
                  {{ t('FORMS.BUILDER.STRUCTURE') }}
                </h3>
                <button
                  type="button"
                  class="inline-flex p-0 size-8 items-center justify-center rounded text-n-teal-11 transition hover:bg-n-teal-3 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-teal-6"
                  :aria-label="t('FORMS.BUILDER.ADD_SECTION')"
                  :title="t('FORMS.BUILDER.ADD_SECTION')"
                  @click="addSection"
                >
                  <span class="i-lucide-plus size-4" aria-hidden="true" />
                </button>
              </div>

              <FormsBlockLibrary
                ref="builderLibraryRef"
                :field-types="fieldTypes"
                :content-block-types="contentBlockTypes"
                :field-group-options="fieldGroupOptions"
                :custom-field-groups="customFieldGroups"
                class="mt-3"
                @add-field="addBuilderField"
                @add-content="addBuilderContentBlock"
                @add-group="addFieldGroup"
                @add-saved-group="addCustomFieldGroup"
                @delete-saved-group="openDeleteFieldGroupDialog"
              />

              <Draggable
                v-model="editor.schema.sections"
                item-key="key"
                tag="ol"
                handle=".forms-builder-section-drag"
                class="mt-3 space-y-3"
                ghost-class="opacity-40"
                @end="syncBuilderSelection"
              >
                <template #item="{ element: section, index: sectionIndex }">
                  <li
                    class="rounded border p-2"
                    :class="
                      sectionIndex === activeBuilderSectionIndex
                        ? 'border-n-teal-7 bg-n-teal-2'
                        : 'border-n-slate-4 bg-n-solid-1'
                    "
                  >
                    <button
                      type="button"
                      class="flex min-h-9 w-full items-center gap-2 rounded px-1 text-left text-sm font-semibold text-n-slate-12 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-teal-6"
                      :data-test="`forms-builder-section-${sectionIndex}`"
                      @click="selectBuilderSection(sectionIndex)"
                    >
                      <span
                        class="forms-builder-section-drag i-lucide-grip-vertical size-4 cursor-grab text-n-slate-9 active:cursor-grabbing"
                        aria-hidden="true"
                      />
                      <span class="min-w-0 break-words">
                        {{
                          section.title || t('FORMS.BUILDER.UNTITLED_SECTION')
                        }}
                      </span>
                    </button>
                    <ol
                      v-if="section.content_blocks?.length"
                      class="mt-1 space-y-1 border-l border-n-slate-4 pl-2"
                    >
                      <li
                        v-for="block in section.content_blocks"
                        :key="block.id"
                      >
                        <button
                          type="button"
                          class="flex min-h-8 w-full items-center gap-2 rounded px-2 text-left text-xs transition hover:bg-n-slate-3 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-teal-6"
                          :class="
                            block.id === selectedBuilderContentBlockId
                              ? 'bg-n-solid-1 font-semibold text-n-teal-11'
                              : 'text-n-slate-11'
                          "
                          :data-test="`forms-builder-content-${block.id}`"
                          @click="selectBuilderContentBlock(block.id)"
                        >
                          <span
                            class="i-lucide-align-left size-3.5 shrink-0 text-n-slate-9"
                            aria-hidden="true"
                          />
                          <span class="min-w-0 break-words">
                            {{ contentBlockLabel(block) }}
                          </span>
                        </button>
                      </li>
                    </ol>
                    <Draggable
                      v-model="section.fields"
                      item-key="key"
                      tag="ol"
                      handle=".forms-builder-field-drag"
                      class="mt-1 space-y-1 border-l border-n-slate-4 pl-2"
                      ghost-class="opacity-40"
                      @end="syncBuilderSelection"
                    >
                      <template #item="{ element: field }">
                        <li>
                          <button
                            type="button"
                            class="flex min-h-8 w-full items-center gap-2 rounded px-2 text-left text-xs transition hover:bg-n-slate-3 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-teal-6"
                            :class="
                              field.key === selectedBuilderFieldKey
                                ? 'bg-n-solid-1 font-semibold text-n-teal-11'
                                : 'text-n-slate-11'
                            "
                            :data-test="`forms-builder-field-${field.key}`"
                            @click="selectBuilderField(field.key)"
                          >
                            <span
                              class="forms-builder-field-drag i-lucide-grip-vertical size-3.5 shrink-0 cursor-grab text-n-slate-9 active:cursor-grabbing"
                              aria-hidden="true"
                            />
                            <span class="min-w-0 break-words">
                              {{
                                field.label || t('FORMS.BUILDER.UNTITLED_FIELD')
                              }}
                            </span>
                          </button>
                        </li>
                      </template>
                    </Draggable>
                    <button
                      type="button"
                      class="mt-2 inline-flex min-h-8 items-center gap-1 rounded px-2 text-xs font-medium text-n-slate-11 transition hover:bg-n-slate-3 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-teal-6"
                      :data-test="`forms-builder-add-content-${sectionIndex}`"
                      @click="focusBuilderLibrary(section)"
                    >
                      <span
                        class="i-lucide-text-cursor-input size-3.5"
                        aria-hidden="true"
                      />
                      {{ t('FORMS.CONTENT_BLOCKS.ADD') }}
                    </button>
                    <button
                      type="button"
                      class="mt-2 inline-flex min-h-8 items-center gap-1 rounded px-2 text-xs font-medium text-n-teal-11 transition hover:bg-n-teal-3 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-teal-6"
                      :data-test="`forms-builder-add-question-${sectionIndex}`"
                      @click="focusBuilderLibrary(section)"
                    >
                      <span class="i-lucide-plus size-3.5" aria-hidden="true" />
                      {{ t('FORMS.BUILDER.ADD_QUESTION') }}
                    </button>
                  </li>
                </template>
              </Draggable>
              <Button
                class="mt-3 w-full"
                size="sm"
                variant="faded"
                color="slate"
                :label="t('FORMS.ACTIONS.ADD_GROUP')"
                icon="i-lucide-layout-template"
                @click="focusBuilderLibrary(activeBuilderSection)"
              />
              <button
                type="button"
                class="mt-2 inline-flex min-h-9 w-full items-center justify-center gap-2 rounded px-3 text-sm font-medium text-n-slate-11 transition hover:bg-n-slate-3 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-teal-6"
                @click="openSaveFieldGroupDialog"
              >
                <span
                  class="i-lucide-bookmark-plus size-4"
                  aria-hidden="true"
                />
                {{ t('FORMS.ACTIONS.SAVE_GROUP') }}
              </button>
            </aside>

            <FormsCanvasEditor
              :editor="editor"
              :active-section-index="activeBuilderSectionIndex"
              :selected-field-key="selectedBuilderFieldKey"
              :field-types="fieldTypes"
              @select-section="selectBuilderSection"
              @select-field="selectBuilderField"
              @add-section="addSection"
              @add-field="addBuilderFieldInline"
              @remove-field="removeSelectedBuilderField"
              @duplicate-field="duplicateSelectedBuilderField"
              @move-field="moveSelectedBuilderField($event.to - $event.from)"
              @open-settings="builderSettingsDialog?.open()"
            />

            <FormsBuilderSettingsDialog
              ref="builderSettingsDialog"
              inline
              class="max-h-[38rem]"
              :content-block="selectedBuilderContentBlock"
              :field="selectedBuilderField"
              :section="activeBuilderSection"
              :section-index="activeBuilderSectionIndex"
              :section-count="editor.schema.sections.length"
              :field-index="
                activeBuilderSection?.fields.indexOf(selectedBuilderField) ?? -1
              "
              :field-count="activeBuilderSection?.fields.length || 0"
              :field-types="fieldTypes"
              :contact-mappings="contactMappings"
              :condition-fields="
                selectedBuilderField
                  ? conditionFieldOptions(selectedBuilderField)
                  : []
              "
              :condition-values="
                selectedBuilderField
                  ? conditionValueOptions(selectedBuilderField)
                  : []
              "
              :opportunity-fields="
                selectedBuilderField
                  ? opportunityFieldOptions(selectedBuilderField)
                  : []
              "
              :fields="allBuilderFields"
              :logics="editor.schema.logics || []"
              :variables="editor.schema.variables || []"
              :endings="editor.schema.endings || []"
              :hidden-fields="editor.schema.hidden_fields || []"
              :settings="editor.settings"
              :form-name="editor.name"
              :brand-logo-url="editor.brandLogoUrl || ''"
              :is-uploading-brand-logo="isUploadingBrandLogo"
              :can-map-to-crm="!isSensitiveHealth"
              :is-uploading-content-image="isUploadingContentImage"
              @upload-content-image="uploadContentImage"
              @remove-content-block="removeSelectedBuilderContentBlock"
              @update-content-block="updateSelectedBuilderContentBlock"
              @update-field="updateSelectedBuilderField"
              @update-section="updateActiveBuilderSection"
              @field-type-changed="onFieldTypeChanged"
              @move-section="moveSelectedBuilderSection"
              @remove-section="removeSelectedBuilderSection"
              @move-field="moveSelectedBuilderField"
              @duplicate-field="duplicateSelectedBuilderField"
              @remove-field="removeSelectedBuilderField"
              @update-logics="updateSchemaLogics"
              @update-variables="updateSchemaVariables"
              @update-settings="updateEditorSettings"
              @upload-brand-logo="uploadBrandLogo"
              @remove-brand-logo="removeBrandLogo"
            />
          </section>

          <!--
            As configurações deixam de ser um acordeão onde tudo aparecia de
            uma vez. Navegação à esquerda, uma secção de cada vez à direita —
            quem procura o destino do CRM não passa pela marca nem pelo acesso
            clínico para lá chegar.
          -->
          <div
            class="grid gap-4 rounded border border-n-slate-4 bg-n-solid-1 p-4 md:grid-cols-[13rem_minmax(0,1fr)]"
            data-test="forms-advanced-settings"
          >
            <nav
              class="grid content-start gap-1"
              :aria-label="t('FORMS.BUILDER.ADVANCED')"
            >
              <button
                v-for="item in settingsSections"
                :key="item.id"
                type="button"
                class="flex min-h-9 items-center rounded px-3 text-start text-sm font-medium transition"
                :class="
                  settingsSection === item.id
                    ? 'bg-n-teal-3 text-n-teal-11'
                    : 'text-n-slate-11 hover:bg-n-slate-3'
                "
                :aria-current="settingsSection === item.id ? 'page' : undefined"
                :data-test="`forms-settings-nav-${item.id}`"
                @click="settingsSection = item.id"
              >
                {{ item.label }}
              </button>
            </nav>
            <div class="min-w-0 space-y-5">
              <section class="rounded border border-n-slate-4 bg-n-solid-1 p-5">
                <div v-show="settingsSection === 'identity'">
                  <h3 class="text-sm font-semibold text-n-slate-12">
                    {{ t('FORMS.EDITOR.DETAILS') }}
                  </h3>
                  <div class="mt-4 grid gap-4 md:grid-cols-2">
                    <label
                      class="grid gap-1.5 text-sm font-medium text-n-slate-11"
                    >
                      {{ t('FORMS.NEW_DIALOG.NAME') }}
                      <input
                        v-model="editor.name"
                        class="min-h-10 rounded border border-n-slate-5 bg-n-solid-1 px-3 text-n-slate-12 outline-none focus:border-n-teal-9 focus:ring-2 focus:ring-n-teal-6"
                      />
                    </label>
                    <label
                      class="grid gap-1.5 text-sm font-medium text-n-slate-11"
                    >
                      {{ t('FORMS.NEW_DIALOG.SLUG') }}
                      <input
                        v-model="editor.slug"
                        class="min-h-10 rounded border border-n-slate-5 bg-n-solid-1 px-3 text-n-slate-12 outline-none focus:border-n-teal-9 focus:ring-2 focus:ring-n-teal-6"
                      />
                    </label>
                    <label
                      class="grid gap-1.5 text-sm font-medium text-n-slate-11"
                    >
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
                    <label
                      class="grid gap-1.5 text-sm font-medium text-n-slate-11"
                    >
                      {{ t('FORMS.EDITOR.LOCALE') }}
                      <select
                        v-model="editor.settings.locale"
                        class="min-h-10 rounded border border-n-slate-5 bg-n-solid-1 px-3 text-n-slate-12 outline-none focus:border-n-teal-9 focus:ring-2 focus:ring-n-teal-6"
                      >
                        <option value="pt_BR">
                          {{ t('FORMS.LOCALES.PT_BR') }}
                        </option>
                        <option value="pt_PT">
                          {{ t('FORMS.LOCALES.PT_PT') }}
                        </option>
                      </select>
                    </label>
                  </div>
                </div>
                <div v-show="settingsSection === 'publishing'">
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
                    class="mt-4 grid gap-1.5 text-sm font-medium text-n-slate-11"
                  >
                    {{ t('FORMS.EDITOR.PRIVACY_POLICY_URL') }}
                    <input
                      v-model="editor.settings.privacy_policy_url"
                      type="url"
                      :placeholder="
                        t('FORMS.EDITOR.PRIVACY_POLICY_URL_PLACEHOLDER')
                      "
                      class="min-h-10 rounded border border-n-slate-5 bg-n-solid-1 px-3 text-n-slate-12 outline-none focus:border-n-teal-9 focus:ring-2 focus:ring-n-teal-6"
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
                  <div
                    v-if="editor.publicEnabled && !isSensitiveHealth"
                    class="mt-4 grid gap-3 rounded border border-n-slate-4 bg-n-slate-2 p-3 lg:grid-cols-2"
                  >
                    <label
                      class="grid gap-1.5 text-sm font-medium text-n-slate-11"
                    >
                      {{ t('FORMS.EDITOR.CAPTCHA_PROVIDER') }}
                      <select
                        v-model="editor.settings.captcha_provider"
                        class="min-h-10 rounded border border-n-slate-5 bg-n-solid-1 px-3 text-n-slate-12 outline-none focus:border-n-teal-9 focus:ring-2 focus:ring-n-teal-6"
                      >
                        <option value="">
                          {{ t('FORMS.EDITOR.CAPTCHA_DISABLED') }}
                        </option>
                        <option value="turnstile">
                          {{ t('FORMS.EDITOR.CAPTCHA_TURNSTILE') }}
                        </option>
                      </select>
                    </label>
                    <label
                      class="grid gap-1.5 text-sm font-medium text-n-slate-11"
                    >
                      {{ t('FORMS.EDITOR.CAPTCHA_SITE_KEY') }}
                      <input
                        v-model="editor.settings.captcha_site_key"
                        :disabled="!editor.settings.captcha_provider"
                        type="text"
                        class="min-h-10 rounded border border-n-slate-5 bg-n-solid-1 px-3 text-n-slate-12 outline-none focus:border-n-teal-9 focus:ring-2 focus:ring-n-teal-6 disabled:cursor-not-allowed disabled:bg-n-slate-3"
                      />
                    </label>
                  </div>
                </div>
                <div v-show="settingsSection === 'automation'">
                  <label
                    v-if="!isSensitiveHealth"
                    class="mt-4 grid gap-1.5 text-sm font-medium text-n-slate-11"
                  >
                    {{ t('FORMS.EDITOR.ABANDONMENT_DELAY_HOURS') }}
                    <input
                      v-model.number="editor.settings.abandonment_delay_hours"
                      type="number"
                      min="1"
                      max="720"
                      class="min-h-10 rounded border border-n-slate-5 bg-n-solid-1 px-3 text-n-slate-12 outline-none focus:border-n-teal-9 focus:ring-2 focus:ring-n-teal-6"
                      :placeholder="t('FORMS.EDITOR.ABANDONMENT_DISABLED')"
                    />
                    <span class="text-xs font-normal leading-5 text-n-slate-10">
                      {{ t('FORMS.EDITOR.ABANDONMENT_HINT') }}
                    </span>
                  </label>
                  <div
                    v-if="!isSensitiveHealth"
                    class="mt-4 grid gap-3 rounded border border-n-slate-4 bg-n-slate-2 p-3 lg:grid-cols-2"
                  >
                    <label
                      class="grid gap-1.5 text-sm font-medium text-n-slate-11"
                    >
                      {{ t('FORMS.EDITOR.CRITICAL_RESPONSE_FIELD') }}
                      <select
                        v-model="editor.settings.critical_response.field_key"
                        class="min-h-10 rounded border border-n-slate-5 bg-n-solid-1 px-3 text-n-slate-12 outline-none focus:border-n-teal-9 focus:ring-2 focus:ring-n-teal-6"
                        @change="editor.settings.critical_response.value = ''"
                      >
                        <option value="">
                          {{ t('FORMS.EDITOR.CRITICAL_RESPONSE_DISABLED') }}
                        </option>
                        <option
                          v-for="field in criticalResponseFields"
                          :key="field.key"
                          :value="field.key"
                        >
                          {{ field.label || field.key }}
                        </option>
                      </select>
                    </label>
                    <label
                      class="grid gap-1.5 text-sm font-medium text-n-slate-11"
                    >
                      {{ t('FORMS.EDITOR.CRITICAL_RESPONSE_VALUE') }}
                      <select
                        v-if="criticalResponseOptions.length"
                        v-model="editor.settings.critical_response.value"
                        :disabled="!editor.settings.critical_response.field_key"
                        class="min-h-10 rounded border border-n-slate-5 bg-n-solid-1 px-3 text-n-slate-12 outline-none focus:border-n-teal-9 focus:ring-2 focus:ring-n-teal-6 disabled:cursor-not-allowed disabled:bg-n-slate-3"
                      >
                        <option value="">
                          {{ t('FORMS.EDITOR.CRITICAL_RESPONSE_SELECT_VALUE') }}
                        </option>
                        <option
                          v-for="option in criticalResponseOptions"
                          :key="option"
                          :value="option"
                        >
                          {{ option }}
                        </option>
                      </select>
                      <input
                        v-else
                        v-model="editor.settings.critical_response.value"
                        :disabled="!editor.settings.critical_response.field_key"
                        type="text"
                        class="min-h-10 rounded border border-n-slate-5 bg-n-solid-1 px-3 text-n-slate-12 outline-none focus:border-n-teal-9 focus:ring-2 focus:ring-n-teal-6 disabled:cursor-not-allowed disabled:bg-n-slate-3"
                      />
                    </label>
                    <p class="text-xs leading-5 text-n-slate-10 lg:col-span-2">
                      {{ t('FORMS.EDITOR.CRITICAL_RESPONSE_HINT') }}
                    </p>
                  </div>
                  <p
                    v-else
                    class="mt-4 rounded border border-n-amber-6 bg-n-amber-2 px-3 py-2 text-sm text-n-amber-11"
                  >
                    {{ t('FORMS.EDITOR.SENSITIVE_HEALTH_NOTICE') }}
                  </p>
                  <div class="mt-5 border-t border-n-slate-4 pt-5">
                    <FormsSubmissionActions
                      :actions="editor.schema.submission_actions || []"
                      :stages="stageOptions"
                      :is-sensitive-health="isSensitiveHealth"
                      @update="updateSubmissionActions"
                    />
                  </div>
                </div>
                <div v-show="settingsSection === 'clinical'">
                  <section
                    v-if="isSensitiveHealth"
                    data-test="forms-clinical-access"
                    class="mt-4 rounded border border-n-slate-4 bg-n-slate-2 p-4"
                  >
                    <div class="flex items-start justify-between gap-3">
                      <div>
                        <h4 class="text-sm font-semibold text-n-slate-12">
                          {{ t('FORMS.EDITOR.CLINICAL_ACCESS') }}
                        </h4>
                        <p class="mt-1 text-sm leading-6 text-n-slate-10">
                          {{ t('FORMS.EDITOR.CLINICAL_ACCESS_DESCRIPTION') }}
                        </p>
                      </div>
                      <span
                        class="shrink-0 rounded-full bg-n-teal-3 px-2.5 py-1 text-xs font-semibold text-n-teal-11"
                      >
                        {{
                          t('FORMS.EDITOR.CLINICAL_ACCESS_SELECTED', {
                            count: clinicalAccessSelectionCount,
                          })
                        }}
                      </span>
                    </div>
                    <div class="mt-3">
                      <label class="sr-only" for="forms-clinical-access-search">
                        {{ t('FORMS.EDITOR.CLINICAL_ACCESS_SEARCH') }}
                      </label>
                      <input
                        id="forms-clinical-access-search"
                        v-model="clinicalAccessSearch"
                        data-test="forms-clinical-access-search"
                        type="search"
                        :placeholder="t('FORMS.EDITOR.CLINICAL_ACCESS_SEARCH')"
                        class="min-h-10 w-full rounded border border-n-slate-5 bg-n-solid-1 px-3 text-sm text-n-slate-12 outline-none placeholder:text-n-slate-9 focus:border-n-teal-9 focus:ring-2 focus:ring-n-teal-6"
                      />
                    </div>
                    <div class="mt-4 grid gap-4 lg:grid-cols-2">
                      <fieldset
                        class="rounded border border-n-slate-4 bg-n-solid-1 p-3"
                      >
                        <legend
                          class="px-1 text-sm font-medium text-n-slate-11"
                        >
                          {{ t('FORMS.EDITOR.CLINICAL_ACCESS_USERS') }}
                        </legend>
                        <div
                          class="mt-2 grid max-h-52 gap-1 overflow-y-auto pr-1"
                        >
                          <label
                            v-for="agent in clinicalAccessAgents"
                            :key="agent.id"
                            class="flex min-h-9 items-center gap-2 rounded px-2 text-sm text-n-slate-11 transition hover:bg-n-solid-1"
                          >
                            <input
                              v-model="editor.settings.clinical_access.user_ids"
                              :data-test="`forms-clinical-access-user-${agent.id}`"
                              :value="agent.id"
                              type="checkbox"
                              class="size-4 accent-n-teal-9"
                            />
                            <span class="min-w-0 break-words">{{
                              agent.name
                            }}</span>
                          </label>
                          <p
                            v-if="!clinicalAccessAgents.length"
                            class="text-sm text-n-slate-10"
                          >
                            {{ t('FORMS.EDITOR.CLINICAL_ACCESS_EMPTY_USERS') }}
                          </p>
                        </div>
                      </fieldset>
                      <fieldset
                        class="rounded border border-n-slate-4 bg-n-solid-1 p-3"
                      >
                        <legend
                          class="px-1 text-sm font-medium text-n-slate-11"
                        >
                          {{ t('FORMS.EDITOR.CLINICAL_ACCESS_TEAMS') }}
                        </legend>
                        <div
                          class="mt-2 grid max-h-52 gap-1 overflow-y-auto pr-1"
                        >
                          <label
                            v-for="team in clinicalAccessTeams"
                            :key="team.id"
                            class="flex min-h-9 items-center gap-2 rounded px-2 text-sm text-n-slate-11 transition hover:bg-n-solid-1"
                          >
                            <input
                              v-model="editor.settings.clinical_access.team_ids"
                              :data-test="`forms-clinical-access-team-${team.id}`"
                              :value="team.id"
                              type="checkbox"
                              class="size-4 accent-n-teal-9"
                            />
                            <span class="min-w-0 break-words">{{
                              team.name
                            }}</span>
                          </label>
                          <p
                            v-if="!clinicalAccessTeams.length"
                            class="text-sm text-n-slate-10"
                          >
                            {{ t('FORMS.EDITOR.CLINICAL_ACCESS_EMPTY_TEAMS') }}
                          </p>
                        </div>
                      </fieldset>
                    </div>
                    <label
                      class="mt-4 block"
                      for="forms-clinical-retention-days"
                    >
                      <span class="block text-sm font-medium text-n-slate-12">
                        {{ t('FORMS.EDITOR.CLINICAL_RETENTION_DAYS') }}
                      </span>
                      <span class="mt-1 block text-sm text-n-slate-10">
                        {{ t('FORMS.EDITOR.CLINICAL_RETENTION_HINT') }}
                      </span>
                      <input
                        id="forms-clinical-retention-days"
                        v-model.number="editor.settings.clinical_retention_days"
                        data-test="forms-clinical-retention-days"
                        type="number"
                        min="1"
                        inputmode="numeric"
                        :placeholder="
                          t('FORMS.EDITOR.CLINICAL_RETENTION_PLACEHOLDER')
                        "
                        class="mt-2 min-h-10 w-full rounded border border-n-slate-5 bg-n-solid-1 px-3 text-sm text-n-slate-12 outline-none placeholder:text-n-slate-9 focus:border-n-teal-9 focus:ring-2 focus:ring-n-teal-6"
                      />
                    </label>
                  </section>
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
                </div>
              </section>

              <div v-show="settingsSection === 'destination'">
                <section
                  v-if="!isSensitiveHealth"
                  class="rounded border border-n-slate-4 bg-n-solid-1 p-5"
                >
                  <div class="flex items-start gap-3">
                    <span
                      class="i-lucide-route mt-0.5 size-4 shrink-0 text-n-teal-10"
                      aria-hidden="true"
                    />
                    <div>
                      <h3 class="text-sm font-semibold text-n-slate-12">
                        {{ t('FORMS.EDITOR.DESTINATION') }}
                      </h3>
                      <p class="mt-1 text-sm leading-6 text-n-slate-10">
                        {{ t('FORMS.EDITOR.DESTINATION_REQUIRED') }}
                      </p>
                    </div>
                  </div>
                  <div class="mt-4 grid gap-4 md:grid-cols-2">
                    <label
                      class="grid gap-1.5 text-sm font-medium text-n-slate-11"
                    >
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
                    <label
                      class="grid gap-1.5 text-sm font-medium text-n-slate-11"
                    >
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
                    <label
                      class="grid gap-1.5 text-sm font-medium text-n-slate-11"
                    >
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
                    <label
                      class="grid gap-1.5 text-sm font-medium text-n-slate-11"
                    >
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
                    v-if="selectedBoardCustomFields.length"
                    class="mt-3 text-sm leading-6 text-n-slate-10"
                  >
                    {{ t('FORMS.EDITOR.OPPORTUNITY_MAPPING_HELP') }}
                  </p>
                </section>
              </div>
            </div>
          </div>
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
    <p
      v-if="createError"
      class="mb-0 rounded border border-n-ruby-6 bg-n-ruby-2 px-3 py-2 text-sm text-n-ruby-11"
      role="alert"
      data-test="forms-create-error"
    >
      {{ createError }}
    </p>
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
    <div v-else class="grid gap-6">
      <div class="flex justify-end">
        <Button
          data-test="forms-export-submission"
          size="sm"
          variant="faded"
          color="slate"
          :label="t('FORMS.SUBMISSIONS.EXPORT')"
          icon="i-lucide-download"
          :is-loading="isExportingSubmission"
          @click="downloadSubmissionExport"
        />
      </div>
      <section
        v-for="section in selectedSubmissionSections"
        :key="section.title"
        class="rounded border border-n-slate-4 bg-n-solid-1"
      >
        <h3
          class="border-b border-n-slate-4 px-4 py-3 text-sm font-semibold text-n-slate-12"
        >
          {{ section.title }}
        </h3>
        <dl class="divide-y divide-n-slate-4 px-4">
          <div v-for="field in section.fields" :key="field.key" class="py-3">
            <dt
              class="text-xs font-medium uppercase tracking-wide text-n-slate-10"
            >
              {{ field.label }}
            </dt>
            <dd
              class="mt-1 whitespace-pre-wrap break-words text-sm leading-6 text-n-slate-12"
            >
              {{ formatAnswer(selectedSubmission.answers[field.key]) }}
            </dd>
          </div>
        </dl>
      </section>
      <section
        v-if="selectedSubmission.consent_snapshot?.length"
        class="rounded border border-n-slate-4 bg-n-solid-1"
      >
        <h3
          class="border-b border-n-slate-4 px-4 py-3 text-sm font-semibold text-n-slate-12"
        >
          {{ t('FORMS.SUBMISSIONS.CLINICAL_CONSENT') }}
        </h3>
        <dl class="divide-y divide-n-slate-4 px-4">
          <div
            v-for="consent in selectedSubmission.consent_snapshot"
            :key="consent.key"
            class="py-3"
          >
            <dt
              class="text-xs font-medium uppercase tracking-wide text-n-slate-10"
            >
              {{ consent.label }}
            </dt>
            <dd class="mt-1 text-sm leading-6 text-n-slate-12">
              {{
                consent.type === 'signature'
                  ? consent.value
                  : t('FORMS.SUBMISSIONS.CONSENT_ACCEPTED')
              }}
            </dd>
            <p class="mt-1 text-xs text-n-slate-10">
              {{
                t('FORMS.SUBMISSIONS.CONSENT_RECORDED_AT', {
                  date: formatSubmissionDate(consent.recorded_at),
                })
              }}
            </p>
          </div>
        </dl>
      </section>
      <section
        v-if="selectedSubmission.attachments?.length"
        class="rounded border border-n-slate-4 bg-n-solid-1"
      >
        <h3
          class="border-b border-n-slate-4 px-4 py-3 text-sm font-semibold text-n-slate-12"
        >
          {{ t('FORMS.SUBMISSIONS.CLINICAL_DOCUMENTS') }}
        </h3>
        <ul class="divide-y divide-n-slate-4">
          <li
            v-for="attachment in selectedSubmission.attachments"
            :key="attachment.id"
            class="flex items-center justify-between gap-3 px-4 py-3"
          >
            <div class="min-w-0">
              <p class="break-all text-sm font-medium text-n-slate-12">
                {{ attachment.filename }}
              </p>
              <p class="mt-0.5 text-xs text-n-slate-10">
                {{ formatAttachmentMeta(attachment) }}
              </p>
            </div>
            <Button
              size="sm"
              variant="faded"
              color="slate"
              :label="t('FORMS.SUBMISSIONS.DOWNLOAD')"
              icon="i-lucide-download"
              @click="downloadClinicalAttachment(attachment)"
            />
          </li>
        </ul>
      </section>
      <section
        v-if="selectedSubmission.audit_trail?.length"
        class="rounded border border-n-slate-4 bg-n-solid-1"
      >
        <h3
          class="border-b border-n-slate-4 px-4 py-3 text-sm font-semibold text-n-slate-12"
        >
          {{ t('FORMS.SUBMISSIONS.ACCESS_HISTORY') }}
        </h3>
        <ul class="divide-y divide-n-slate-4">
          <li
            v-for="audit in selectedSubmission.audit_trail"
            :key="audit.id"
            class="flex items-start justify-between gap-4 px-4 py-3"
          >
            <div class="min-w-0">
              <p class="text-sm font-medium text-n-slate-12">
                {{ formatAuditAction(audit.action) }}
              </p>
              <p class="mt-0.5 text-xs text-n-slate-10">
                {{ audit.actor?.name || t('FORMS.SUBMISSIONS.SYSTEM') }}
              </p>
            </div>
            <time class="shrink-0 text-xs text-n-slate-10">
              {{ formatSubmissionDate(audit.occurred_at) }}
            </time>
          </li>
        </ul>
      </section>
    </div>
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
    ref="saveFieldGroupDialog"
    data-test="forms-save-field-group-dialog"
    :title="t('FORMS.FIELD_GROUPS.SAVE_TITLE')"
    :description="t('FORMS.FIELD_GROUPS.SAVE_DESCRIPTION')"
    :confirm-button-label="t('FORMS.FIELD_GROUPS.SAVE')"
    :is-loading="isSaving"
    @confirm="saveCustomFieldGroup"
  >
    <label class="grid gap-1.5 text-sm font-medium text-n-slate-11">
      {{ t('FORMS.FIELD_GROUPS.NAME') }}
      <input
        v-model="fieldGroupForm.name"
        class="min-h-10 rounded border border-n-slate-5 bg-n-solid-1 px-3 text-n-slate-12 outline-none focus:border-n-teal-9 focus:ring-2 focus:ring-n-teal-6"
      />
    </label>
  </Dialog>

  <Dialog
    ref="deleteFieldGroupDialog"
    :title="t('FORMS.FIELD_GROUPS.DELETE_TITLE')"
    :description="
      t('FORMS.FIELD_GROUPS.DELETE_DESCRIPTION', {
        name: fieldGroupPendingDeletion?.name || '',
      })
    "
    :confirm-button-label="t('FORMS.ACTIONS.REMOVE')"
    :is-loading="isSaving"
    @confirm="deleteCustomFieldGroup"
  />

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
