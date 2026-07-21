<script setup>
import { computed, onMounted, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import camelcaseKeys from 'camelcase-keys';
import Draggable from 'vuedraggable';

import { useAlert } from 'dashboard/composables';
import { useAdmin } from 'dashboard/composables/useAdmin';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import KanbanBoardsAPI from 'dashboard/api/kanbanBoards';
import Button from 'dashboard/components-next/button/Button.vue';
import TagMultiSelectComboBox from 'dashboard/components-next/combobox/TagMultiSelectComboBox.vue';
import {
  DEFAULT_KANBAN_STAGE_COLOR,
  KANBAN_STAGE_COLOR_OPTIONS,
  getKanbanStageColorOption,
} from 'dashboard/helper/kanbanStageColors';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const store = useStore();

const agents = useMapGetter('agents/getAgents');
const inboxes = useMapGetter('inboxes/getAllInboxes');
const { isAdmin } = useAdmin();

const isLoading = ref(false);
const isSaving = ref(false);
const isSavingAutomation = ref(false);
const isDeleting = ref(false);
const isCreatingStage = ref(false);
const isImportingConversations = ref(false);
const loadError = ref('');
const saveError = ref('');
const stageError = ref('');
const importError = ref('');
const showDeleteConfirmation = ref(false);
const showCreateStageForm = ref(false);
const showImportExistingConversationsModal = ref(false);
const stages = ref([]);
const newStageName = ref('');
const newStageColor = ref(DEFAULT_KANBAN_STAGE_COLOR);
const activeStageActionKey = ref('');
const ignoreGroupsForImport = ref(false);
const activeFormulaFieldId = ref(null);
const activeFormulaSuggestionIndex = ref(0);
const showCustomFieldManager = ref(false);
const selectedCustomFieldId = ref(null);
const newCustomFieldOption = ref('');
const showNewFieldSectionForm = ref(false);
const newFieldSectionName = ref('');
let customFieldRowSequence = 0;

const nextCustomFieldRowId = () => {
  customFieldRowSequence += 1;
  return `custom-field-${customFieldRowSequence}`;
};

const form = reactive({
  name: '',
  description: '',
  autoCreateCardsFromConversations: false,
  visibilityMode: 'all_agents',
  visibleUserIds: [],
  inboxScopeMode: 'all_inboxes',
  allowedInboxIds: [],
  nextActionTypesText: '',
  lostReasonOptionsText: '',
  customFieldDefinitionsText: '',
  customFieldDefinitions: [],
  customFieldSections: [],
  compactCardFieldKeys: [],
  staleStageThresholds: {},
});

const boardId = computed(() => Number(route.params.boardId));
const stageListModel = computed({
  get: () => stages.value,
  set: nextStages => {
    stages.value = nextStages;
  },
});
const selectedCustomField = computed(() =>
  form.customFieldDefinitions.find(
    definition => definition.clientId === selectedCustomFieldId.value
  )
);

const agentOptions = computed(() =>
  agents.value.map(agent => ({
    value: agent.id,
    label: agent.name || agent.email,
  }))
);

const inboxOptions = computed(() =>
  inboxes.value.map(inbox => ({
    value: inbox.id,
    label: inbox.name,
  }))
);

const linesFromText = value =>
  String(value || '')
    .split('\n')
    .map(item => item.trim())
    .filter(Boolean);

const systemConditionFields = computed(() => [
  {
    key: 'system_subject',
    label: t('KANBAN.SETTINGS.SALES.SYSTEM_FIELDS.SUBJECT'),
    fieldType: 'text',
  },
  {
    key: 'system_description',
    label: t('KANBAN.SETTINGS.SALES.SYSTEM_FIELDS.DESCRIPTION'),
    fieldType: 'textarea',
  },
  {
    key: 'system_amount',
    label: t('KANBAN.SETTINGS.SALES.SYSTEM_FIELDS.AMOUNT'),
    fieldType: 'currency',
  },
  {
    key: 'system_owner_id',
    label: t('KANBAN.SETTINGS.SALES.SYSTEM_FIELDS.OWNER'),
    fieldType: 'select',
    conditionOptions: agentOptions.value,
  },
  {
    key: 'system_assignee_id',
    label: t('KANBAN.SETTINGS.SALES.SYSTEM_FIELDS.ASSIGNEE'),
    fieldType: 'select',
    conditionOptions: agentOptions.value,
  },
  {
    key: 'system_stage_id',
    label: t('KANBAN.SETTINGS.SALES.SYSTEM_FIELDS.STAGE'),
    fieldType: 'select',
    conditionOptions: stages.value.map(stage => ({
      value: stage.id,
      label: stage.name,
    })),
  },
  {
    key: 'system_inbox_id',
    label: t('KANBAN.SETTINGS.SALES.SYSTEM_FIELDS.INBOX'),
    fieldType: 'select',
    conditionOptions: inboxOptions.value,
  },
  {
    key: 'system_status',
    label: t('KANBAN.SETTINGS.SALES.SYSTEM_FIELDS.STATUS'),
    fieldType: 'select',
    conditionOptions: [
      {
        value: 'open',
        label: t('KANBAN.SETTINGS.SALES.SYSTEM_STATUS.OPEN'),
      },
      {
        value: 'won',
        label: t('KANBAN.SETTINGS.SALES.SYSTEM_STATUS.WON'),
      },
      {
        value: 'lost',
        label: t('KANBAN.SETTINGS.SALES.SYSTEM_STATUS.LOST'),
      },
    ],
  },
  {
    key: 'system_starts_at',
    label: t('KANBAN.SETTINGS.SALES.SYSTEM_FIELDS.STARTS_AT'),
    fieldType: 'date',
  },
  {
    key: 'system_due_at',
    label: t('KANBAN.SETTINGS.SALES.SYSTEM_FIELDS.DUE_AT'),
    fieldType: 'date',
  },
  {
    key: 'system_next_action_type',
    label: t('KANBAN.SETTINGS.SALES.SYSTEM_FIELDS.NEXT_ACTION_TYPE'),
    fieldType: 'select',
    conditionOptions: linesFromText(form.nextActionTypesText).map(value => ({
      value,
      label: value,
    })),
  },
  {
    key: 'system_next_action_at',
    label: t('KANBAN.SETTINGS.SALES.SYSTEM_FIELDS.NEXT_ACTION_AT'),
    fieldType: 'date',
  },
  {
    key: 'system_next_action_note',
    label: t('KANBAN.SETTINGS.SALES.SYSTEM_FIELDS.NEXT_ACTION_NOTE'),
    fieldType: 'text',
  },
  {
    key: 'system_next_action_completed',
    label: t('KANBAN.SETTINGS.SALES.SYSTEM_FIELDS.NEXT_ACTION_COMPLETED'),
    fieldType: 'boolean',
  },
  {
    key: 'system_lost_reason',
    label: t('KANBAN.SETTINGS.SALES.SYSTEM_FIELDS.LOST_REASON'),
    fieldType: 'select',
    conditionOptions: linesFromText(form.lostReasonOptionsText).map(value => ({
      value,
      label: value,
    })),
  },
  {
    key: 'system_contact_id',
    label: t('KANBAN.SETTINGS.SALES.SYSTEM_FIELDS.CONTACT'),
    fieldType: 'integer',
  },
  {
    key: 'system_conversation_id',
    label: t('KANBAN.SETTINGS.SALES.SYSTEM_FIELDS.CONVERSATION'),
    fieldType: 'integer',
  },
]);

const customFieldTypeOptions = computed(() => [
  { value: 'text', label: t('KANBAN.SETTINGS.SALES.FIELD_TYPES.TEXT') },
  {
    value: 'textarea',
    label: t('KANBAN.SETTINGS.SALES.FIELD_TYPES.TEXTAREA'),
  },
  { value: 'select', label: t('KANBAN.SETTINGS.SALES.FIELD_TYPES.SELECT') },
  {
    value: 'multiselect',
    label: t('KANBAN.SETTINGS.SALES.FIELD_TYPES.MULTISELECT'),
  },
  { value: 'integer', label: t('KANBAN.SETTINGS.SALES.FIELD_TYPES.INTEGER') },
  { value: 'decimal', label: t('KANBAN.SETTINGS.SALES.FIELD_TYPES.DECIMAL') },
  {
    value: 'currency',
    label: t('KANBAN.SETTINGS.SALES.FIELD_TYPES.CURRENCY'),
  },
  { value: 'date', label: t('KANBAN.SETTINGS.SALES.FIELD_TYPES.DATE') },
  {
    value: 'datetime',
    label: t('KANBAN.SETTINGS.SALES.FIELD_TYPES.DATETIME'),
  },
  { value: 'boolean', label: t('KANBAN.SETTINGS.SALES.FIELD_TYPES.BOOLEAN') },
  { value: 'url', label: t('KANBAN.SETTINGS.SALES.FIELD_TYPES.URL') },
  { value: 'formula', label: t('KANBAN.SETTINGS.SALES.FIELD_TYPES.FORMULA') },
]);

const customFieldWidthOptions = computed(() => [
  { value: 'full', label: t('KANBAN.SETTINGS.SALES.FIELD_WIDTHS.FULL') },
  { value: 'half', label: t('KANBAN.SETTINGS.SALES.FIELD_WIDTHS.HALF') },
  { value: 'third', label: t('KANBAN.SETTINGS.SALES.FIELD_WIDTHS.THIRD') },
]);

const leadOriginOptions = [
  'Mídia Paga',
  'WhatsApp Directo',
  'Indicação',
  'Google',
  'Site',
  'Facebook',
  'Referência Médica',
  'Outro',
  'Orgânico',
  'Parceria',
];
const leadSubOriginOptions = [
  '[MP] Google',
  '[MP] Meta',
  '[MP] YouTube',
  '[MP] TikTok',
  '[ORG] Google',
  '[ORG] Instagram',
  '[ORG] Facebook',
  '[ORG] Site Direto',
  '[ORG] WhatsApp',
  '[IND] Paciente',
  '[IND] Parceiro',
  '[OUT] Desconhecido',
];
const marketingFieldLabels = computed(() => ({
  LEAD_ORIGIN: t('KANBAN.SETTINGS.SALES.MARKETING_FIELDS.LEAD_ORIGIN'),
  LEAD_SUB_ORIGIN: t('KANBAN.SETTINGS.SALES.MARKETING_FIELDS.LEAD_SUB_ORIGIN'),
  UTM_SOURCE: t('KANBAN.SETTINGS.SALES.MARKETING_FIELDS.UTM_SOURCE'),
  UTM_MEDIUM: t('KANBAN.SETTINGS.SALES.MARKETING_FIELDS.UTM_MEDIUM'),
  UTM_CAMPAIGN: t('KANBAN.SETTINGS.SALES.MARKETING_FIELDS.UTM_CAMPAIGN'),
  UTM_TERM: t('KANBAN.SETTINGS.SALES.MARKETING_FIELDS.UTM_TERM'),
  UTM_CONTENT: t('KANBAN.SETTINGS.SALES.MARKETING_FIELDS.UTM_CONTENT'),
  UTM_ID: t('KANBAN.SETTINGS.SALES.MARKETING_FIELDS.UTM_ID'),
  UTM_REFERRER: t('KANBAN.SETTINGS.SALES.MARKETING_FIELDS.UTM_REFERRER'),
  REFERRER: t('KANBAN.SETTINGS.SALES.MARKETING_FIELDS.REFERRER'),
  GOOGLE_CLIENT_ID: t(
    'KANBAN.SETTINGS.SALES.MARKETING_FIELDS.GOOGLE_CLIENT_ID'
  ),
  GCLID: t('KANBAN.SETTINGS.SALES.MARKETING_FIELDS.GCLID'),
  GBRAID: t('KANBAN.SETTINGS.SALES.MARKETING_FIELDS.GBRAID'),
  WBRAID: t('KANBAN.SETTINGS.SALES.MARKETING_FIELDS.WBRAID'),
  DCLID: t('KANBAN.SETTINGS.SALES.MARKETING_FIELDS.DCLID'),
  FBCLID: t('KANBAN.SETTINGS.SALES.MARKETING_FIELDS.FBCLID'),
  FBC: t('KANBAN.SETTINGS.SALES.MARKETING_FIELDS.FBC'),
  FBP: t('KANBAN.SETTINGS.SALES.MARKETING_FIELDS.FBP'),
  TTCLID: t('KANBAN.SETTINGS.SALES.MARKETING_FIELDS.TTCLID'),
  TIKTOK_AD_ID: t('KANBAN.SETTINGS.SALES.MARKETING_FIELDS.TIKTOK_AD_ID'),
  TIKTOK_AD_NAME: t('KANBAN.SETTINGS.SALES.MARKETING_FIELDS.TIKTOK_AD_NAME'),
  MSCLKID: t('KANBAN.SETTINGS.SALES.MARKETING_FIELDS.MSCLKID'),
  CAMPAIGN_NAME: t('KANBAN.SETTINGS.SALES.MARKETING_FIELDS.CAMPAIGN_NAME'),
  ADSET_NAME: t('KANBAN.SETTINGS.SALES.MARKETING_FIELDS.ADSET_NAME'),
  AD_NAME: t('KANBAN.SETTINGS.SALES.MARKETING_FIELDS.AD_NAME'),
  CAMPAIGN_ID: t('KANBAN.SETTINGS.SALES.MARKETING_FIELDS.CAMPAIGN_ID'),
  ADSET_ID: t('KANBAN.SETTINGS.SALES.MARKETING_FIELDS.ADSET_ID'),
  AD_ID: t('KANBAN.SETTINGS.SALES.MARKETING_FIELDS.AD_ID'),
  LANDING_PAGE: t('KANBAN.SETTINGS.SALES.MARKETING_FIELDS.LANDING_PAGE'),
  LANDING_PAGE_FULL: t(
    'KANBAN.SETTINGS.SALES.MARKETING_FIELDS.LANDING_PAGE_FULL'
  ),
  EVENT_ID: t('KANBAN.SETTINGS.SALES.MARKETING_FIELDS.EVENT_ID'),
}));
const marketingFieldDefinitions = computed(() => {
  const field = (key, labelKey, options = {}) => ({
    key,
    label: marketingFieldLabels.value[labelKey],
    fieldType: 'text',
    layoutWidth: 'half',
    ...options,
  });

  return [
    field('origem_do_lead', 'LEAD_ORIGIN', {
      fieldType: 'select',
      options: leadOriginOptions,
    }),
    field('sub_origem', 'LEAD_SUB_ORIGIN', {
      fieldType: 'select',
      options: leadSubOriginOptions,
    }),
    field('campaign', 'CAMPAIGN_NAME'),
    field('adset', 'ADSET_NAME'),
    field('ad', 'AD_NAME'),
    field('utm_content', 'UTM_CONTENT'),
    field('utm_medium', 'UTM_MEDIUM'),
    field('utm_campaign', 'UTM_CAMPAIGN'),
    field('utm_source', 'UTM_SOURCE'),
    field('utm_term', 'UTM_TERM'),
    field('utm_referrer', 'UTM_REFERRER'),
    field('referrer', 'REFERRER'),
    field('gclientid', 'GOOGLE_CLIENT_ID'),
    field('gclid', 'GCLID'),
    field('fvclid', 'FBCLID'),
    field('ttad_name', 'TIKTOK_AD_NAME'),
    field('ttad_id', 'TIKTOK_AD_ID'),
    field('fbc', 'FBC'),
    field('fbp', 'FBP'),
    field('ttclid', 'TTCLID'),
    field('campaign_id', 'CAMPAIGN_ID'),
    field('adset_id', 'ADSET_ID'),
    field('ad_id', 'AD_ID'),
    field('landing_page', 'LANDING_PAGE', { fieldType: 'url' }),
    field('event_id', 'EVENT_ID'),
    field('landing_page_full', 'LANDING_PAGE_FULL', {
      fieldType: 'textarea',
      layoutWidth: 'full',
    }),
  ];
});

const getErrorMessage = (error, fallbackMessage) =>
  error?.response?.data?.error ||
  error?.response?.data?.message ||
  error?.message ||
  fallbackMessage;

const normalizeFormulaSearch = value =>
  String(value || '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase();

const numericFormulaCandidates = definition => {
  const definitionIndex = form.customFieldDefinitions.indexOf(definition);
  return [
    {
      key: 'system_amount',
      label: t('KANBAN.SETTINGS.SALES.SYSTEM_FIELDS.AMOUNT'),
      searchAliases: 'valor value amount',
    },
    ...form.customFieldDefinitions
      .filter(
        (field, fieldIndex) =>
          field !== definition &&
          field.key &&
          ['integer', 'decimal', 'currency', 'formula'].includes(
            field.fieldType
          ) &&
          (field.fieldType !== 'formula' || fieldIndex < definitionIndex)
      )
      .map(field => ({ key: field.key, label: field.label || field.key })),
  ];
};

function formulaDisplayValue(definition) {
  let formula = String(definition.formula || '');
  numericFormulaCandidates(definition)
    .sort((first, second) => second.key.length - first.key.length)
    .forEach(candidate => {
      formula = formula.replace(
        new RegExp(`\\b${candidate.key}\\b`, 'g'),
        `[${candidate.label}]`
      );
    });
  return formula;
}

function stableFormulaValue(definition) {
  const candidates = numericFormulaCandidates(definition);
  return String(definition.formulaDisplay || '').replace(
    /\[([^\]]+)\]/gu,
    (match, token) => {
      const normalizedToken = normalizeFormulaSearch(token);
      const candidate = candidates.find(
        item =>
          normalizeFormulaSearch(item.label) === normalizedToken ||
          normalizeFormulaSearch(item.key) === normalizedToken
      );
      return candidate?.key || match;
    }
  );
}

const applySettings = payload => {
  const settings = camelcaseKeys(payload || {}, { deep: true });

  form.name = settings.name || '';
  form.description = settings.description || '';
  form.autoCreateCardsFromConversations =
    settings.autoCreateCardsFromConversations || false;
  form.visibilityMode = settings.visibilityMode || 'all_agents';
  form.visibleUserIds = settings.visibleUserIds || [];
  form.inboxScopeMode = settings.inboxScopeMode || 'all_inboxes';
  form.allowedInboxIds = settings.allowedInboxIds || [];
  form.nextActionTypesText = (settings.nextActionTypes || []).join('\n');
  form.lostReasonOptionsText = (settings.lostReasonOptions || []).join('\n');
  form.customFieldDefinitionsText = JSON.stringify(
    settings.customFieldDefinitions || [],
    null,
    2
  );
  form.customFieldDefinitions = (settings.customFieldDefinitions || []).map(
    definition => ({
      clientId: nextCustomFieldRowId(),
      key: definition.key || '',
      label: definition.label || '',
      fieldType: definition.fieldType || 'text',
      optionsText: (definition.options || []).join('\n'),
      requiredStageIds: definition.requiredStageIds || [],
      conditionFieldKey:
        definition.condition?.fieldKey || definition.condition?.field_key || '',
      conditionEquals: definition.condition?.equals ?? '',
      formula: definition.formula || '',
      formulaDisplay: definition.formula || '',
      layoutSection: definition.layout?.section || 'details',
      layoutPosition: definition.layout?.position || 1,
      layoutWidth: definition.layout?.width || 'full',
      important: Boolean(definition.important),
      autoKey: false,
    })
  );
  form.customFieldDefinitions.forEach(definition => {
    definition.formulaDisplay = formulaDisplayValue(definition);
  });
  form.customFieldSections = settings.customFieldSections || [];
  form.compactCardFieldKeys = settings.compactCardFieldKeys || [];
  form.staleStageThresholds = settings.staleStageThresholds || {};
};

const applyBoard = payload => {
  const board = camelcaseKeys(payload || {}, { deep: true });
  stages.value = board.stages || [];
};

const fetchSettings = async () => {
  isLoading.value = true;
  loadError.value = '';

  try {
    const [response, boardResponse] = await Promise.all([
      KanbanBoardsAPI.getSettings(boardId.value),
      KanbanBoardsAPI.showBoard(boardId.value),
      store.dispatch('agents/get'),
      store.dispatch('inboxes/get'),
    ]);
    applySettings(response.data);
    applyBoard(boardResponse.data);
  } catch (error) {
    loadError.value = getErrorMessage(error, t('KANBAN.SETTINGS.LOAD_ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const refreshBoard = async () => {
  const response = await KanbanBoardsAPI.showBoard(boardId.value);
  applyBoard(response.data);
};

const customFieldDefinitionsFromText = value => {
  const trimmedValue = String(value || '').trim();
  if (!trimmedValue) return [];

  const parsedValue = JSON.parse(trimmedValue);
  return Array.isArray(parsedValue) ? parsedValue : [];
};

const customFieldKeyFromLabel = label =>
  String(label || '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '');

const customFieldPayload = definition => ({
  key: definition.key,
  label: definition.label,
  field_type: definition.fieldType,
  options: linesFromText(definition.optionsText),
  required_stage_ids: (definition.requiredStageIds || []).map(Number),
  condition: definition.conditionFieldKey
    ? {
        field_key: definition.conditionFieldKey,
        equals: definition.conditionEquals,
      }
    : {},
  formula:
    definition.fieldType === 'formula' ? stableFormulaValue(definition) : null,
  important: Boolean(definition.important),
  layout: {
    section: definition.layoutSection || 'details',
    position: Number(definition.layoutPosition) || 1,
    width: definition.layoutWidth || 'full',
  },
});

const createCustomFieldRow = ({
  key = '',
  label = '',
  fieldType = 'text',
  options = [],
  layoutSection = 'details',
  layoutPosition = form.customFieldDefinitions.length + 1,
  layoutWidth = 'full',
  autoKey = true,
  important = false,
} = {}) => ({
  clientId: nextCustomFieldRowId(),
  key,
  label,
  fieldType,
  optionsText: options.join('\n'),
  requiredStageIds: [],
  conditionFieldKey: '',
  conditionEquals: '',
  formula: '',
  formulaDisplay: '',
  layoutSection,
  layoutPosition,
  layoutWidth,
  important,
  autoKey,
});

const syncCustomFieldDefinitionsText = () => {
  form.customFieldDefinitionsText = JSON.stringify(
    form.customFieldDefinitions.map(customFieldPayload),
    null,
    2
  );
};

const addCustomField = () => {
  const definition = createCustomFieldRow();
  form.customFieldDefinitions.push(definition);
  selectedCustomFieldId.value = definition.clientId;
  showCustomFieldManager.value = true;
  syncCustomFieldDefinitionsText();
};

const openCustomFieldManager = clientId => {
  selectedCustomFieldId.value =
    clientId || form.customFieldDefinitions[0]?.clientId || null;
  showCustomFieldManager.value = true;
};

const closeCustomFieldManager = () => {
  showCustomFieldManager.value = false;
  newCustomFieldOption.value = '';
};

const customFieldOptionValues = definition =>
  linesFromText(definition.optionsText);

const addCustomFieldOption = definition => {
  const option = newCustomFieldOption.value.trim();
  if (!option) return;

  definition.optionsText = [
    ...new Set([...customFieldOptionValues(definition), option]),
  ].join('\n');
  newCustomFieldOption.value = '';
  syncCustomFieldDefinitionsText();
};

const removeCustomFieldOption = (definition, option) => {
  definition.optionsText = customFieldOptionValues(definition)
    .filter(value => value !== option)
    .join('\n');
  syncCustomFieldDefinitionsText();
};

const customFieldSectionLabel = sectionKey => {
  if (sectionKey === 'details') {
    return t('KANBAN.SETTINGS.SALES.TABS.GENERAL');
  }
  if (sectionKey === 'marketing') {
    return t('KANBAN.SETTINGS.SALES.TABS.MARKETING');
  }

  return sectionKey
    .replace(/[_-]+/g, ' ')
    .replace(/^./, character => character.toUpperCase());
};
const customFieldLayoutSections = computed(() => {
  const configuredSections = [
    {
      key: 'details',
      label: t('KANBAN.SETTINGS.SALES.TABS.GENERAL'),
      builtIn: true,
    },
    {
      key: 'marketing',
      label: t('KANBAN.SETTINGS.SALES.TABS.MARKETING'),
      builtIn: true,
    },
    ...form.customFieldSections,
  ];
  const knownKeys = new Set(configuredSections.map(section => section.key));

  form.customFieldDefinitions.forEach(definition => {
    const key = definition.layoutSection || 'details';
    if (knownKeys.has(key)) return;

    knownKeys.add(key);
    configuredSections.push({ key, label: customFieldSectionLabel(key) });
  });

  return configuredSections;
});

const openNewFieldSectionForm = () => {
  showNewFieldSectionForm.value = true;
};

const createCustomFieldSection = () => {
  const label = newFieldSectionName.value.trim();
  if (!label) return;

  const usedKeys = new Set(
    customFieldLayoutSections.value.map(section => section.key)
  );
  const baseKey = customFieldKeyFromLabel(label) || 'nova_aba';
  let key = baseKey;
  let suffix = 2;
  while (usedKeys.has(key)) {
    key = `${baseKey}_${suffix}`;
    suffix += 1;
  }

  form.customFieldSections.push({ key, label });
  newFieldSectionName.value = '';
  showNewFieldSectionForm.value = false;
};
const customFieldsForLayoutSection = sectionKey =>
  form.customFieldDefinitions
    .filter(
      definition => (definition.layoutSection || 'details') === sectionKey
    )
    .sort(
      (firstDefinition, secondDefinition) =>
        Number(firstDefinition.layoutPosition) -
        Number(secondDefinition.layoutPosition)
    );
const renumberCustomFieldSection = sectionKey => {
  customFieldsForLayoutSection(sectionKey).forEach((definition, index) => {
    definition.layoutPosition = index + 1;
  });
};
const moveCustomFieldInLayout = (sectionKey, event) => {
  const change = event.added || event.moved;
  if (!change) return;

  const definition = change.element;
  const previousSectionKey = definition.layoutSection || 'details';
  definition.layoutSection = sectionKey;

  const sectionFields = customFieldsForLayoutSection(sectionKey).filter(
    field => field !== definition
  );
  sectionFields.splice(change.newIndex, 0, definition);
  sectionFields.forEach((field, index) => {
    field.layoutPosition = index + 1;
  });

  if (previousSectionKey !== sectionKey) {
    renumberCustomFieldSection(previousSectionKey);
  }
  syncCustomFieldDefinitionsText();
};
const addMarketingFields = () => {
  const presetKeys = new Set(
    marketingFieldDefinitions.value.map(definition => definition.key)
  );
  const obsoletePresetKeys = new Set([
    'utm_id',
    'gbraid',
    'wbraid',
    'dclid',
    'fbclid',
    'msclkid',
    'campaign_name',
    'adset_name',
    'ad_name',
  ]);
  form.customFieldDefinitions = form.customFieldDefinitions.filter(
    definition =>
      !(
        definition.layoutSection === 'marketing' &&
        (presetKeys.has(definition.key) ||
          obsoletePresetKeys.has(definition.key))
      )
  );
  let position = customFieldsForLayoutSection('marketing').length + 1;

  marketingFieldDefinitions.value.forEach(definition => {
    form.customFieldDefinitions.push(
      createCustomFieldRow({
        ...definition,
        layoutSection: 'marketing',
        layoutPosition: position,
        autoKey: false,
      })
    );
    position += 1;
  });
  syncCustomFieldDefinitionsText();
};

const updateCustomFieldLabel = definition => {
  if (definition.autoKey) {
    const previousKey = definition.key;
    const nextKey = customFieldKeyFromLabel(definition.label);
    definition.key = nextKey;
    form.compactCardFieldKeys = form.compactCardFieldKeys.map(key =>
      key === previousKey ? nextKey : key
    );
  }
  syncCustomFieldDefinitionsText();
};

const customFieldConditionCandidates = definition => [
  ...systemConditionFields.value,
  ...form.customFieldDefinitions.filter(
    field => field !== definition && field.key
  ),
];

const conditionSourceField = definition =>
  customFieldConditionCandidates(definition).find(
    field => field.key === definition.conditionFieldKey
  );

const conditionValueOptions = definition => {
  const sourceField = conditionSourceField(definition);
  if (!sourceField) return [];

  if (sourceField.conditionOptions) {
    return sourceField.conditionOptions.map(option => ({
      ...option,
      value: String(option.value),
    }));
  }

  if (['select', 'multiselect'].includes(sourceField.fieldType)) {
    return linesFromText(sourceField.optionsText).map(value => ({
      value,
      label: value,
    }));
  }

  if (sourceField.fieldType === 'boolean') {
    return [
      {
        value: 'true',
        label: t('KANBAN.SETTINGS.SALES.CONDITION_BOOLEAN_TRUE'),
      },
      {
        value: 'false',
        label: t('KANBAN.SETTINGS.SALES.CONDITION_BOOLEAN_FALSE'),
      },
    ];
  }

  return [];
};

const conditionValueInputType = definition => {
  const fieldType = conditionSourceField(definition)?.fieldType;

  if (['integer', 'decimal', 'currency', 'formula'].includes(fieldType)) {
    return 'number';
  }
  if (fieldType === 'date') return 'date';
  if (fieldType === 'datetime') return 'datetime-local';
  if (fieldType === 'url') return 'url';

  return 'text';
};

const updateConditionField = definition => {
  definition.conditionEquals = '';
  syncCustomFieldDefinitionsText();
};

const currentFormulaToken = definition =>
  String(definition.formulaDisplay || '').match(/\[([^\]]*)$/u)?.[1] ?? null;

const formulaSuggestions = definition => {
  if (activeFormulaFieldId.value !== definition.clientId) return [];

  const token = currentFormulaToken(definition);
  if (token === null) return [];
  const query = normalizeFormulaSearch(token);

  return numericFormulaCandidates(definition).filter(candidate =>
    normalizeFormulaSearch(
      `${candidate.label} ${candidate.key} ${candidate.searchAliases || ''}`
    ).includes(query)
  );
};

const insertFormulaCandidate = (definition, candidate) => {
  const formula = String(definition.formulaDisplay || '');
  const markerStart = formula.lastIndexOf('[');
  definition.formulaDisplay = `${formula.slice(0, markerStart)}[${candidate.label}] `;
  definition.formula = stableFormulaValue(definition);
  activeFormulaFieldId.value = null;
  activeFormulaSuggestionIndex.value = 0;
  syncCustomFieldDefinitionsText();
};

const onFormulaInput = definition => {
  definition.formula = stableFormulaValue(definition);
  activeFormulaFieldId.value = definition.clientId;
  activeFormulaSuggestionIndex.value = 0;
  syncCustomFieldDefinitionsText();
};

const onFormulaKeydown = (definition, event) => {
  const suggestions = formulaSuggestions(definition);
  if (!suggestions.length) return;

  if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
    event.preventDefault();
    const direction = event.key === 'ArrowDown' ? 1 : -1;
    activeFormulaSuggestionIndex.value =
      (activeFormulaSuggestionIndex.value + direction + suggestions.length) %
      suggestions.length;
  }
  if (event.key === 'Enter') {
    event.preventDefault();
    insertFormulaCandidate(
      definition,
      suggestions[activeFormulaSuggestionIndex.value]
    );
  }
  if (event.key === 'Escape') activeFormulaFieldId.value = null;
};

const removeCustomField = index => {
  const [removedField] = form.customFieldDefinitions.splice(index, 1);
  form.compactCardFieldKeys = form.compactCardFieldKeys.filter(
    key => key !== removedField.key
  );
  syncCustomFieldDefinitionsText();
};

const removeCustomFieldById = clientId => {
  const index = form.customFieldDefinitions.findIndex(
    definition => definition.clientId === clientId
  );
  if (index < 0) return;

  removeCustomField(index);
  selectedCustomFieldId.value =
    form.customFieldDefinitions[index]?.clientId ||
    form.customFieldDefinitions[index - 1]?.clientId ||
    null;
};

const toggleCompactCardField = (fieldKey, checked) => {
  form.compactCardFieldKeys = checked
    ? [...new Set([...form.compactCardFieldKeys, fieldKey])]
    : form.compactCardFieldKeys.filter(key => key !== fieldKey);
};

const normalizedStaleStageThresholds = () =>
  Object.fromEntries(
    Object.entries(form.staleStageThresholds)
      .map(([stageId, days]) => [stageId, Number(days)])
      .filter(([, days]) => days > 0)
  );

const buildPayload = () => ({
  kanban_board: {
    name: form.name.trim(),
    description: form.description.trim(),
    auto_create_cards_from_conversations: form.autoCreateCardsFromConversations,
    visibility_mode: form.visibilityMode,
    visible_user_ids:
      form.visibilityMode === 'selected_agents' ? form.visibleUserIds : [],
    inbox_scope_mode: form.inboxScopeMode,
    allowed_inbox_ids:
      form.inboxScopeMode === 'selected_inboxes' ? form.allowedInboxIds : [],
    next_action_types: linesFromText(form.nextActionTypesText),
    lost_reason_options: linesFromText(form.lostReasonOptionsText),
    custom_field_definitions: customFieldDefinitionsFromText(
      form.customFieldDefinitionsText
    ),
    custom_field_sections: form.customFieldSections,
    compact_card_field_keys: form.compactCardFieldKeys,
    stale_stage_thresholds: normalizedStaleStageThresholds(),
  },
});

const saveSettings = async () => {
  if (!form.name.trim() || isSaving.value || !isAdmin.value) return;

  isSaving.value = true;
  saveError.value = '';

  try {
    const response = await KanbanBoardsAPI.updateSettings(
      boardId.value,
      buildPayload()
    );
    applySettings(response.data);
    await store.dispatch('kanbanBoards/refreshBoards');
    useAlert(t('KANBAN.SETTINGS.SAVE_SUCCESS'));
    await router.replace({
      name: 'kanban_board_show',
      params: { accountId: route.params.accountId, boardId: boardId.value },
    });
  } catch (error) {
    saveError.value = getErrorMessage(error, t('KANBAN.SETTINGS.SAVE_ERROR'));
    useAlert(saveError.value);
  } finally {
    isSaving.value = false;
  }
};

const saveAutomationSetting = async event => {
  const enabled = event.target.checked;
  if (isSavingAutomation.value || !isAdmin.value) return;

  isSavingAutomation.value = true;
  saveError.value = '';

  try {
    const response = await KanbanBoardsAPI.updateSettings(
      boardId.value,
      buildPayload()
    );
    applySettings(response.data);
    await store.dispatch('kanbanBoards/refreshBoards');

    if (enabled) {
      importError.value = '';
      ignoreGroupsForImport.value = false;
      showImportExistingConversationsModal.value = true;
    }
  } catch (error) {
    form.autoCreateCardsFromConversations = !enabled;
    saveError.value = getErrorMessage(error, t('KANBAN.SETTINGS.SAVE_ERROR'));
    useAlert(saveError.value);
  } finally {
    isSavingAutomation.value = false;
  }
};

const closeImportExistingConversationsModal = () => {
  if (isImportingConversations.value) return;

  showImportExistingConversationsModal.value = false;
  importError.value = '';
};

const importExistingConversations = async () => {
  if (isImportingConversations.value) return;

  isImportingConversations.value = true;
  importError.value = '';

  try {
    await KanbanBoardsAPI.importExistingConversations(boardId.value, {
      ignore_groups: ignoreGroupsForImport.value,
    });
    showImportExistingConversationsModal.value = false;
    useAlert(t('KANBAN.SETTINGS.AUTOMATIONS.IMPORT_SUCCESS'));
  } catch (error) {
    importError.value = getErrorMessage(
      error,
      t('KANBAN.SETTINGS.AUTOMATIONS.IMPORT_ERROR')
    );
    useAlert(importError.value);
  } finally {
    isImportingConversations.value = false;
  }
};

const getStageColorClass = stage =>
  getKanbanStageColorOption(stage.color).swatchClass;

const getStageCardsCount = stage =>
  stage.cardsCount ?? stage.cards?.length ?? 0;

const openCreateStageForm = () => {
  showCreateStageForm.value = true;
};

const closeCreateStageForm = () => {
  showCreateStageForm.value = false;
  newStageName.value = '';
  newStageColor.value = DEFAULT_KANBAN_STAGE_COLOR;
};

const createStage = async () => {
  const name = newStageName.value.trim();
  if (!name || isCreatingStage.value || !isAdmin.value) return;

  isCreatingStage.value = true;
  stageError.value = '';

  try {
    await KanbanBoardsAPI.createStage(boardId.value, {
      stage: {
        name,
        color: newStageColor.value,
        position: stages.value.length + 1,
      },
    });
    closeCreateStageForm();
    await refreshBoard();
    await store.dispatch('kanbanBoards/refreshBoards');
    useAlert(t('KANBAN.ACTIONS.CREATE_STAGE_SUCCESS'));
  } catch (error) {
    stageError.value = getErrorMessage(
      error,
      t('KANBAN.ACTIONS.CREATE_STAGE_ERROR')
    );
    useAlert(stageError.value);
  } finally {
    isCreatingStage.value = false;
  }
};

const saveStageRules = async stage => {
  if (!stage?.id || activeStageActionKey.value || !isAdmin.value) return;

  activeStageActionKey.value = `update-stage-${stage.id}`;
  stageError.value = '';

  try {
    await KanbanBoardsAPI.updateStage(boardId.value, stage.id, {
      stage: {
        category: stage.category || 'open',
        wip_limit: Number(stage.wipLimit) || null,
      },
    });
    await refreshBoard();
    useAlert(t('KANBAN.SETTINGS.STAGES.SAVE_SUCCESS'));
  } catch (error) {
    stageError.value = getErrorMessage(
      error,
      t('KANBAN.SETTINGS.STAGES.SAVE_ERROR')
    );
    useAlert(stageError.value);
  } finally {
    activeStageActionKey.value = '';
  }
};

const reorderStageByPosition = async (stage, position) => {
  if (!stage?.id || activeStageActionKey.value || !isAdmin.value) return;

  activeStageActionKey.value = `reorder-stage-${stage.id}`;
  stageError.value = '';

  try {
    await KanbanBoardsAPI.reorderStage(boardId.value, stage.id, { position });
    await refreshBoard();
    await store.dispatch('kanbanBoards/refreshBoards');
  } catch (error) {
    stageError.value = getErrorMessage(
      error,
      t('KANBAN.ACTIONS.REORDER_STAGE_ERROR')
    );
    useAlert(stageError.value);
    await refreshBoard();
  } finally {
    activeStageActionKey.value = '';
  }
};

const onStageDragEnd = async event => {
  const stageId = Number(event?.item?.dataset?.stageId);
  const newIndex = event?.newIndex;
  const oldIndex = event?.oldIndex;
  if (!stageId || oldIndex === newIndex || newIndex === undefined) return;

  const stage = stages.value.find(item => item.id === stageId);
  if (!stage) return;

  await reorderStageByPosition(stage, newIndex + 1);
};

const openDeleteConfirmation = () => {
  showDeleteConfirmation.value = true;
};

const closeDeleteConfirmation = () => {
  showDeleteConfirmation.value = false;
};

const deleteBoard = async () => {
  if (isDeleting.value || !isAdmin.value) return;

  isDeleting.value = true;
  saveError.value = '';

  try {
    await KanbanBoardsAPI.delete(boardId.value);
    await store.dispatch('kanbanBoards/refreshBoards');
    closeDeleteConfirmation();
    await router.replace({
      name: 'kanban_boards',
      params: { accountId: route.params.accountId },
    });
    useAlert(t('KANBAN.ACTIONS.REMOVE_BOARD_SUCCESS'));
  } catch (error) {
    saveError.value = getErrorMessage(
      error,
      t('KANBAN.ACTIONS.REMOVE_BOARD_ERROR')
    );
    useAlert(saveError.value);
  } finally {
    isDeleting.value = false;
  }
};

onMounted(async () => {
  await fetchSettings();
  if (route.query?.section === 'fields') {
    openCustomFieldManager();
    if (route.query?.action === 'new-tab') openNewFieldSectionForm();
  }
});
</script>

<template>
  <main class="flex h-full min-h-0 w-full bg-n-surface-1 text-n-slate-12">
    <div class="flex w-full flex-col gap-6 overflow-y-auto p-8">
      <header class="flex items-center justify-between gap-4">
        <div class="min-w-0">
          <h1 class="text-2xl font-medium text-n-slate-12">
            {{ t('KANBAN.SETTINGS.TITLE') }}
          </h1>
          <p class="mt-1 text-sm text-n-slate-11">
            {{ t('KANBAN.SETTINGS.DESCRIPTION') }}
          </p>
        </div>
        <Button
          icon="i-lucide-arrow-left"
          :label="t('KANBAN.SETTINGS.BACK_TO_BOARD')"
          color="slate"
          size="sm"
          @click="
            router.push({
              name: 'kanban_board_show',
              params: { accountId: route.params.accountId, boardId },
            })
          "
        />
      </header>

      <div
        v-if="isLoading"
        data-testid="kanban-settings-loading"
        class="flex items-center justify-center py-16 text-sm text-n-slate-11"
      >
        {{ t('KANBAN.SETTINGS.LOADING') }}
      </div>

      <div
        v-else-if="loadError || !isAdmin"
        data-testid="kanban-settings-error"
        class="rounded-lg border border-n-weak bg-n-surface-2 p-6 text-sm text-n-ruby-11"
      >
        {{ loadError || t('KANBAN.SETTINGS.ACCESS_DENIED') }}
      </div>

      <form
        v-else
        data-testid="kanban-settings-form"
        class="grid gap-6"
        @submit.prevent="saveSettings"
      >
        <section class="grid gap-4 border-b border-n-weak pb-6">
          <h2 class="text-base font-medium text-n-slate-12">
            {{ t('KANBAN.SETTINGS.GENERAL.TITLE') }}
          </h2>
          <label class="grid gap-1 text-sm font-medium text-n-slate-12">
            {{ t('KANBAN.SETTINGS.GENERAL.NAME') }}
            <input
              v-model="form.name"
              data-testid="kanban-settings-name"
              type="text"
              class="rounded-md border border-n-weak bg-n-surface-1 px-3 py-2 text-sm font-normal text-n-slate-12 outline-none placeholder:text-n-slate-10 focus:border-n-brand"
            />
          </label>
          <label class="grid gap-1 text-sm font-medium text-n-slate-12">
            {{ t('KANBAN.SETTINGS.GENERAL.DESCRIPTION') }}
            <textarea
              v-model="form.description"
              data-testid="kanban-settings-description"
              rows="3"
              class="rounded-md border border-n-weak bg-n-surface-1 px-3 py-2 text-sm font-normal text-n-slate-12 outline-none placeholder:text-n-slate-10 focus:border-n-brand"
            />
          </label>

          <div class="grid gap-3">
            <div class="flex items-center justify-end">
              <Button
                v-if="!showCreateStageForm"
                data-testid="kanban-settings-create-stage-toggle"
                icon="i-lucide-plus"
                :label="t('KANBAN.ACTIONS.CREATE_STAGE')"
                color="slate"
                size="sm"
                @click="openCreateStageForm"
              />
            </div>

            <div
              v-if="showCreateStageForm"
              data-testid="kanban-settings-create-stage-panel"
              class="grid gap-3 rounded-md border border-n-weak bg-n-surface-2 p-3"
            >
              <div class="flex flex-wrap items-center gap-2">
                <button
                  v-for="colorOption in KANBAN_STAGE_COLOR_OPTIONS"
                  :key="colorOption.value"
                  type="button"
                  class="size-5 rounded-full border border-n-strong ring-offset-2"
                  :class="[
                    colorOption.swatchClass,
                    newStageColor === colorOption.value
                      ? 'ring-2 ring-n-brand'
                      : 'hover:ring-2 hover:ring-n-weak',
                  ]"
                  :aria-label="
                    t('KANBAN.ACTIONS.SELECT_STAGE_COLOR', {
                      color: colorOption.value,
                    })
                  "
                  @click="newStageColor = colorOption.value"
                />
              </div>
              <div class="flex flex-wrap items-center gap-2">
                <input
                  v-model="newStageName"
                  data-testid="kanban-settings-new-stage-name"
                  type="text"
                  class="min-w-64 flex-1 rounded-md border border-n-weak bg-n-surface-1 px-3 py-2 text-sm font-normal text-n-slate-12 outline-none placeholder:text-n-slate-10 focus:border-n-brand"
                  :placeholder="t('KANBAN.ACTIONS.STAGE_NAME_PLACEHOLDER')"
                />
                <Button
                  type="button"
                  data-testid="kanban-settings-create-stage"
                  icon="i-lucide-check"
                  :label="t('KANBAN.ACTIONS.CREATE_STAGE_CONFIRM')"
                  color="blue"
                  size="sm"
                  :disabled="!newStageName.trim()"
                  :is-loading="isCreatingStage"
                  @click="createStage"
                />
                <Button
                  type="button"
                  icon="i-lucide-x"
                  :label="t('KANBAN.ACTIONS.CANCEL')"
                  color="slate"
                  size="sm"
                  @click="closeCreateStageForm"
                />
              </div>
            </div>

            <p
              v-if="stageError"
              data-testid="kanban-settings-stage-error"
              class="text-sm text-n-ruby-11"
            >
              {{ stageError }}
            </p>

            <p
              v-if="stages.length === 0"
              data-testid="kanban-settings-empty-stages"
              class="rounded-md border border-dashed border-n-weak px-3 py-4 text-sm text-n-slate-11"
            >
              {{ t('KANBAN.EMPTY_STAGES') }}
            </p>

            <Draggable
              v-else
              v-model="stageListModel"
              item-key="id"
              data-testid="kanban-settings-stage-list"
              class="grid gap-2"
              handle=".stage-drag-handle"
              ghost-class="opacity-60"
              chosen-class="opacity-90"
              :animation="180"
              @end="onStageDragEnd"
            >
              <template #item="{ element: stage }">
                <div
                  :data-stage-id="stage.id"
                  data-testid="kanban-settings-stage-row"
                  class="grid gap-3 rounded-md border border-n-weak bg-n-surface-2 px-3 py-3 lg:grid-cols-[minmax(10rem,1fr)_minmax(9rem,0.55fr)_minmax(9rem,0.45fr)_auto] lg:items-end"
                >
                  <div
                    class="stage-drag-handle flex min-w-0 cursor-grab items-center gap-3 self-center"
                  >
                    <span
                      class="i-lucide-grip-vertical size-4 text-n-slate-10"
                    />
                    <span
                      class="size-4 flex-none rounded-full"
                      :class="getStageColorClass(stage)"
                    />
                    <span class="min-w-0 truncate text-sm text-n-slate-12">
                      {{ stage.name }}
                    </span>
                    <span
                      data-testid="kanban-settings-stage-card-count"
                      class="flex-none rounded-full bg-n-alpha-2 px-2 py-0.5 text-xs font-medium text-n-slate-11"
                    >
                      {{ getStageCardsCount(stage) }}
                    </span>
                  </div>
                  <label class="grid gap-1 text-xs text-n-slate-11">
                    {{ t('KANBAN.SETTINGS.STAGES.CATEGORY') }}
                    <select
                      v-model="stage.category"
                      data-testid="kanban-settings-stage-category"
                      class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-2 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                    >
                      <option value="open">
                        {{ t('KANBAN.SETTINGS.STAGES.CATEGORY_OPEN') }}
                      </option>
                      <option value="won">
                        {{ t('KANBAN.SETTINGS.STAGES.CATEGORY_WON') }}
                      </option>
                      <option value="lost">
                        {{ t('KANBAN.SETTINGS.STAGES.CATEGORY_LOST') }}
                      </option>
                    </select>
                  </label>
                  <label class="grid gap-1 text-xs text-n-slate-11">
                    {{ t('KANBAN.SETTINGS.STAGES.WIP_LIMIT') }}
                    <input
                      v-model="stage.wipLimit"
                      data-testid="kanban-settings-stage-wip-limit"
                      type="number"
                      min="1"
                      class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-2 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                    />
                  </label>
                  <button
                    type="button"
                    data-testid="kanban-settings-save-stage-rules"
                    class="flex size-9 items-center justify-center rounded-md text-n-slate-11 hover:bg-n-alpha-2 hover:text-n-slate-12 disabled:cursor-not-allowed disabled:opacity-50"
                    :disabled="Boolean(activeStageActionKey)"
                    :aria-label="t('KANBAN.SETTINGS.STAGES.SAVE')"
                    :title="t('KANBAN.SETTINGS.STAGES.SAVE')"
                    @click="saveStageRules(stage)"
                  >
                    <span class="i-lucide-save size-4" />
                  </button>
                </div>
              </template>
            </Draggable>
          </div>
        </section>

        <section class="grid gap-4 border-b border-n-weak pb-6">
          <h2 class="text-base font-medium text-n-slate-12">
            {{ t('KANBAN.SETTINGS.AGENTS.TITLE') }}
          </h2>
          <div class="flex flex-wrap gap-2">
            <label class="flex items-center gap-2 text-sm text-n-slate-12">
              <input
                v-model="form.visibilityMode"
                data-testid="kanban-settings-all-agents"
                type="radio"
                value="all_agents"
              />
              {{ t('KANBAN.SETTINGS.AGENTS.ALL') }}
            </label>
            <label class="flex items-center gap-2 text-sm text-n-slate-12">
              <input
                v-model="form.visibilityMode"
                data-testid="kanban-settings-selected-agents"
                type="radio"
                value="selected_agents"
              />
              {{ t('KANBAN.SETTINGS.AGENTS.SELECTED') }}
            </label>
          </div>
          <TagMultiSelectComboBox
            v-if="form.visibilityMode === 'selected_agents'"
            v-model="form.visibleUserIds"
            data-testid="kanban-settings-agent-select"
            :options="agentOptions"
            :placeholder="t('KANBAN.SETTINGS.AGENTS.PLACEHOLDER')"
            :search-placeholder="t('KANBAN.SETTINGS.AGENTS.SEARCH')"
            :empty-state="t('KANBAN.SETTINGS.AGENTS.EMPTY')"
          />
        </section>

        <section class="grid gap-4 border-b border-n-weak pb-6">
          <h2 class="text-base font-medium text-n-slate-12">
            {{ t('KANBAN.SETTINGS.INBOXES.TITLE') }}
          </h2>
          <div class="flex flex-wrap gap-2">
            <label class="flex items-center gap-2 text-sm text-n-slate-12">
              <input
                v-model="form.inboxScopeMode"
                data-testid="kanban-settings-all-inboxes"
                type="radio"
                value="all_inboxes"
              />
              {{ t('KANBAN.SETTINGS.INBOXES.ALL') }}
            </label>
            <label class="flex items-center gap-2 text-sm text-n-slate-12">
              <input
                v-model="form.inboxScopeMode"
                data-testid="kanban-settings-selected-inboxes"
                type="radio"
                value="selected_inboxes"
              />
              {{ t('KANBAN.SETTINGS.INBOXES.SELECTED') }}
            </label>
          </div>
          <TagMultiSelectComboBox
            v-if="form.inboxScopeMode === 'selected_inboxes'"
            v-model="form.allowedInboxIds"
            data-testid="kanban-settings-inbox-select"
            :options="inboxOptions"
            :placeholder="t('KANBAN.SETTINGS.INBOXES.PLACEHOLDER')"
            :search-placeholder="t('KANBAN.SETTINGS.INBOXES.SEARCH')"
            :empty-state="t('KANBAN.SETTINGS.INBOXES.EMPTY')"
          />
        </section>

        <section class="grid gap-4 border-b border-n-weak pb-6">
          <h2 class="text-base font-medium text-n-slate-12">
            {{ t('KANBAN.SETTINGS.SALES.TITLE') }}
          </h2>
          <label class="grid gap-1 text-sm font-medium text-n-slate-12">
            {{ t('KANBAN.SETTINGS.SALES.NEXT_ACTION_TYPES') }}
            <textarea
              v-model="form.nextActionTypesText"
              data-testid="kanban-settings-next-action-types"
              rows="5"
              class="rounded-md border border-n-weak bg-n-surface-1 px-3 py-2 text-sm font-normal text-n-slate-12 outline-none placeholder:text-n-slate-10 focus:border-n-brand"
              :placeholder="
                t('KANBAN.SETTINGS.SALES.NEXT_ACTION_TYPES_PLACEHOLDER')
              "
            />
          </label>
          <label class="grid gap-1 text-sm font-medium text-n-slate-12">
            {{ t('KANBAN.SETTINGS.SALES.LOST_REASON_OPTIONS') }}
            <textarea
              v-model="form.lostReasonOptionsText"
              data-testid="kanban-settings-lost-reason-options"
              rows="5"
              class="rounded-md border border-n-weak bg-n-surface-1 px-3 py-2 text-sm font-normal text-n-slate-12 outline-none placeholder:text-n-slate-10 focus:border-n-brand"
              :placeholder="
                t('KANBAN.SETTINGS.SALES.LOST_REASON_OPTIONS_PLACEHOLDER')
              "
            />
          </label>
          <div class="grid gap-3">
            <div class="flex items-center justify-between gap-3">
              <h3 class="mb-0 text-sm font-medium text-n-slate-12">
                {{ t('KANBAN.SETTINGS.SALES.CUSTOM_FIELDS') }}
              </h3>
              <div class="flex flex-wrap justify-end gap-2">
                <Button
                  type="button"
                  data-testid="kanban-settings-add-marketing-fields"
                  icon="i-lucide-megaphone"
                  :label="t('KANBAN.SETTINGS.SALES.ADD_MARKETING_FIELDS')"
                  color="slate"
                  size="sm"
                  @click="addMarketingFields"
                />
                <Button
                  type="button"
                  data-testid="kanban-settings-add-custom-field"
                  icon="i-lucide-plus"
                  :label="t('KANBAN.SETTINGS.SALES.ADD_CUSTOM_FIELD')"
                  color="slate"
                  size="sm"
                  @click="addCustomField"
                />
                <Button
                  type="button"
                  data-testid="kanban-settings-manage-custom-fields"
                  icon="i-lucide-settings-2"
                  :label="t('KANBAN.SETTINGS.SALES.MANAGE_CUSTOM_FIELDS')"
                  color="slate"
                  size="sm"
                  @click="openCustomFieldManager()"
                />
              </div>
            </div>

            <div
              class="flex flex-wrap gap-2 rounded-md border border-n-weak bg-n-surface-2 p-3"
            >
              <button
                v-for="definition in form.customFieldDefinitions.slice(0, 8)"
                :key="definition.clientId"
                type="button"
                class="inline-flex max-w-48 items-center gap-1 rounded-md border border-n-weak bg-n-surface-1 px-2 py-1 text-xs text-n-slate-11 hover:border-n-brand hover:text-n-slate-12"
                @click="openCustomFieldManager(definition.clientId)"
              >
                <i class="i-lucide-grip-vertical size-3" />
                <span class="truncate">{{ definition.label }}</span>
              </button>
              <span
                v-if="form.customFieldDefinitions.length > 8"
                class="px-2 py-1 text-xs text-n-slate-10"
              >
                {{ `+${form.customFieldDefinitions.length - 8}` }}
              </span>
              <span
                v-if="!form.customFieldDefinitions.length"
                class="text-sm text-n-slate-11"
              >
                {{ t('KANBAN.SETTINGS.SALES.NO_CUSTOM_FIELDS') }}
              </span>
            </div>

            <woot-modal
              :show="showCustomFieldManager"
              :show-close-button="false"
              full-width
              size="modal-big"
              :on-close="closeCustomFieldManager"
            >
              <div
                v-if="showCustomFieldManager"
                data-testid="kanban-settings-custom-field-manager"
                class="mx-auto flex max-h-[94vh] w-full max-w-[90rem] flex-col overflow-hidden bg-n-background"
              >
                <header
                  class="flex items-center justify-between gap-4 border-b border-n-weak px-6 py-4"
                >
                  <div>
                    <h3 class="mb-0 text-base font-medium text-n-slate-12">
                      {{ t('KANBAN.SETTINGS.SALES.FIELD_MANAGER_TITLE') }}
                    </h3>
                    <p class="mb-0 mt-1 text-xs text-n-slate-11">
                      {{ t('KANBAN.SETTINGS.SALES.FIELD_MANAGER_DESCRIPTION') }}
                    </p>
                  </div>
                  <div class="flex items-center gap-2">
                    <Button
                      type="button"
                      icon="i-lucide-plus"
                      :label="t('KANBAN.SETTINGS.SALES.ADD_CUSTOM_FIELD')"
                      color="slate"
                      size="sm"
                      @click="addCustomField"
                    />
                    <button
                      type="button"
                      class="flex size-9 items-center justify-center rounded-md text-n-slate-11 hover:bg-n-alpha-2"
                      :aria-label="t('KANBAN.ACTIONS.CLOSE')"
                      @click="closeCustomFieldManager"
                    >
                      <i class="i-lucide-x size-4" />
                    </button>
                  </div>
                </header>
                <div
                  class="grid min-h-0 flex-1 overflow-auto p-5 lg:grid-cols-[18rem_minmax(0,1fr)] lg:gap-5"
                >
                  <aside
                    class="grid content-start gap-1 border-b border-n-weak pb-4 lg:border-b-0 lg:border-r lg:pb-0 lg:pr-4"
                  >
                    <button
                      v-for="definition in form.customFieldDefinitions"
                      :key="definition.clientId"
                      type="button"
                      :data-testid="`kanban-settings-field-list-item-${definition.key}`"
                      class="flex min-w-0 items-center gap-2 rounded-md px-3 py-2 text-left text-sm"
                      :class="
                        selectedCustomFieldId === definition.clientId
                          ? 'bg-n-alpha-2 text-n-slate-12'
                          : 'text-n-slate-11 hover:bg-n-alpha-1'
                      "
                      @click="selectedCustomFieldId = definition.clientId"
                    >
                      <i class="i-lucide-grip-vertical size-4 shrink-0" />
                      <span class="min-w-0 flex-1 truncate">
                        {{
                          definition.label ||
                          t('KANBAN.SETTINGS.SALES.UNNAMED_FIELD')
                        }}
                      </span>
                      <span class="text-xs text-n-slate-10">
                        {{ definition.fieldType }}
                      </span>
                    </button>
                    <p
                      v-if="!form.customFieldDefinitions.length"
                      class="m-0 px-3 py-6 text-center text-sm text-n-slate-10"
                    >
                      {{ t('KANBAN.SETTINGS.SALES.NO_CUSTOM_FIELDS') }}
                    </p>
                  </aside>
                  <main class="grid min-w-0 content-start gap-4">
                    <section
                      class="grid gap-3 rounded-md border border-n-weak p-3"
                    >
                      <div class="grid gap-1">
                        <h4 class="mb-0 text-sm font-medium text-n-slate-12">
                          {{ t('KANBAN.SETTINGS.SALES.TAB_LAYOUT') }}
                        </h4>
                        <p class="mb-0 text-xs text-n-slate-11">
                          {{
                            t('KANBAN.SETTINGS.SALES.TAB_LAYOUT_DESCRIPTION')
                          }}
                        </p>
                      </div>

                      <div class="flex flex-wrap items-center gap-2">
                        <span
                          v-for="section in customFieldLayoutSections"
                          :key="section.key"
                          class="inline-flex h-8 items-center rounded-md border border-n-weak bg-n-surface-1 px-3 text-xs font-medium text-n-slate-12"
                        >
                          {{ section.label }}
                        </span>
                        <button
                          type="button"
                          data-testid="kanban-settings-add-field-section"
                          class="flex size-8 items-center justify-center rounded-md border border-dashed border-n-weak text-n-slate-11 hover:border-n-brand hover:text-n-brand"
                          :aria-label="
                            t('KANBAN.SETTINGS.SALES.ADD_FIELD_SECTION')
                          "
                          @click="openNewFieldSectionForm"
                        >
                          <i class="i-lucide-plus size-4" />
                        </button>
                      </div>

                      <div
                        v-if="showNewFieldSectionForm"
                        class="flex max-w-lg items-end gap-2 rounded-md bg-n-surface-2 p-3"
                      >
                        <label
                          class="grid min-w-0 flex-1 gap-1 text-xs font-medium text-n-slate-11"
                        >
                          {{ t('KANBAN.SETTINGS.SALES.FIELD_SECTION_NAME') }}
                          <input
                            v-model="newFieldSectionName"
                            data-testid="kanban-settings-new-field-section-name"
                            class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm font-normal text-n-slate-12 outline-none focus:border-n-brand"
                            autofocus
                            @keydown.enter.prevent="createCustomFieldSection"
                          />
                        </label>
                        <Button
                          type="button"
                          data-testid="kanban-settings-create-field-section"
                          icon="i-lucide-check"
                          :label="
                            t('KANBAN.SETTINGS.SALES.CREATE_FIELD_SECTION')
                          "
                          color="blue"
                          size="sm"
                          @click="createCustomFieldSection"
                        />
                      </div>

                      <div class="grid gap-3 xl:grid-cols-2">
                        <article
                          v-for="section in customFieldLayoutSections"
                          :key="section.key"
                          class="grid min-w-0 content-start gap-2 rounded-md bg-n-surface-2 p-2"
                        >
                          <h5 class="mb-0 text-xs font-medium text-n-slate-12">
                            {{ section.label }}
                          </h5>
                          <Draggable
                            :model-value="
                              customFieldsForLayoutSection(section.key)
                            "
                            item-key="clientId"
                            group="kanban-custom-field-layout"
                            :data-section-key="section.key"
                            class="grid min-h-16 content-start gap-1.5 rounded-md border border-dashed border-n-weak p-2"
                            @change="
                              moveCustomFieldInLayout(section.key, $event)
                            "
                          >
                            <template #item="{ element }">
                              <button
                                type="button"
                                class="flex min-w-0 cursor-grab items-center gap-2 rounded-md border border-n-weak bg-n-surface-1 px-2 py-1.5 text-left text-xs text-n-slate-12"
                                @click="
                                  selectedCustomFieldId = element.clientId
                                "
                              >
                                <i
                                  class="i-lucide-grip-vertical size-3.5 shrink-0"
                                />
                                <span class="truncate">
                                  {{
                                    element.label ||
                                    element.key ||
                                    t('KANBAN.SETTINGS.SALES.UNNAMED_FIELD')
                                  }}
                                </span>
                              </button>
                            </template>
                            <template #footer>
                              <p
                                v-if="
                                  !customFieldsForLayoutSection(section.key)
                                    .length
                                "
                                class="m-0 self-center text-center text-xs text-n-slate-10"
                              >
                                {{ t('KANBAN.SETTINGS.SALES.EMPTY_TAB') }}
                              </p>
                            </template>
                          </Draggable>
                        </article>
                      </div>
                    </section>

                    <article
                      v-if="selectedCustomField"
                      :key="selectedCustomField.clientId"
                      data-testid="kanban-settings-custom-field-row"
                      class="grid gap-4 rounded-md border border-n-weak bg-n-surface-2 p-4"
                    >
                      <div class="grid gap-3 md:grid-cols-3">
                        <label
                          class="grid gap-1 text-xs font-medium text-n-slate-11"
                        >
                          {{ t('KANBAN.SETTINGS.SALES.FIELD_LABEL') }}
                          <input
                            v-model="selectedCustomField.label"
                            data-testid="kanban-settings-custom-field-label"
                            class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm font-normal text-n-slate-12 outline-none focus:border-n-brand"
                            @input="updateCustomFieldLabel(selectedCustomField)"
                          />
                        </label>
                        <label
                          class="grid gap-1 text-xs font-medium text-n-slate-11"
                        >
                          {{ t('KANBAN.SETTINGS.SALES.FIELD_KEY') }}
                          <input
                            v-model="selectedCustomField.key"
                            class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm font-normal text-n-slate-12 outline-none focus:border-n-brand"
                            @input="
                              selectedCustomField.autoKey = false;
                              syncCustomFieldDefinitionsText();
                            "
                          />
                        </label>
                        <label
                          class="grid gap-1 text-xs font-medium text-n-slate-11"
                        >
                          {{ t('KANBAN.SETTINGS.SALES.FIELD_TYPE') }}
                          <select
                            v-model="selectedCustomField.fieldType"
                            data-testid="kanban-settings-custom-field-type"
                            class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm font-normal text-n-slate-12 outline-none focus:border-n-brand"
                            @change="syncCustomFieldDefinitionsText"
                          >
                            <option
                              v-for="option in customFieldTypeOptions"
                              :key="option.value"
                              :value="option.value"
                            >
                              {{ option.label }}
                            </option>
                          </select>
                        </label>
                      </div>

                      <fieldset
                        v-if="
                          ['select', 'multiselect'].includes(
                            selectedCustomField.fieldType
                          )
                        "
                        class="grid gap-2"
                      >
                        <legend
                          class="mb-1 text-xs font-medium text-n-slate-11"
                        >
                          {{ t('KANBAN.SETTINGS.SALES.FIELD_OPTIONS') }}
                        </legend>
                        <div class="flex max-w-2xl gap-2">
                          <input
                            v-model="newCustomFieldOption"
                            data-testid="kanban-settings-custom-field-option-input"
                            class="h-9 min-w-0 flex-1 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm font-normal text-n-slate-12 outline-none focus:border-n-brand"
                            :placeholder="
                              t(
                                'KANBAN.SETTINGS.SALES.FIELD_OPTION_PLACEHOLDER'
                              )
                            "
                            @keydown.enter.prevent="
                              addCustomFieldOption(selectedCustomField)
                            "
                          />
                          <button
                            type="button"
                            data-testid="kanban-settings-add-field-option"
                            class="flex size-9 shrink-0 items-center justify-center rounded-md border border-n-weak text-n-slate-11 hover:bg-n-alpha-2"
                            :aria-label="
                              t('KANBAN.SETTINGS.SALES.ADD_FIELD_OPTION')
                            "
                            @click="addCustomFieldOption(selectedCustomField)"
                          >
                            <i class="i-lucide-plus size-4" />
                          </button>
                        </div>
                        <div class="flex flex-wrap gap-2">
                          <span
                            v-for="option in customFieldOptionValues(
                              selectedCustomField
                            )"
                            :key="option"
                            class="inline-flex items-center gap-1 rounded-md bg-n-alpha-2 px-2 py-1 text-xs text-n-slate-12"
                          >
                            {{ option }}
                            <button
                              type="button"
                              class="flex size-4 items-center justify-center text-n-slate-10 hover:text-n-ruby-11"
                              :aria-label="
                                t('KANBAN.SETTINGS.SALES.REMOVE_FIELD_OPTION', {
                                  option,
                                })
                              "
                              @click="
                                removeCustomFieldOption(
                                  selectedCustomField,
                                  option
                                )
                              "
                            >
                              <i class="i-lucide-x size-3" />
                            </button>
                          </span>
                        </div>
                      </fieldset>

                      <div class="grid gap-3 md:grid-cols-3">
                        <label
                          class="grid gap-1 text-xs font-medium text-n-slate-11"
                        >
                          {{ t('KANBAN.SETTINGS.SALES.FIELD_WIDTH') }}
                          <select
                            v-model="selectedCustomField.layoutWidth"
                            class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm font-normal text-n-slate-12 outline-none focus:border-n-brand"
                            @change="syncCustomFieldDefinitionsText"
                          >
                            <option
                              v-for="option in customFieldWidthOptions"
                              :key="option.value"
                              :value="option.value"
                            >
                              {{ option.label }}
                            </option>
                          </select>
                        </label>
                        <label
                          class="grid gap-1 text-xs font-medium text-n-slate-11"
                        >
                          {{ t('KANBAN.SETTINGS.SALES.FIELD_SECTION') }}
                          <select
                            v-model="selectedCustomField.layoutSection"
                            class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm font-normal text-n-slate-12 outline-none focus:border-n-brand"
                            @change="syncCustomFieldDefinitionsText"
                          >
                            <option
                              v-for="section in customFieldLayoutSections"
                              :key="section.key"
                              :value="section.key"
                            >
                              {{ section.label }}
                            </option>
                          </select>
                        </label>
                        <label
                          class="grid gap-1 text-xs font-medium text-n-slate-11"
                        >
                          {{ t('KANBAN.SETTINGS.SALES.FIELD_POSITION') }}
                          <input
                            v-model="selectedCustomField.layoutPosition"
                            type="number"
                            min="1"
                            class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm font-normal text-n-slate-12 outline-none focus:border-n-brand"
                            @input="syncCustomFieldDefinitionsText"
                          />
                        </label>
                      </div>

                      <fieldset
                        data-testid="kanban-settings-required-stage-list"
                        class="grid grid-cols-2 gap-2 rounded-md border border-n-weak bg-n-surface-1 p-3 md:grid-cols-3"
                      >
                        <legend
                          class="px-1 text-xs font-medium text-n-slate-11"
                        >
                          {{ t('KANBAN.SETTINGS.SALES.REQUIRED_STAGES') }}
                        </legend>
                        <label
                          v-for="stage in stages"
                          :key="stage.id"
                          class="flex min-w-0 items-center gap-2 text-sm text-n-slate-12"
                        >
                          <input
                            v-model="selectedCustomField.requiredStageIds"
                            data-testid="kanban-settings-required-stage"
                            type="checkbox"
                            :value="stage.id"
                            class="size-4 shrink-0 rounded border-n-weak text-n-brand focus:ring-n-brand"
                            @change="syncCustomFieldDefinitionsText"
                          />
                          <span class="truncate">{{ stage.name }}</span>
                        </label>
                      </fieldset>

                      <div class="grid gap-3 md:grid-cols-2">
                        <label
                          class="grid gap-1 text-xs font-medium text-n-slate-11"
                        >
                          {{ t('KANBAN.SETTINGS.SALES.CONDITION_FIELD') }}
                          <select
                            v-model="selectedCustomField.conditionFieldKey"
                            data-testid="kanban-settings-condition-field"
                            class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm font-normal text-n-slate-12 outline-none focus:border-n-brand"
                            @change="updateConditionField(selectedCustomField)"
                          >
                            <option value="">
                              {{ t('KANBAN.SETTINGS.SALES.CONDITION_NONE') }}
                            </option>
                            <option
                              v-for="candidate in customFieldConditionCandidates(
                                selectedCustomField
                              )"
                              :key="candidate.key"
                              :value="candidate.key"
                            >
                              {{ candidate.label || candidate.key }}
                            </option>
                          </select>
                        </label>
                        <label
                          class="grid gap-1 text-xs font-medium text-n-slate-11"
                        >
                          {{ t('KANBAN.SETTINGS.SALES.CONDITION_VALUE') }}
                          <select
                            v-if="
                              conditionValueOptions(selectedCustomField).length
                            "
                            v-model="selectedCustomField.conditionEquals"
                            data-testid="kanban-settings-condition-value-select"
                            class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm font-normal text-n-slate-12 outline-none focus:border-n-brand"
                            @change="syncCustomFieldDefinitionsText"
                          >
                            <option value="">
                              {{
                                t(
                                  'KANBAN.SETTINGS.SALES.CONDITION_VALUE_PLACEHOLDER'
                                )
                              }}
                            </option>
                            <option
                              v-for="option in conditionValueOptions(
                                selectedCustomField
                              )"
                              :key="option.value"
                              :value="option.value"
                            >
                              {{ option.label }}
                            </option>
                          </select>
                          <input
                            v-else
                            v-model="selectedCustomField.conditionEquals"
                            data-testid="kanban-settings-condition-value-input"
                            :type="conditionValueInputType(selectedCustomField)"
                            :step="
                              conditionValueInputType(selectedCustomField) ===
                              'number'
                                ? 'any'
                                : undefined
                            "
                            :disabled="!selectedCustomField.conditionFieldKey"
                            :placeholder="
                              selectedCustomField.conditionFieldKey
                                ? t(
                                    'KANBAN.SETTINGS.SALES.CONDITION_VALUE_PLACEHOLDER'
                                  )
                                : t(
                                    'KANBAN.SETTINGS.SALES.CONDITION_SELECT_FIELD_FIRST'
                                  )
                            "
                            class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm font-normal text-n-slate-12 outline-none focus:border-n-brand disabled:cursor-not-allowed disabled:bg-n-surface-3"
                            @input="syncCustomFieldDefinitionsText"
                          />
                        </label>
                      </div>

                      <p class="m-0 text-xs text-n-slate-10">
                        {{ t('KANBAN.SETTINGS.SALES.CONDITION_HELP') }}
                      </p>

                      <label
                        v-if="selectedCustomField.fieldType === 'formula'"
                        class="relative grid gap-1 text-xs font-medium text-n-slate-11"
                      >
                        {{ t('KANBAN.SETTINGS.SALES.FORMULA') }}
                        <input
                          v-model="selectedCustomField.formulaDisplay"
                          data-testid="kanban-settings-formula-input"
                          :placeholder="
                            t('KANBAN.SETTINGS.SALES.FORMULA_PLACEHOLDER')
                          "
                          class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 font-mono text-sm font-normal text-n-slate-12 outline-none focus:border-n-brand"
                          @focus="onFormulaInput(selectedCustomField)"
                          @input="onFormulaInput(selectedCustomField)"
                          @keydown="
                            onFormulaKeydown(selectedCustomField, $event)
                          "
                        />
                        <div
                          v-if="formulaSuggestions(selectedCustomField).length"
                          data-testid="kanban-settings-formula-suggestions"
                          class="absolute left-0 right-0 top-[3.75rem] z-20 max-h-48 overflow-auto rounded-md border border-n-weak bg-n-solid-1 p-1 shadow-lg"
                        >
                          <button
                            v-for="(
                              candidate, candidateIndex
                            ) in formulaSuggestions(selectedCustomField)"
                            :key="candidate.key"
                            type="button"
                            class="flex w-full items-center justify-between gap-3 rounded px-2 py-2 text-left text-sm font-normal"
                            :class="
                              activeFormulaSuggestionIndex === candidateIndex
                                ? 'bg-n-alpha-2 text-n-slate-12'
                                : 'text-n-slate-11 hover:bg-n-alpha-1'
                            "
                            @mousedown.prevent="
                              insertFormulaCandidate(
                                selectedCustomField,
                                candidate
                              )
                            "
                          >
                            <span>{{ candidate.label }}</span>
                            <code class="text-xs text-n-slate-10">
                              {{ candidate.key }}
                            </code>
                          </button>
                        </div>
                        <span
                          class="font-sans text-xs font-normal text-n-slate-10"
                        >
                          {{ t('KANBAN.SETTINGS.SALES.FORMULA_HELP') }}
                        </span>
                      </label>

                      <div
                        class="flex flex-wrap items-center justify-between gap-3"
                      >
                        <div class="flex flex-wrap items-center gap-4">
                          <label
                            class="flex items-center gap-2 text-sm text-n-slate-12"
                          >
                            <input
                              type="checkbox"
                              data-testid="kanban-settings-custom-field-show-on-card"
                              :checked="
                                form.compactCardFieldKeys.includes(
                                  selectedCustomField.key
                                )
                              "
                              class="size-4 rounded border-n-weak text-n-brand focus:ring-n-brand"
                              @change="
                                toggleCompactCardField(
                                  selectedCustomField.key,
                                  $event.target.checked
                                )
                              "
                            />
                            {{ t('KANBAN.SETTINGS.SALES.SHOW_ON_CARD') }}
                          </label>
                          <label
                            class="flex items-center gap-2 text-sm text-n-slate-12"
                          >
                            <input
                              v-model="selectedCustomField.important"
                              type="checkbox"
                              data-testid="kanban-settings-custom-field-important"
                              class="size-4 rounded border-n-weak text-n-brand focus:ring-n-brand"
                              @change="syncCustomFieldDefinitionsText"
                            />
                            {{ t('KANBAN.SETTINGS.SALES.IMPORTANT_FIELD') }}
                          </label>
                        </div>
                        <button
                          type="button"
                          class="flex size-8 items-center justify-center rounded-md text-n-ruby-11 hover:bg-n-ruby-2"
                          :aria-label="
                            t('KANBAN.SETTINGS.SALES.REMOVE_CUSTOM_FIELD')
                          "
                          @click="
                            removeCustomFieldById(selectedCustomField.clientId)
                          "
                        >
                          <i class="i-lucide-trash size-4" />
                        </button>
                      </div>
                    </article>

                    <details class="text-sm text-n-slate-11">
                      <summary class="cursor-pointer font-medium">
                        {{ t('KANBAN.SETTINGS.SALES.ADVANCED_JSON') }}
                      </summary>
                      <textarea
                        v-model="form.customFieldDefinitionsText"
                        data-testid="kanban-settings-custom-fields"
                        rows="8"
                        class="font-mono mt-2 w-full rounded-md border border-n-weak bg-n-surface-1 px-3 py-2 text-sm font-normal text-n-slate-12 outline-none placeholder:text-n-slate-10 focus:border-n-brand"
                        :placeholder="
                          t('KANBAN.SETTINGS.SALES.CUSTOM_FIELDS_PLACEHOLDER')
                        "
                      />
                    </details>
                  </main>
                </div>
                <footer
                  class="flex justify-end gap-2 border-t border-n-weak px-6 py-4"
                >
                  <Button
                    type="button"
                    :label="t('KANBAN.ACTIONS.CLOSE')"
                    color="slate"
                    size="sm"
                    @click="closeCustomFieldManager"
                  />
                  <Button
                    type="button"
                    data-testid="kanban-settings-save-fields"
                    icon="i-lucide-save"
                    :label="t('KANBAN.SETTINGS.SAVE')"
                    color="blue"
                    size="sm"
                    :is-loading="isSaving"
                    @click="saveSettings"
                  />
                </footer>
              </div>
            </woot-modal>
          </div>

          <div class="grid gap-2">
            <h3 class="mb-0 text-sm font-medium text-n-slate-12">
              {{ t('KANBAN.SETTINGS.SALES.STALE_ALERTS') }}
            </h3>
            <p class="text-sm text-n-slate-11">
              {{ t('KANBAN.SETTINGS.SALES.STALE_ALERTS_DESCRIPTION') }}
            </p>
            <label
              v-for="stage in stages"
              :key="stage.id"
              class="grid grid-cols-[minmax(0,1fr)_8rem] items-center gap-3 text-sm text-n-slate-12"
            >
              <span class="truncate">{{ stage.name }}</span>
              <span class="flex items-center gap-2">
                <input
                  v-model="form.staleStageThresholds[stage.id]"
                  :data-testid="`kanban-settings-stale-stage-${stage.id}`"
                  type="number"
                  min="1"
                  class="h-9 min-w-0 flex-1 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                  :aria-label="t('KANBAN.SETTINGS.SALES.STALE_DAYS')"
                />
                <span class="text-xs text-n-slate-10">
                  {{ t('KANBAN.SETTINGS.SALES.STALE_DAYS_SUFFIX') }}
                </span>
              </span>
            </label>
          </div>
        </section>

        <section class="grid gap-4 border-b border-n-weak pb-6">
          <h2 class="text-base font-medium text-n-slate-12">
            {{ t('KANBAN.SETTINGS.AUTOMATIONS.TITLE') }}
          </h2>
          <label
            class="flex items-start gap-3 rounded-md border border-n-weak bg-n-surface-2 px-3 py-2 text-sm text-n-slate-12"
          >
            <input
              v-model="form.autoCreateCardsFromConversations"
              data-testid="kanban-settings-auto-create"
              type="checkbox"
              class="mt-1 size-4 rounded border-n-weak text-n-brand focus:ring-n-brand disabled:cursor-not-allowed disabled:opacity-60"
              :disabled="isSavingAutomation"
              @change="saveAutomationSetting"
            />
            <span class="font-medium">
              {{ t('KANBAN.SETTINGS.AUTOMATIONS.AUTO_CREATE') }}
            </span>
          </label>
        </section>

        <section class="grid gap-3 border-b border-n-weak pb-6">
          <h2 class="text-base font-medium text-n-ruby-11">
            {{ t('KANBAN.SETTINGS.DELETE.TITLE') }}
          </h2>
          <p class="text-sm text-n-slate-11">
            {{ t('KANBAN.SETTINGS.DELETE.DESCRIPTION') }}
          </p>
          <Button
            data-testid="kanban-settings-delete"
            icon="i-lucide-trash"
            :label="t('KANBAN.SETTINGS.DELETE.ACTION')"
            color="ruby"
            size="sm"
            class="w-fit"
            :is-loading="isDeleting"
            @click="openDeleteConfirmation"
          />
        </section>

        <p
          v-if="saveError"
          data-testid="kanban-settings-save-error"
          class="text-sm text-n-ruby-11"
        >
          {{ saveError }}
        </p>

        <div class="flex justify-end gap-2">
          <Button
            type="submit"
            data-testid="kanban-settings-save"
            icon="i-lucide-save"
            :label="t('KANBAN.SETTINGS.SAVE')"
            color="blue"
            size="sm"
            :disabled="!form.name.trim()"
            :is-loading="isSaving"
          />
        </div>
      </form>

      <woot-delete-modal
        v-model:show="showDeleteConfirmation"
        :on-close="closeDeleteConfirmation"
        :on-confirm="deleteBoard"
        :title="t('KANBAN.REMOVE_BOARD.TITLE')"
        :message="t('KANBAN.REMOVE_BOARD.MESSAGE')"
        :confirm-text="t('KANBAN.REMOVE_BOARD.CONFIRM')"
        :reject-text="t('KANBAN.REMOVE_BOARD.CANCEL')"
      />

      <woot-modal
        v-model:show="showImportExistingConversationsModal"
        :on-close="closeImportExistingConversationsModal"
      >
        <div
          class="flex w-full max-w-lg flex-col gap-4 rounded-lg bg-n-surface-1 p-6 text-n-slate-12"
          data-testid="kanban-import-existing-conversations-modal"
        >
          <div class="grid gap-1">
            <h3 class="text-lg font-medium">
              {{ t('KANBAN.SETTINGS.AUTOMATIONS.IMPORT_TITLE') }}
            </h3>
            <p class="text-sm text-n-slate-11">
              {{ t('KANBAN.SETTINGS.AUTOMATIONS.IMPORT_DESCRIPTION') }}
            </p>
          </div>

          <label class="flex items-center gap-2 text-sm text-n-slate-12">
            <input
              v-model="ignoreGroupsForImport"
              data-testid="kanban-import-ignore-groups"
              type="checkbox"
              class="size-4 rounded border-n-weak text-n-brand focus:ring-n-brand"
            />
            {{ t('KANBAN.SETTINGS.AUTOMATIONS.IGNORE_GROUPS') }}
          </label>

          <p
            v-if="importError"
            data-testid="kanban-import-error"
            class="text-sm text-n-ruby-11"
          >
            {{ importError }}
          </p>

          <div class="flex justify-end gap-2">
            <Button
              type="button"
              data-testid="kanban-import-skip"
              :label="t('KANBAN.SETTINGS.AUTOMATIONS.SKIP_IMPORT')"
              color="slate"
              size="sm"
              :disabled="isImportingConversations"
              @click="closeImportExistingConversationsModal"
            />
            <Button
              type="button"
              data-testid="kanban-import-existing-conversations"
              icon="i-lucide-upload"
              :label="t('KANBAN.SETTINGS.AUTOMATIONS.IMPORT_EXISTING')"
              color="blue"
              size="sm"
              :is-loading="isImportingConversations"
              @click="importExistingConversations"
            />
          </div>
        </div>
      </woot-modal>
    </div>
  </main>
</template>
