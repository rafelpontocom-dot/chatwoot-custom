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
const isLoadingBirthdayAutomation = ref(false);
const isSavingBirthdayAutomation = ref(false);
const isDeleting = ref(false);
const isDuplicating = ref(false);
const isCreatingStage = ref(false);
const isImportingConversations = ref(false);
const activeSettingsSection = ref('general');
const loadError = ref('');
const saveError = ref('');
const stageError = ref('');
const importError = ref('');
const showUnsavedChangesConfirmation = ref(false);
const serverSettingsSnapshot = ref(null);
const serverSettingsPayload = ref(null);
const showDeleteConfirmation = ref(false);
const showDuplicateConfirmation = ref(false);
const showCreateStageForm = ref(false);
const showImportExistingConversationsModal = ref(false);
const stages = ref([]);
const newStageName = ref('');
const newStageColor = ref(DEFAULT_KANBAN_STAGE_COLOR);
const activeStageActionKey = ref('');
const ignoreGroupsForImport = ref(false);
const activeFormulaFieldId = ref(null);
const activeFormulaSuggestionIndex = ref(0);
const formulaPreviewValues = ref({});
const showCustomFieldManager = ref(false);
const selectedCustomFieldId = ref(null);
const activeFieldSectionKey = ref('details');
const draggedCustomFieldId = ref(null);
const newCustomFieldOption = ref('');
const showNewFieldSectionForm = ref(false);
const newFieldSectionName = ref('');
const sectionPendingRemoval = ref(null);
const sectionRemovalDestination = ref('details');
const showRemoveFieldSectionConfirmation = ref(false);
const newFieldGroupName = ref('');
const newFieldGroupColor = ref('slate');
const automationRules = ref([]);
const automationRulesLoading = ref(false);
const automationRulesSaving = ref(false);
const automationRulesError = ref('');
const selectedAutomationRuleId = ref(null);
const automationTestCardId = ref('');
const automationTestResult = ref(null);
const showAutomationDeleteConfirmation = ref(false);
const automationRulePendingDeletion = ref(null);
const cadences = ref([]);
const cadencesLoading = ref(false);
const cadenceSaving = ref(false);
const cadenceError = ref('');
const appointmentReminderRules = ref([]);
const appointmentReminderLoading = ref(false);
const appointmentReminderSaving = ref(false);
const appointmentReminderError = ref('');
const birthdayAutomationError = ref('');
const birthdayAutomation = reactive({
  active: false,
  daysBefore: 0,
  deliveryChannels: [],
  optInAttributeKey: 'birthday_messages_opt_in',
  messageLocale: 'pt_BR',
  timezone: '',
  timezoneName: '',
  sendTime: '09:00',
  messageTemplate:
    'Feliz aniversário, {{contact_name}}! Desejamos um dia especial para você.',
});
const cadenceForm = reactive({
  name: '',
  pauseOnIncomingMessage: true,
  triggerType: 'manual',
  triggerStageId: '',
  steps: [{ delayHours: 0, actionType: '', note: '' }],
});
const appointmentReminderForm = reactive({
  triggerStageId: '',
  fieldKey: 'system_starts_at',
  offsets: '48,24,2',
  channels: ['whatsapp'],
  optInAttributeKey: 'appointment_reminders_opt_in',
  messageTemplates: {},
});
const defaultAppointmentReminderMessage =
  'Olá, {{contact_name}}! Lembramos que sua consulta será em {{appointment_date}}.';
const appointmentReminderOffsets = computed(() =>
  appointmentReminderForm.offsets
    .split(',')
    .map(value => Number(value.trim()))
    .filter(value => Number.isInteger(value) && value > 0)
    .filter((value, index, values) => values.indexOf(value) === index)
);
const automationRuleForm = reactive({
  name: '',
  description: '',
  eventName: 'kanban.card.stage_changed',
  active: true,
  stageId: '',
  ownerId: '',
  fieldKey: '',
  fieldOperator: 'equals',
  fieldValue: '',
  actions: [
    {
      actionName: 'move_stage',
      stageId: '',
      ownerId: '',
      fieldKey: '',
      fieldValue: '',
      nextActionType: '',
      nextActionAt: '',
      nextActionNote: '',
    },
  ],
});
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
  appointmentReminderHours: '',
  lockVersion: null,
});

const boardId = computed(() => Number(route.params.boardId));
const settingsNavigation = computed(() => [
  {
    key: 'general',
    label: t('KANBAN.SETTINGS.GENERAL.TITLE'),
    icon: 'i-lucide-sliders-horizontal',
  },
  {
    key: 'access',
    label: t('KANBAN.SETTINGS.AGENTS.TITLE'),
    icon: 'i-lucide-users',
  },
  {
    key: 'sales',
    label: t('KANBAN.SETTINGS.SALES.TITLE'),
    icon: 'i-lucide-panels-top-left',
  },
  {
    key: 'automation',
    label: t('KANBAN.SETTINGS.AUTOMATIONS.TITLE'),
    icon: 'i-lucide-zap',
  },
  {
    key: 'danger',
    label: t('KANBAN.SETTINGS.DELETE.TITLE'),
    icon: 'i-lucide-trash-2',
  },
]);

const automationEventOptions = computed(() => [
  {
    value: 'kanban.card.created',
    label: t('KANBAN.SETTINGS.AUTOMATIONS.EVENTS.CREATED'),
  },
  {
    value: 'kanban.card.stage_changed',
    label: t('KANBAN.SETTINGS.AUTOMATIONS.EVENTS.STAGE_CHANGED'),
  },
  {
    value: 'kanban.card.next_action_completed',
    label: t('KANBAN.SETTINGS.AUTOMATIONS.EVENTS.NEXT_ACTION_COMPLETED'),
  },
  {
    value: 'kanban.card.won',
    label: t('KANBAN.SETTINGS.AUTOMATIONS.EVENTS.WON'),
  },
  {
    value: 'kanban.card.lost',
    label: t('KANBAN.SETTINGS.AUTOMATIONS.EVENTS.LOST'),
  },
]);

const automationActionOptions = computed(() => [
  {
    value: 'move_stage',
    label: t('KANBAN.SETTINGS.AUTOMATIONS.ACTIONS.MOVE_STAGE'),
  },
  {
    value: 'assign_owner',
    label: t('KANBAN.SETTINGS.AUTOMATIONS.ACTIONS.ASSIGN_OWNER'),
  },
  {
    value: 'set_next_action',
    label: t('KANBAN.SETTINGS.AUTOMATIONS.ACTIONS.SET_NEXT_ACTION'),
  },
  {
    value: 'set_field',
    label: t('KANBAN.SETTINGS.AUTOMATIONS.ACTIONS.SET_FIELD'),
  },
  {
    value: 'archive_card',
    label: t('KANBAN.SETTINGS.AUTOMATIONS.ACTIONS.ARCHIVE_CARD'),
  },
]);
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

const settingsFingerprint = () =>
  JSON.stringify({
    name: form.name,
    description: form.description,
    autoCreateCardsFromConversations: form.autoCreateCardsFromConversations,
    visibilityMode: form.visibilityMode,
    visibleUserIds: form.visibleUserIds,
    inboxScopeMode: form.inboxScopeMode,
    allowedInboxIds: form.allowedInboxIds,
    nextActionTypesText: form.nextActionTypesText,
    lostReasonOptionsText: form.lostReasonOptionsText,
    customFieldDefinitionsText: form.customFieldDefinitionsText,
    customFieldSections: form.customFieldSections,
    compactCardFieldKeys: form.compactCardFieldKeys,
    staleStageThresholds: form.staleStageThresholds,
    appointmentReminderHours: form.appointmentReminderHours,
  });

const hasUnsavedSettings = computed(
  () =>
    serverSettingsSnapshot.value !== null &&
    settingsFingerprint() !== serverSettingsSnapshot.value
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

const automationFieldOptions = computed(() => [
  ...systemConditionFields.value,
  ...form.customFieldDefinitions.map(field => ({
    key: field.key,
    label: field.label || field.key,
    fieldType: field.fieldType,
    conditionOptions: field.optionsText
      ? linesFromText(field.optionsText).map(value => ({ value, label: value }))
      : [],
  })),
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
  UTM_REFERRER: t('KANBAN.SETTINGS.SALES.MARKETING_FIELDS.UTM_REFERRER'),
  REFERRER: t('KANBAN.SETTINGS.SALES.MARKETING_FIELDS.REFERRER'),
  GOOGLE_CLIENT_ID: t(
    'KANBAN.SETTINGS.SALES.MARKETING_FIELDS.GOOGLE_CLIENT_ID'
  ),
  GCLID: t('KANBAN.SETTINGS.SALES.MARKETING_FIELDS.GCLID'),
  FBCLID: t('KANBAN.SETTINGS.SALES.MARKETING_FIELDS.FBCLID'),
  FBC: t('KANBAN.SETTINGS.SALES.MARKETING_FIELDS.FBC'),
  FBP: t('KANBAN.SETTINGS.SALES.MARKETING_FIELDS.FBP'),
  TTCLID: t('KANBAN.SETTINGS.SALES.MARKETING_FIELDS.TTCLID'),
  TIKTOK_AD_ID: t('KANBAN.SETTINGS.SALES.MARKETING_FIELDS.TIKTOK_AD_ID'),
  TIKTOK_AD_NAME: t('KANBAN.SETTINGS.SALES.MARKETING_FIELDS.TIKTOK_AD_NAME'),
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

const marketingFieldAliases = Object.freeze({
  campaign_name: 'campaign',
  adset_name: 'adset',
  ad_name: 'ad',
  google_client_id: 'gclientid',
  tiktok_ad_id: 'ttad_id',
  tiktok_ad_name: 'ttad_name',
  fbclid: 'fvclid',
});
const obsoleteMarketingFieldKeys = new Set([
  'utm_id',
  'gbraid',
  'wbraid',
  'dclid',
  'msclkid',
]);

const normalizeMarketingFieldDefinitions = definitions => {
  const canonicalDefinitions = marketingFieldDefinitions.value;
  const canonicalKeys = new Set(
    canonicalDefinitions.map(definition => definition.key)
  );
  const hasMarketingPreset = definitions.some(definition => {
    const key = definition.key || '';
    const section = definition.layout?.section || definition.layoutSection;
    return (
      section === 'marketing' &&
      (canonicalKeys.has(key) ||
        Object.prototype.hasOwnProperty.call(marketingFieldAliases, key) ||
        obsoleteMarketingFieldKeys.has(key))
    );
  });

  if (!hasMarketingPreset) return definitions;

  const normalized = [];
  const seenCanonicalKeys = new Set();
  let marketingPosition = 1;

  definitions.forEach(definition => {
    const key = definition.key || '';
    const section = definition.layout?.section || definition.layoutSection;
    const canonicalKey = marketingFieldAliases[key] || key;
    const isMarketingDefinition =
      section === 'marketing' &&
      (canonicalKeys.has(canonicalKey) ||
        Object.prototype.hasOwnProperty.call(marketingFieldAliases, key) ||
        obsoleteMarketingFieldKeys.has(key));

    if (!isMarketingDefinition) {
      normalized.push(definition);
      return;
    }

    if (
      obsoleteMarketingFieldKeys.has(key) ||
      seenCanonicalKeys.has(canonicalKey)
    ) {
      return;
    }

    const preset = canonicalDefinitions.find(item => item.key === canonicalKey);
    if (!preset) return;

    normalized.push({
      ...definition,
      key: canonicalKey,
      label: preset.label,
      fieldType: preset.fieldType,
      options: preset.options || [],
      optionsText: (preset.options || []).join('\n'),
      layout: {
        ...(definition.layout || {}),
        section: 'marketing',
        position: marketingPosition,
        width: preset.layoutWidth || 'half',
      },
    });
    seenCanonicalKeys.add(canonicalKey);
    marketingPosition += 1;
  });

  canonicalDefinitions.forEach(preset => {
    if (seenCanonicalKeys.has(preset.key)) return;

    normalized.push({
      key: preset.key,
      label: preset.label,
      fieldType: preset.fieldType,
      options: preset.options || [],
      optionsText: (preset.options || []).join('\n'),
      requiredStageIds: [],
      condition: {},
      formula: null,
      formulaResultType: null,
      important: false,
      layout: {
        section: 'marketing',
        position: marketingPosition,
        width: preset.layoutWidth || 'half',
      },
    });
    marketingPosition += 1;
  });

  return normalized;
};

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
      fieldType: 'currency',
      searchAliases: 'valor value amount',
    },
    ...form.customFieldDefinitions
      .filter(
        (field, fieldIndex) =>
          field !== definition &&
          field.key &&
          [
            'integer',
            'decimal',
            'currency',
            'formula',
            'date',
            'datetime',
          ].includes(field.fieldType) &&
          (field.fieldType !== 'formula' || fieldIndex < definitionIndex)
      )
      .map(field => ({
        key: field.key,
        label: field.label || field.key,
        fieldType: field.fieldType,
        formulaResultType: field.formulaResultType,
      })),
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

const formulaPreviewCandidates = computed(() => {
  if (
    !selectedCustomField.value ||
    selectedCustomField.value.fieldType !== 'formula'
  ) {
    return [];
  }

  return numericFormulaCandidates(selectedCustomField.value).filter(
    candidate =>
      ['integer', 'decimal', 'currency', 'formula'].includes(
        candidate.fieldType
      ) &&
      (candidate.fieldType !== 'formula' ||
        ['number', undefined, ''].includes(candidate.formulaResultType))
  );
});

const evaluateFormulaPreview = (expression, values) => {
  const normalizedExpression = String(expression || '').replace(
    /[a-zA-Z_][a-zA-Z0-9_]*/g,
    token => {
      const value = Number(values[token]);
      return Number.isFinite(value) ? String(value) : 'NaN';
    }
  );
  if (!/^[\d\s+\-*/().]+$/u.test(normalizedExpression)) return null;

  const tokens = normalizedExpression.match(/\d+(?:\.\d+)?|[+\-*/()]/gu);
  if (!tokens || tokens.join('') !== normalizedExpression.replace(/\s+/gu, ''))
    return null;

  let index = 0;
  let parseAdditive;
  const parsePrimary = () => {
    const token = tokens[index];
    if (token === '(') {
      index += 1;
      const result = parseAdditive();
      if (tokens[index] !== ')') return null;
      index += 1;
      return result;
    }
    if (!token || !/^\d/u.test(token)) return null;
    index += 1;
    return Number(token);
  };
  const parseMultiplicative = () => {
    let result = parsePrimary();
    while (result !== null && ['*', '/'].includes(tokens[index])) {
      const operator = tokens[index];
      index += 1;
      const right = parsePrimary();
      if (right === null || (operator === '/' && right === 0)) return null;
      result = operator === '*' ? result * right : result / right;
    }
    return result;
  };
  parseAdditive = () => {
    let result = parseMultiplicative();
    while (result !== null && ['+', '-'].includes(tokens[index])) {
      const operator = tokens[index];
      index += 1;
      const right = parseMultiplicative();
      if (right === null) return null;
      result = operator === '+' ? result + right : result - right;
    }
    return result;
  };

  const result = parseAdditive();
  return index === tokens.length && Number.isFinite(result) ? result : null;
};

const formulaPreviewResult = computed(() => {
  if (!selectedCustomField.value) return null;

  return evaluateFormulaPreview(
    stableFormulaValue(selectedCustomField.value),
    formulaPreviewValues.value
  );
});

const applyBirthdayAutomation = payload => {
  const settings = camelcaseKeys(payload || {}, { deep: true });
  birthdayAutomation.active = Boolean(settings.active);
  birthdayAutomation.daysBefore = Number(settings.daysBefore) || 0;
  birthdayAutomation.deliveryChannels = settings.deliveryChannels || [];
  birthdayAutomation.optInAttributeKey =
    settings.optInAttributeKey || 'birthday_messages_opt_in';
  birthdayAutomation.messageLocale = settings.messageLocale || 'pt_BR';
  birthdayAutomation.timezone = settings.timezone || '';
  birthdayAutomation.timezoneName = settings.timezoneName || '';
  birthdayAutomation.sendTime = settings.sendTime || '09:00';
  birthdayAutomation.messageTemplate = settings.messageTemplate || '';
};

const fetchBirthdayAutomation = async () => {
  if (!isAdmin.value) return;

  isLoadingBirthdayAutomation.value = true;
  birthdayAutomationError.value = '';
  try {
    const response = await KanbanBoardsAPI.getBirthdayAutomation();
    applyBirthdayAutomation(response.data);
  } catch (error) {
    birthdayAutomationError.value = getErrorMessage(
      error,
      t('KANBAN.SETTINGS.AUTOMATIONS.BIRTHDAY.LOAD_ERROR')
    );
  } finally {
    isLoadingBirthdayAutomation.value = false;
  }
};

const saveBirthdayAutomation = async () => {
  if (isSavingBirthdayAutomation.value || !isAdmin.value) return;

  isSavingBirthdayAutomation.value = true;
  birthdayAutomationError.value = '';
  try {
    const response = await KanbanBoardsAPI.updateBirthdayAutomation({
      birthday_automation: {
        active: birthdayAutomation.active,
        days_before: Number(birthdayAutomation.daysBefore) || 0,
        delivery_channels: birthdayAutomation.deliveryChannels,
        opt_in_attribute_key: birthdayAutomation.optInAttributeKey.trim(),
        message_locale: birthdayAutomation.messageLocale,
        timezone: birthdayAutomation.timezone.trim() || null,
        send_time: birthdayAutomation.sendTime,
        message_template: birthdayAutomation.messageTemplate.trim(),
      },
    });
    applyBirthdayAutomation(response.data);
    useAlert(t('KANBAN.SETTINGS.AUTOMATIONS.BIRTHDAY.SAVE_SUCCESS'));
  } catch (error) {
    birthdayAutomationError.value = getErrorMessage(
      error,
      t('KANBAN.SETTINGS.AUTOMATIONS.BIRTHDAY.SAVE_ERROR')
    );
    useAlert(birthdayAutomationError.value);
  } finally {
    isSavingBirthdayAutomation.value = false;
  }
};

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
  form.customFieldDefinitions = normalizeMarketingFieldDefinitions(
    settings.customFieldDefinitions || []
  ).map(definition => ({
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
    formulaResultType:
      definition.formulaResultType ||
      definition.formula_result_type ||
      'number',
    layoutSection: definition.layout?.section || 'details',
    layoutGroup: definition.layout?.group || '',
    layoutPosition: definition.layout?.position || 1,
    layoutWidth: definition.layout?.width || 'full',
    important: Boolean(definition.important),
    autoKey: false,
  }));
  form.customFieldDefinitions.forEach(definition => {
    definition.formulaDisplay = formulaDisplayValue(definition);
  });
  const configuredSections = (settings.customFieldSections || []).map(
    section => {
      const groups = (section.groups || []).map(group => ({
        color: 'slate',
        ...group,
      }));
      return { color: 'slate', ...section, groups };
    }
  );
  const builtInSections = [
    {
      key: 'details',
      label: t('KANBAN.SETTINGS.SALES.TABS.GENERAL'),
      builtIn: true,
      color: 'slate',
      groups: [],
    },
    {
      key: 'marketing',
      label: t('KANBAN.SETTINGS.SALES.TABS.MARKETING'),
      builtIn: true,
      color: 'slate',
      groups: [],
    },
  ];
  const hasPersistedTabOrder = builtInSections.every(builtIn =>
    configuredSections.some(section => section.key === builtIn.key)
  );
  const configuredSectionsByKey = new Map(
    configuredSections.map(section => [section.key, section])
  );
  form.customFieldSections = hasPersistedTabOrder
    ? configuredSections
    : [
        ...builtInSections.map(section => ({
          ...section,
          ...(configuredSectionsByKey.get(section.key) || {}),
        })),
        ...configuredSections.filter(
          section =>
            !builtInSections.some(builtIn => builtIn.key === section.key)
        ),
      ];
  form.compactCardFieldKeys = settings.compactCardFieldKeys || [];
  form.staleStageThresholds = settings.staleStageThresholds || {};
  form.appointmentReminderHours = settings.appointmentReminderHours ?? '';
  form.lockVersion = settings.lockVersion ?? null;
  // Keep the editor's normalized view model and the API payload in sync.
  // eslint-disable-next-line no-use-before-define
  syncCustomFieldDefinitionsText();
  serverSettingsPayload.value = JSON.parse(JSON.stringify(settings));
  serverSettingsSnapshot.value = settingsFingerprint();
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
      fetchBirthdayAutomation(),
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
  if (!Array.isArray(parsedValue)) return [];

  return parsedValue.map(definition => ({
    key: definition.key,
    label: definition.label,
    field_type: definition.field_type || definition.fieldType,
    options: definition.options || [],
    required_stage_ids:
      definition.required_stage_ids || definition.requiredStageIds || [],
    condition: definition.condition || {},
    formula: definition.formula || null,
    formula_result_type:
      definition.formula_result_type || definition.formulaResultType || null,
    important: Boolean(definition.important),
    layout: definition.layout || {},
  }));
};

const customFieldSectionsPayload = () =>
  form.customFieldSections.map(section => ({
    key: section.key,
    label: section.label,
    color: section.color,
    groups: (section.groups || []).map(group => ({
      key: group.key,
      label: group.label,
      color: group.color,
    })),
  }));

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
  formula_result_type:
    definition.fieldType === 'formula' ? definition.formulaResultType : null,
  important: Boolean(definition.important),
  layout: {
    section: definition.layoutSection || 'details',
    group: definition.layoutGroup || '',
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
  layoutGroup = '',
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
  formulaResultType: 'number',
  layoutSection,
  layoutGroup,
  layoutPosition,
  layoutWidth,
  important,
  autoKey,
});

function syncCustomFieldDefinitionsText() {
  form.customFieldDefinitionsText = JSON.stringify(
    form.customFieldDefinitions.map(customFieldPayload),
    null,
    2
  );
}

const addCustomField = () => {
  const definition = createCustomFieldRow({
    layoutSection: activeFieldSectionKey.value,
    layoutPosition:
      form.customFieldDefinitions.filter(
        item =>
          (item.layoutSection || 'details') === activeFieldSectionKey.value
      ).length + 1,
  });
  form.customFieldDefinitions.push(definition);
  selectedCustomFieldId.value = definition.clientId;
  showCustomFieldManager.value = true;
  syncCustomFieldDefinitionsText();
};

const openCustomFieldManager = clientId => {
  selectedCustomFieldId.value =
    clientId || form.customFieldDefinitions[0]?.clientId || null;
  const selected = form.customFieldDefinitions.find(
    definition => definition.clientId === selectedCustomFieldId.value
  );
  activeFieldSectionKey.value = selected?.layoutSection || 'details';
  showCustomFieldManager.value = true;
};

const closeCustomFieldManager = () => {
  if (hasUnsavedSettings.value) {
    showUnsavedChangesConfirmation.value = true;
    return;
  }

  showCustomFieldManager.value = false;
  newCustomFieldOption.value = '';
};

const discardUnsavedSettings = () => {
  showUnsavedChangesConfirmation.value = false;
  if (serverSettingsPayload.value) applySettings(serverSettingsPayload.value);
  showCustomFieldManager.value = false;
  newCustomFieldOption.value = '';
};

const isStaleSettingsError = error =>
  error?.response?.status === 409 &&
  error?.response?.data?.code === 'stale_settings';

const reloadSettingsAfterConflict = async () => {
  saveError.value = '';
  await fetchSettings();
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
  const configuredSections = [];
  const seenKeys = new Set();
  form.customFieldSections.forEach(section => {
    if (seenKeys.has(section.key)) return;

    seenKeys.add(section.key);
    configuredSections.push({
      color: 'slate',
      groups: [],
      builtIn: ['details', 'marketing'].includes(section.key),
      ...section,
    });
  });
  ['details', 'marketing'].forEach(sectionKey => {
    if (seenKeys.has(sectionKey)) return;

    seenKeys.add(sectionKey);
    configuredSections.push({
      key: sectionKey,
      label: customFieldSectionLabel(sectionKey),
      builtIn: true,
      color: 'slate',
      groups: [],
    });
  });
  const knownKeys = new Set(configuredSections.map(section => section.key));

  form.customFieldDefinitions.forEach(definition => {
    const key = definition.layoutSection || 'details';
    if (knownKeys.has(key)) return;

    knownKeys.add(key);
    configuredSections.push({
      key,
      label: customFieldSectionLabel(key),
      color: 'slate',
      groups: [],
    });
  });

  return configuredSections;
});

const customFieldSectionConfig = sectionKey => {
  let section = form.customFieldSections.find(item => item.key === sectionKey);
  if (!section && ['details', 'marketing'].includes(sectionKey)) {
    section = {
      key: sectionKey,
      label: customFieldSectionLabel(sectionKey),
      color: 'slate',
      groups: [],
    };
    form.customFieldSections.push(section);
  }
  if (!section) return null;
  section.groups ||= [];
  return section;
};

const customFieldGroupsForSection = sectionKey =>
  customFieldLayoutSections.value.find(section => section.key === sectionKey)
    ?.groups || [];

const updateCustomFieldSection = definition => {
  const groups = customFieldGroupsForSection(definition.layoutSection);
  if (!groups.some(group => group.key === definition.layoutGroup)) {
    definition.layoutGroup = '';
  }
  syncCustomFieldDefinitionsText();
};

const createCustomFieldGroup = () => {
  const label = newFieldGroupName.value.trim();
  if (!label) return;

  const section = customFieldSectionConfig(activeFieldSectionKey.value);
  if (!section) return;

  const usedKeys = new Set(section.groups.map(group => group.key));
  const baseKey = customFieldKeyFromLabel(label) || 'novo_grupo';
  let key = baseKey;
  let suffix = 2;
  while (usedKeys.has(key)) {
    key = `${baseKey}_${suffix}`;
    suffix += 1;
  }

  section.groups.push({ key, label, color: newFieldGroupColor.value });
  newFieldGroupName.value = '';
  newFieldGroupColor.value = 'slate';
  syncCustomFieldDefinitionsText();
};

const removeCustomFieldGroup = (sectionKey, groupKey) => {
  const section = customFieldSectionConfig(sectionKey);
  if (!section) return;

  form.customFieldDefinitions.forEach(definition => {
    if (
      definition.layoutSection === sectionKey &&
      definition.layoutGroup === groupKey
    ) {
      definition.layoutGroup = '';
    }
  });
  section.groups = section.groups.filter(group => group.key !== groupKey);
  syncCustomFieldDefinitionsText();
};

const moveCustomFieldToGroup = (sectionKey, groupKey, event) => {
  event.preventDefault();
  const clientId =
    event.dataTransfer?.getData('text/plain') || draggedCustomFieldId.value;
  const definition = form.customFieldDefinitions.find(
    item => item.clientId === clientId
  );
  if (!definition) return;

  // The section mover is declared with the other drag handlers below.
  // eslint-disable-next-line no-use-before-define
  moveCustomFieldToSection(
    sectionKey,
    definition,
    // eslint-disable-next-line no-use-before-define
    customFieldsForLayoutSection(sectionKey).length
  );
  definition.layoutGroup = groupKey;
  syncCustomFieldDefinitionsText();
  draggedCustomFieldId.value = null;
};

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

  form.customFieldSections.push({ key, label, color: 'slate', groups: [] });
  activeFieldSectionKey.value = key;
  newFieldSectionName.value = '';
  showNewFieldSectionForm.value = false;
};

const customSectionByKey = sectionKey =>
  form.customFieldSections.find(section => section.key === sectionKey);

const moveCustomFieldSection = (sectionKey, direction) => {
  const sectionIndex = form.customFieldSections.findIndex(
    section => section.key === sectionKey
  );
  const nextIndex = sectionIndex + direction;
  if (
    sectionIndex < 0 ||
    nextIndex < 0 ||
    nextIndex >= form.customFieldSections.length
  )
    return;

  const sections = [...form.customFieldSections];
  [sections[sectionIndex], sections[nextIndex]] = [
    sections[nextIndex],
    sections[sectionIndex],
  ];
  form.customFieldSections = sections;
  syncCustomFieldDefinitionsText();
};

const openRemoveCustomFieldSection = section => {
  if (section.builtIn) return;

  sectionPendingRemoval.value = section;
  sectionRemovalDestination.value = 'details';
  showRemoveFieldSectionConfirmation.value = true;
};

const removeCustomFieldSection = () => {
  const section = sectionPendingRemoval.value;
  if (!section) return;

  form.customFieldDefinitions.forEach(definition => {
    if ((definition.layoutSection || 'details') === section.key) {
      definition.layoutSection = sectionRemovalDestination.value;
    }
  });
  form.customFieldSections = form.customFieldSections.filter(
    item => item.key !== section.key
  );
  if (activeFieldSectionKey.value === section.key) {
    activeFieldSectionKey.value = sectionRemovalDestination.value;
  }
  sectionPendingRemoval.value = null;
  showRemoveFieldSectionConfirmation.value = false;
  syncCustomFieldDefinitionsText();
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
const customFieldsForLayoutGroup = (sectionKey, groupKey) =>
  customFieldsForLayoutSection(sectionKey).filter(
    definition => definition.layoutGroup === groupKey
  );
const renumberCustomFieldSection = sectionKey => {
  customFieldsForLayoutSection(sectionKey).forEach((definition, index) => {
    definition.layoutPosition = index + 1;
  });
};
const selectCustomField = definition => {
  selectedCustomFieldId.value = definition.clientId;
  activeFieldSectionKey.value = definition.layoutSection || 'details';
};
const moveCustomFieldToSection = (sectionKey, definition, newIndex) => {
  const previousSectionKey = definition.layoutSection || 'details';
  definition.layoutSection = sectionKey;

  const sectionFields = customFieldsForLayoutSection(sectionKey).filter(
    field => field !== definition
  );
  const targetIndex = Math.max(
    0,
    Math.min(Number(newIndex) || sectionFields.length, sectionFields.length)
  );
  sectionFields.splice(targetIndex, 0, definition);
  sectionFields.forEach((field, index) => {
    field.layoutPosition = index + 1;
  });

  if (previousSectionKey !== sectionKey) {
    renumberCustomFieldSection(previousSectionKey);
  }
  activeFieldSectionKey.value = sectionKey;
  selectedCustomFieldId.value = definition.clientId;
  syncCustomFieldDefinitionsText();
};
const moveCustomFieldInLayout = (sectionKey, event) => {
  const change = event.added || event.moved;
  if (!change) return;

  moveCustomFieldToSection(sectionKey, change.element, change.newIndex);
};
const moveCustomFieldInGroup = (sectionKey, groupKey, event) => {
  const change = event.added || event.moved;
  if (!change) return;

  moveCustomFieldToSection(sectionKey, change.element, change.newIndex);
  change.element.layoutGroup = groupKey;
  syncCustomFieldDefinitionsText();
};
const onCustomFieldDragStart = (event, definition) => {
  draggedCustomFieldId.value = definition.clientId;
  if (event.dataTransfer) {
    event.dataTransfer.effectAllowed = 'move';
    event.dataTransfer.setData('text/plain', definition.clientId);
  }
};
const onCustomFieldDragEnd = () => {
  draggedCustomFieldId.value = null;
};
const onCustomFieldDrop = (sectionKey, event) => {
  event.preventDefault();
  const clientId =
    event.dataTransfer?.getData('text/plain') || draggedCustomFieldId.value;
  const definition = form.customFieldDefinitions.find(
    item => item.clientId === clientId
  );
  if (definition) {
    moveCustomFieldToSection(
      sectionKey,
      definition,
      customFieldsForLayoutSection(sectionKey).length
    );
  }
  draggedCustomFieldId.value = null;
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
    'google_client_id',
    'tiktok_ad_id',
    'tiktok_ad_name',
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
    ...(form.lockVersion !== null ? { lock_version: form.lockVersion } : {}),
    custom_field_definitions: customFieldDefinitionsFromText(
      form.customFieldDefinitionsText
    ),
    custom_field_sections: customFieldSectionsPayload(),
    compact_card_field_keys: form.compactCardFieldKeys,
    stale_stage_thresholds: normalizedStaleStageThresholds(),
    appointment_reminder_hours:
      form.appointmentReminderHours === ''
        ? null
        : Number(form.appointmentReminderHours),
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
    saveError.value = isStaleSettingsError(error)
      ? t('KANBAN.SETTINGS.STALE_SETTINGS')
      : getErrorMessage(error, t('KANBAN.SETTINGS.SAVE_ERROR'));
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

const blankAutomationAction = () => ({
  actionName: 'move_stage',
  stageId: '',
  ownerId: '',
  fieldKey: '',
  fieldValue: '',
  nextActionType: '',
  nextActionAt: '',
  nextActionNote: '',
});

const resetAutomationRuleForm = () => {
  selectedAutomationRuleId.value = null;
  automationTestResult.value = null;
  automationRuleForm.name = '';
  automationRuleForm.description = '';
  automationRuleForm.eventName = 'kanban.card.stage_changed';
  automationRuleForm.active = true;
  automationRuleForm.stageId = '';
  automationRuleForm.ownerId = '';
  automationRuleForm.fieldKey = '';
  automationRuleForm.fieldOperator = 'equals';
  automationRuleForm.fieldValue = '';
  automationRuleForm.actions.splice(
    0,
    automationRuleForm.actions.length,
    blankAutomationAction()
  );
};

const applyAutomationRule = rule => {
  const normalizedRule = camelcaseKeys(rule || {}, { deep: true });
  const conditions = normalizedRule.conditions || {};
  const firstField = conditions.fields?.[0] || {};
  selectedAutomationRuleId.value = normalizedRule.id;
  automationTestResult.value = null;
  automationRuleForm.name = normalizedRule.name || '';
  automationRuleForm.description = normalizedRule.description || '';
  automationRuleForm.eventName =
    normalizedRule.eventName || 'kanban.card.stage_changed';
  automationRuleForm.active = normalizedRule.active !== false;
  automationRuleForm.stageId = conditions.stageIds?.[0] || '';
  automationRuleForm.ownerId = conditions.ownerIds?.[0] || '';
  automationRuleForm.fieldKey = firstField.fieldKey || '';
  automationRuleForm.fieldOperator = firstField.operator || 'equals';
  automationRuleForm.fieldValue = firstField.value ?? '';
  const actions = (normalizedRule.actions || []).map(action => ({
    ...blankAutomationAction(),
    actionName: action.actionName || 'move_stage',
    stageId: action.actionParams?.stageId || '',
    ownerId: action.actionParams?.ownerId || '',
    fieldKey: action.actionParams?.fieldKey || '',
    fieldValue: action.actionParams?.value ?? '',
    nextActionType: action.actionParams?.nextActionType || '',
    nextActionAt: action.actionParams?.nextActionAt || '',
    nextActionNote: action.actionParams?.nextActionNote || '',
  }));
  automationRuleForm.actions.splice(
    0,
    automationRuleForm.actions.length,
    ...(actions.length ? actions : [blankAutomationAction()])
  );
};

const fetchAutomationRules = async () => {
  if (!isAdmin.value) return;

  automationRulesLoading.value = true;
  automationRulesError.value = '';
  try {
    const response = await KanbanBoardsAPI.getAutomationRules(boardId.value);
    automationRules.value = camelcaseKeys(response.data || [], { deep: true });
  } catch (error) {
    automationRulesError.value = getErrorMessage(
      error,
      t('KANBAN.SETTINGS.AUTOMATIONS.RULES.LOAD_ERROR')
    );
  } finally {
    automationRulesLoading.value = false;
  }
};

const blankCadenceStep = () => ({ delayHours: 0, actionType: '', note: '' });

const resetCadenceForm = () => {
  cadenceForm.name = '';
  cadenceForm.pauseOnIncomingMessage = true;
  cadenceForm.triggerType = 'manual';
  cadenceForm.triggerStageId = '';
  cadenceForm.steps.splice(0, cadenceForm.steps.length, blankCadenceStep());
};

const fetchAppointmentReminderRules = async () => {
  if (!isAdmin.value) return;
  appointmentReminderLoading.value = true;
  appointmentReminderError.value = '';
  try {
    const response = await KanbanBoardsAPI.getAppointmentReminderRules(
      boardId.value
    );
    appointmentReminderRules.value = camelcaseKeys(response.data || [], {
      deep: true,
    });
  } catch (error) {
    appointmentReminderError.value = getErrorMessage(
      error,
      t('KANBAN.SETTINGS.AUTOMATIONS.APPOINTMENT.LOAD_ERROR')
    );
  } finally {
    appointmentReminderLoading.value = false;
  }
};

const saveAppointmentReminderRule = async () => {
  if (
    appointmentReminderSaving.value ||
    !appointmentReminderForm.triggerStageId
  )
    return;
  const offsets = appointmentReminderOffsets.value;
  if (!offsets.length || !appointmentReminderForm.channels.length) return;

  appointmentReminderSaving.value = true;
  appointmentReminderError.value = '';
  try {
    const response = await KanbanBoardsAPI.createAppointmentReminderRule(
      boardId.value,
      {
        appointment_reminder_rule: {
          trigger_type: 'stage_entered',
          trigger_stage_id: Number(appointmentReminderForm.triggerStageId),
          field_key: appointmentReminderForm.fieldKey,
          offsets,
          channels: appointmentReminderForm.channels,
          opt_in_attribute_key: appointmentReminderForm.optInAttributeKey,
          message_templates: Object.fromEntries(
            offsets.map(offset => [
              String(offset),
              appointmentReminderForm.messageTemplates[offset]?.trim() ||
                defaultAppointmentReminderMessage,
            ])
          ),
          active: true,
        },
      }
    );
    appointmentReminderRules.value.push(
      camelcaseKeys(response.data || {}, { deep: true })
    );
    useAlert(t('KANBAN.SETTINGS.AUTOMATIONS.APPOINTMENT.SAVE_SUCCESS'));
  } catch (error) {
    appointmentReminderError.value = getErrorMessage(
      error,
      t('KANBAN.SETTINGS.AUTOMATIONS.APPOINTMENT.SAVE_ERROR')
    );
    useAlert(appointmentReminderError.value);
  } finally {
    appointmentReminderSaving.value = false;
  }
};

const deleteAppointmentReminderRule = async rule => {
  if (!rule?.id || appointmentReminderSaving.value) return;
  appointmentReminderSaving.value = true;
  try {
    await KanbanBoardsAPI.deleteAppointmentReminderRule(boardId.value, rule.id);
    appointmentReminderRules.value = appointmentReminderRules.value.filter(
      item => item.id !== rule.id
    );
    useAlert(t('KANBAN.SETTINGS.AUTOMATIONS.APPOINTMENT.DISABLE_SUCCESS'));
  } catch (error) {
    appointmentReminderError.value = getErrorMessage(
      error,
      t('KANBAN.SETTINGS.AUTOMATIONS.APPOINTMENT.DISABLE_ERROR')
    );
    useAlert(appointmentReminderError.value);
  } finally {
    appointmentReminderSaving.value = false;
  }
};

const fetchCadences = async () => {
  if (!isAdmin.value) return;

  cadencesLoading.value = true;
  cadenceError.value = '';
  try {
    const response = await KanbanBoardsAPI.getCadences(boardId.value);
    cadences.value = camelcaseKeys(response.data || [], { deep: true });
  } catch (error) {
    cadenceError.value = getErrorMessage(
      error,
      t('KANBAN.SETTINGS.AUTOMATIONS.CADENCES.LOAD_ERROR')
    );
  } finally {
    cadencesLoading.value = false;
  }
};

const saveCadence = async () => {
  if (!isAdmin.value || cadenceSaving.value || !cadenceForm.name.trim()) return;

  const steps = cadenceForm.steps
    .map(step => ({
      delay_hours: Number(step.delayHours) || 0,
      action_type: step.actionType.trim(),
      note: step.note.trim() || null,
    }))
    .filter(step => step.action_type);
  if (!steps.length) return;

  cadenceSaving.value = true;
  cadenceError.value = '';
  try {
    const response = await KanbanBoardsAPI.createCadence(boardId.value, {
      cadence: {
        name: cadenceForm.name.trim(),
        pause_on_incoming_message: cadenceForm.pauseOnIncomingMessage,
        trigger_type: cadenceForm.triggerType,
        trigger_stage_id: cadenceForm.triggerStageId
          ? Number(cadenceForm.triggerStageId)
          : null,
        steps,
      },
    });
    cadences.value.push(camelcaseKeys(response.data || {}, { deep: true }));
    resetCadenceForm();
    useAlert(t('KANBAN.SETTINGS.AUTOMATIONS.CADENCES.SAVE_SUCCESS'));
  } catch (error) {
    cadenceError.value = getErrorMessage(
      error,
      t('KANBAN.SETTINGS.AUTOMATIONS.CADENCES.SAVE_ERROR')
    );
    useAlert(cadenceError.value);
  } finally {
    cadenceSaving.value = false;
  }
};

const deleteCadence = async cadence => {
  if (!cadence?.id || cadenceSaving.value) return;

  cadenceSaving.value = true;
  cadenceError.value = '';
  try {
    await KanbanBoardsAPI.deleteCadence(boardId.value, cadence.id);
    cadences.value = cadences.value.filter(item => item.id !== cadence.id);
    useAlert(t('KANBAN.SETTINGS.AUTOMATIONS.CADENCES.DELETE_SUCCESS'));
  } catch (error) {
    cadenceError.value = getErrorMessage(
      error,
      t('KANBAN.SETTINGS.AUTOMATIONS.CADENCES.DELETE_ERROR')
    );
    useAlert(cadenceError.value);
  } finally {
    cadenceSaving.value = false;
  }
};

const automationActionParams = action => {
  switch (action.actionName) {
    case 'move_stage':
      return { stage_id: Number(action.stageId) };
    case 'assign_owner':
      return { owner_id: Number(action.ownerId) };
    case 'set_next_action':
      return {
        next_action_type: action.nextActionType,
        next_action_at: action.nextActionAt || null,
        next_action_note: action.nextActionNote || null,
      };
    case 'set_field':
      return { field_key: action.fieldKey, value: action.fieldValue };
    default:
      return {};
  }
};

const automationRulePayload = () => ({
  kanban_automation_rule: {
    name: automationRuleForm.name.trim(),
    description: automationRuleForm.description.trim() || null,
    event_name: automationRuleForm.eventName,
    active: automationRuleForm.active,
    conditions: {
      stage_ids: automationRuleForm.stageId
        ? [Number(automationRuleForm.stageId)]
        : [],
      owner_ids: automationRuleForm.ownerId
        ? [Number(automationRuleForm.ownerId)]
        : [],
      fields: automationRuleForm.fieldKey
        ? [
            {
              field_key: automationRuleForm.fieldKey,
              operator: automationRuleForm.fieldOperator,
              value: automationRuleForm.fieldValue,
            },
          ]
        : [],
    },
    actions: automationRuleForm.actions
      .filter(action => action.actionName)
      .map(action => ({
        action_name: action.actionName,
        action_params: automationActionParams(action),
      })),
  },
});

const saveAutomationRule = async () => {
  if (!automationRuleForm.name.trim() || automationRulesSaving.value) return;

  automationRulesSaving.value = true;
  automationRulesError.value = '';
  try {
    const response = selectedAutomationRuleId.value
      ? await KanbanBoardsAPI.updateAutomationRule(
          boardId.value,
          selectedAutomationRuleId.value,
          automationRulePayload()
        )
      : await KanbanBoardsAPI.createAutomationRule(
          boardId.value,
          automationRulePayload()
        );
    const savedRule = camelcaseKeys(response.data || {}, { deep: true });
    const index = automationRules.value.findIndex(
      rule => rule.id === savedRule.id
    );
    if (index >= 0) automationRules.value.splice(index, 1, savedRule);
    else automationRules.value.push(savedRule);
    applyAutomationRule(savedRule);
    useAlert(t('KANBAN.SETTINGS.AUTOMATIONS.RULES.SAVE_SUCCESS'));
  } catch (error) {
    automationRulesError.value = getErrorMessage(
      error,
      t('KANBAN.SETTINGS.AUTOMATIONS.RULES.SAVE_ERROR')
    );
    useAlert(automationRulesError.value);
  } finally {
    automationRulesSaving.value = false;
  }
};

const toggleAutomationRule = async rule => {
  try {
    const response = await KanbanBoardsAPI.updateAutomationRule(
      boardId.value,
      rule.id,
      { kanban_automation_rule: { active: !rule.active } }
    );
    Object.assign(rule, camelcaseKeys(response.data || {}, { deep: true }));
  } catch (error) {
    useAlert(
      getErrorMessage(error, t('KANBAN.SETTINGS.AUTOMATIONS.RULES.SAVE_ERROR'))
    );
  }
};

const deleteAutomationRule = async rule => {
  automationRulePendingDeletion.value = rule;
  showAutomationDeleteConfirmation.value = true;
};

const closeAutomationDeleteConfirmation = () => {
  if (automationRulesSaving.value) return;

  showAutomationDeleteConfirmation.value = false;
  automationRulePendingDeletion.value = null;
};

const confirmDeleteAutomationRule = async () => {
  const rule = automationRulePendingDeletion.value;
  if (!rule) return;

  try {
    await KanbanBoardsAPI.deleteAutomationRule(boardId.value, rule.id);
    automationRules.value = automationRules.value.filter(
      item => item.id !== rule.id
    );
    if (selectedAutomationRuleId.value === rule.id) resetAutomationRuleForm();
    useAlert(t('KANBAN.SETTINGS.AUTOMATIONS.RULES.DELETE_SUCCESS'));
    closeAutomationDeleteConfirmation();
  } catch (error) {
    useAlert(
      getErrorMessage(
        error,
        t('KANBAN.SETTINGS.AUTOMATIONS.RULES.DELETE_ERROR')
      )
    );
  }
};

const testAutomationRule = async rule => {
  if (!automationTestCardId.value) return;

  try {
    const response = await KanbanBoardsAPI.testAutomationRule(
      boardId.value,
      rule.id,
      Number(automationTestCardId.value)
    );
    automationTestResult.value = camelcaseKeys(response.data || {}, {
      deep: true,
    });
  } catch (error) {
    automationTestResult.value = {
      matches: false,
      message: getErrorMessage(
        error,
        t('KANBAN.SETTINGS.AUTOMATIONS.RULES.TEST_ERROR')
      ),
    };
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
        ...(stage.category === 'open'
          ? { probability: Number(stage.probability) || 0 }
          : {}),
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

const openDuplicateConfirmation = () => {
  showDuplicateConfirmation.value = true;
};

const closeDuplicateConfirmation = () => {
  showDuplicateConfirmation.value = false;
};

const duplicateBoard = async () => {
  if (isDuplicating.value || !isAdmin.value) return;

  isDuplicating.value = true;
  saveError.value = '';

  try {
    const response = await KanbanBoardsAPI.duplicateBoard(boardId.value);
    const duplicatedBoard = camelcaseKeys(response.data || {}, { deep: true });
    await store.dispatch('kanbanBoards/refreshBoards');
    closeDuplicateConfirmation();
    await router.replace({
      name: 'kanban_board_settings',
      params: {
        accountId: route.params.accountId,
        boardId: duplicatedBoard.id,
      },
    });
    useAlert(t('KANBAN.SETTINGS.DUPLICATE.SUCCESS'));
  } catch (error) {
    saveError.value = getErrorMessage(
      error,
      t('KANBAN.SETTINGS.DUPLICATE.ERROR')
    );
    useAlert(saveError.value);
  } finally {
    isDuplicating.value = false;
  }
};

onMounted(async () => {
  await fetchSettings();
  await fetchAutomationRules();
  await fetchCadences();
  await fetchAppointmentReminderRules();
  if (route.query?.section === 'fields') {
    activeSettingsSection.value = 'sales';
    openCustomFieldManager();
    if (route.query?.action === 'new-tab') openNewFieldSectionForm();
  }
});
</script>

<template>
  <main class="flex h-full min-h-0 w-full bg-n-surface-1 text-n-slate-12">
    <div class="flex w-full flex-col gap-4 overflow-y-auto p-4 lg:p-6">
      <header class="flex items-center justify-between gap-4">
        <div class="min-w-0">
          <h1 class="text-xl font-semibold text-n-slate-12">
            {{ t('KANBAN.SETTINGS.TITLE') }}
          </h1>
          <p class="mt-1 max-w-2xl text-sm text-n-slate-11">
            {{ t('KANBAN.SETTINGS.DESCRIPTION') }}
          </p>
        </div>
        <div class="flex flex-wrap items-center justify-end gap-2">
          <Button
            v-if="isAdmin"
            type="button"
            data-testid="kanban-settings-duplicate"
            icon="i-lucide-copy"
            :label="t('KANBAN.SETTINGS.DUPLICATE.ACTION')"
            color="slate"
            size="sm"
            @click="openDuplicateConfirmation"
          />
          <Button
            type="button"
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
        </div>
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
        role="alert"
      >
        {{ loadError || t('KANBAN.SETTINGS.ACCESS_DENIED') }}
      </div>

      <form
        v-else
        data-testid="kanban-settings-form"
        class="grid gap-4 lg:grid-cols-[11rem_minmax(0,1fr)] lg:items-start"
        @submit.prevent="saveSettings"
      >
        <nav
          class="grid min-w-0 gap-1 lg:sticky lg:top-0 lg:row-span-6"
          :aria-label="t('KANBAN.SETTINGS.TITLE')"
        >
          <button
            v-for="item in settingsNavigation"
            :key="item.key"
            type="button"
            class="flex min-h-10 items-center gap-2 rounded-md px-3 py-2 text-left text-sm font-medium transition-colors focus:outline-none focus:ring-2 focus:ring-n-brand/40"
            :class="
              activeSettingsSection === item.key
                ? 'bg-n-brand/10 text-n-brand'
                : 'text-n-slate-11 hover:bg-n-alpha-2 hover:text-n-slate-12'
            "
            :aria-current="
              activeSettingsSection === item.key ? 'page' : undefined
            "
            :data-testid="`kanban-settings-nav-${item.key}`"
            @click="activeSettingsSection = item.key"
          >
            <i
              class="size-4 shrink-0"
              :class="[item.icon]"
              aria-hidden="true"
            />
            <span class="truncate">{{ item.label }}</span>
          </button>
        </nav>

        <section
          v-show="activeSettingsSection === 'general'"
          class="grid gap-4 border-b border-n-weak pb-6 lg:col-start-2"
        >
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
              role="alert"
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
                  class="grid gap-3 rounded-md border border-n-weak bg-n-surface-2 px-3 py-3 lg:grid-cols-[minmax(10rem,1fr)_minmax(9rem,0.55fr)_minmax(8rem,0.4fr)_minmax(8rem,0.4fr)_auto] lg:items-end"
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
                  <label class="grid gap-1 text-xs text-n-slate-11">
                    {{ t('KANBAN.SETTINGS.STAGES.PROBABILITY') }}
                    <div class="relative">
                      <input
                        v-model.number="stage.probability"
                        data-testid="kanban-settings-stage-probability"
                        type="number"
                        min="0"
                        max="100"
                        class="h-9 w-full rounded-md border border-n-weak bg-n-surface-1 px-2 pr-7 text-sm text-n-slate-12 outline-none focus:border-n-brand disabled:cursor-not-allowed disabled:bg-n-alpha-1 disabled:text-n-slate-10"
                        :disabled="stage.category !== 'open'"
                      />
                      <span
                        class="pointer-events-none absolute inset-y-0 right-2 flex items-center text-xs text-n-slate-10"
                      >
                        {{ t('KANBAN.SETTINGS.STAGES.PERCENT') }}
                      </span>
                    </div>
                  </label>
                  <button
                    type="button"
                    data-testid="kanban-settings-save-stage-rules"
                    class="flex size-9 items-center justify-center rounded-md text-n-slate-11 outline-none hover:bg-n-alpha-2 hover:text-n-slate-12 focus:ring-2 focus:ring-n-brand/40 disabled:cursor-not-allowed disabled:opacity-50"
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

        <section
          v-show="activeSettingsSection === 'access'"
          class="grid gap-4 border-b border-n-weak pb-6 lg:col-start-2"
        >
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

        <section
          v-show="activeSettingsSection === 'access'"
          class="grid gap-4 border-b border-n-weak pb-6 lg:col-start-2"
        >
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

        <section
          v-show="activeSettingsSection === 'sales'"
          class="grid gap-4 border-b border-n-weak pb-6 lg:col-start-2"
        >
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
                class="inline-flex max-w-48 items-center gap-1 rounded-md border border-n-weak bg-n-surface-1 px-2 py-1 text-xs text-n-slate-11 outline-none hover:border-n-brand hover:text-n-slate-12 focus:ring-2 focus:ring-n-brand/40"
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
                class="mx-auto flex max-h-[88vh] w-full max-w-[78rem] flex-col overflow-hidden bg-n-background"
              >
                <header
                  class="flex items-center justify-between gap-4 border-b border-n-weak px-4 py-3"
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
                      class="flex size-9 items-center justify-center rounded-md text-n-slate-11 outline-none hover:bg-n-alpha-2 focus:ring-2 focus:ring-n-brand/40"
                      :aria-label="t('KANBAN.ACTIONS.CLOSE')"
                      @click="closeCustomFieldManager"
                    >
                      <i class="i-lucide-x size-4" />
                    </button>
                  </div>
                </header>
                <div
                  class="grid min-h-0 flex-1 overflow-auto p-4 lg:grid-cols-[15rem_minmax(0,1fr)] lg:gap-4"
                >
                  <aside
                    class="grid max-h-[calc(88vh-8rem)] content-start gap-1 overflow-y-auto border-b border-n-weak pb-3 lg:border-b-0 lg:border-r lg:pb-0 lg:pr-3"
                  >
                    <div class="mb-1 px-3">
                      <h4 class="mb-0 text-sm font-medium text-n-slate-12">
                        {{ t('KANBAN.SETTINGS.SALES.FIELD_PALETTE_TITLE') }}
                      </h4>
                      <p class="mb-0 mt-1 text-xs text-n-slate-10">
                        {{
                          t('KANBAN.SETTINGS.SALES.FIELD_PALETTE_DESCRIPTION')
                        }}
                      </p>
                    </div>
                    <button
                      v-for="definition in form.customFieldDefinitions"
                      :key="definition.clientId"
                      type="button"
                      :data-testid="`kanban-settings-field-list-item-${definition.key}`"
                      draggable="true"
                      class="flex min-w-0 cursor-grab items-center gap-2 rounded-md px-3 py-2 text-left text-sm outline-none active:cursor-grabbing focus:ring-2 focus:ring-inset focus:ring-n-brand/40"
                      :class="
                        selectedCustomFieldId === definition.clientId
                          ? 'bg-n-alpha-2 text-n-slate-12'
                          : 'text-n-slate-11 hover:bg-n-alpha-1'
                      "
                      @click="selectCustomField(definition)"
                      @dragstart="onCustomFieldDragStart($event, definition)"
                      @dragend="onCustomFieldDragEnd"
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
                        <div
                          v-for="(
                            section, sectionIndex
                          ) in customFieldLayoutSections"
                          :key="section.key"
                          class="inline-flex h-8 items-center gap-1 rounded-md border px-2 text-xs font-medium text-n-slate-12"
                          :class="
                            activeFieldSectionKey === section.key
                              ? 'border-n-brand bg-n-brand/10'
                              : 'border-n-weak bg-n-surface-1'
                          "
                          role="tab"
                          tabindex="0"
                          :aria-selected="activeFieldSectionKey === section.key"
                          :data-testid="`kanban-settings-section-tab-${section.key}`"
                          @click="activeFieldSectionKey = section.key"
                          @keydown.enter.prevent="
                            activeFieldSectionKey = section.key
                          "
                          @keydown.space.prevent="
                            activeFieldSectionKey = section.key
                          "
                        >
                          <input
                            v-if="!section.builtIn"
                            v-model="customSectionByKey(section.key).label"
                            :data-testid="`kanban-settings-section-label-${section.key}`"
                            class="w-24 min-w-0 border-0 bg-transparent text-xs outline-none"
                            @input="syncCustomFieldDefinitionsText"
                          />
                          <span v-else>{{ section.label }}</span>
                          <button
                            v-if="!section.builtIn"
                            type="button"
                            :data-testid="`kanban-settings-rename-section-${section.key}`"
                            class="flex size-5 items-center justify-center rounded text-n-slate-10 outline-none hover:bg-n-alpha-2 focus:ring-2 focus:ring-n-brand/40"
                            :aria-label="
                              t('KANBAN.SETTINGS.SALES.RENAME_FIELD_SECTION')
                            "
                            @click="
                              customSectionByKey(section.key).label =
                                section.label
                            "
                          >
                            <i class="i-lucide-pencil size-3" />
                          </button>
                          <button
                            v-if="!section.builtIn && sectionIndex > 0"
                            type="button"
                            :data-testid="`kanban-settings-move-section-${section.key}-up`"
                            class="flex size-5 items-center justify-center rounded text-n-slate-10 outline-none hover:bg-n-alpha-2 focus:ring-2 focus:ring-n-brand/40"
                            :aria-label="
                              t('KANBAN.SETTINGS.SALES.MOVE_FIELD_SECTION_UP')
                            "
                            @click="moveCustomFieldSection(section.key, -1)"
                          >
                            <i class="i-lucide-chevron-up size-3" />
                          </button>
                          <button
                            v-if="
                              !section.builtIn &&
                              sectionIndex <
                                customFieldLayoutSections.length - 1
                            "
                            type="button"
                            :data-testid="`kanban-settings-move-section-${section.key}-down`"
                            class="flex size-5 items-center justify-center rounded text-n-slate-10 outline-none hover:bg-n-alpha-2 focus:ring-2 focus:ring-n-brand/40"
                            :aria-label="
                              t('KANBAN.SETTINGS.SALES.MOVE_FIELD_SECTION_DOWN')
                            "
                            @click="moveCustomFieldSection(section.key, 1)"
                          >
                            <i class="i-lucide-chevron-down size-3" />
                          </button>
                          <button
                            v-if="!section.builtIn"
                            type="button"
                            :data-testid="`kanban-settings-remove-section-${section.key}`"
                            class="flex size-5 items-center justify-center rounded text-n-ruby-11 outline-none hover:bg-n-ruby-2 focus:ring-2 focus:ring-n-ruby-8"
                            :aria-label="
                              t('KANBAN.SETTINGS.SALES.REMOVE_FIELD_SECTION')
                            "
                            @click="openRemoveCustomFieldSection(section)"
                          >
                            <i class="i-lucide-trash-2 size-3" />
                          </button>
                        </div>
                        <button
                          type="button"
                          data-testid="kanban-settings-add-field-section"
                          class="flex size-8 items-center justify-center rounded-md border border-dashed border-n-weak text-n-slate-11 outline-none hover:border-n-brand hover:text-n-brand focus:ring-2 focus:ring-n-brand/40"
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

                      <details
                        data-testid="kanban-settings-field-groups"
                        class="rounded-md border border-n-weak bg-n-surface-1"
                      >
                        <summary
                          class="flex cursor-pointer list-none items-center justify-between gap-3 px-3 py-2 text-xs font-medium text-n-slate-12 outline-none focus:ring-2 focus:ring-inset focus:ring-n-brand/40"
                        >
                          <span class="flex items-center gap-2">
                            <i
                              class="i-lucide-layout-grid size-3.5 text-n-slate-10"
                            />
                            {{ t('KANBAN.SETTINGS.SALES.FIELD_GROUPS') }}
                            <span
                              class="rounded-full bg-n-alpha-2 px-1.5 py-0.5 text-[11px] font-normal text-n-slate-10"
                            >
                              {{
                                customFieldGroupsForSection(
                                  activeFieldSectionKey
                                ).length
                              }}
                            </span>
                          </span>
                          <span class="text-[11px] font-normal text-n-slate-10">
                            {{
                              t(
                                'KANBAN.SETTINGS.SALES.FIELD_GROUPS_DESCRIPTION'
                              )
                            }}
                          </span>
                        </summary>
                        <div class="grid gap-2 border-t border-n-weak p-3">
                          <div
                            class="flex min-w-0 flex-wrap items-center gap-1.5"
                          >
                            <input
                              v-model="newFieldGroupName"
                              data-testid="kanban-settings-new-field-group-name"
                              class="h-8 min-w-40 flex-1 rounded-md border border-n-weak bg-n-surface-1 px-2 text-xs text-n-slate-12 outline-none focus:border-n-brand"
                              :placeholder="
                                t('KANBAN.SETTINGS.SALES.FIELD_GROUP_NAME')
                              "
                              @keydown.enter.prevent="createCustomFieldGroup"
                            />
                            <select
                              v-model="newFieldGroupColor"
                              data-testid="kanban-settings-new-field-group-color"
                              class="h-8 max-w-28 rounded-md border border-n-weak bg-n-surface-1 px-2 text-xs text-n-slate-12 outline-none focus:border-n-brand"
                              :aria-label="
                                t('KANBAN.SETTINGS.SALES.FIELD_GROUP_COLOR')
                              "
                            >
                              <option
                                v-for="color in KANBAN_STAGE_COLOR_OPTIONS"
                                :key="color.value"
                                :value="color.value"
                              >
                                {{ color.value }}
                              </option>
                            </select>
                            <button
                              type="button"
                              data-testid="kanban-settings-add-field-group"
                              class="flex size-8 items-center justify-center rounded-md bg-n-brand text-white outline-none hover:bg-n-brand/90 focus:ring-2 focus:ring-n-brand/40 disabled:opacity-50"
                              :disabled="!newFieldGroupName.trim()"
                              :aria-label="
                                t('KANBAN.SETTINGS.SALES.ADD_FIELD_GROUP')
                              "
                              @click="createCustomFieldGroup"
                            >
                              <i class="i-lucide-plus size-4" />
                            </button>
                          </div>
                          <div class="grid gap-1.5 sm:grid-cols-2">
                            <div
                              v-for="group in customFieldGroupsForSection(
                                activeFieldSectionKey
                              )"
                              :key="group.key"
                              class="flex min-w-0 items-center gap-1.5 rounded-md border border-n-weak bg-n-surface-2 px-2 py-1.5"
                            >
                              <span
                                class="size-2.5 shrink-0 rounded-full"
                                :class="
                                  getKanbanStageColorOption(group.color)
                                    .swatchClass
                                "
                                aria-hidden="true"
                              />
                              <input
                                v-model="group.label"
                                class="min-w-0 flex-1 border-0 bg-transparent px-1 text-xs text-n-slate-12 outline-none"
                                :aria-label="group.label"
                                @input="syncCustomFieldDefinitionsText"
                              />
                              <span class="text-[11px] text-n-slate-10">
                                {{
                                  customFieldsForLayoutGroup(
                                    activeFieldSectionKey,
                                    group.key
                                  ).length
                                }}
                              </span>
                              <select
                                v-model="group.color"
                                class="h-6 max-w-16 border-0 bg-transparent text-[10px] text-n-slate-10 outline-none"
                                :aria-label="
                                  t('KANBAN.SETTINGS.SALES.FIELD_GROUP_COLOR')
                                "
                                @change="syncCustomFieldDefinitionsText"
                              >
                                <option
                                  v-for="color in KANBAN_STAGE_COLOR_OPTIONS"
                                  :key="color.value"
                                  :value="color.value"
                                >
                                  {{ color.value }}
                                </option>
                              </select>
                              <button
                                type="button"
                                class="flex size-6 items-center justify-center rounded text-n-ruby-11 outline-none hover:bg-n-ruby-2 focus:ring-2 focus:ring-n-ruby-8"
                                :aria-label="
                                  t('KANBAN.SETTINGS.SALES.REMOVE_FIELD_GROUP')
                                "
                                @click="
                                  removeCustomFieldGroup(
                                    activeFieldSectionKey,
                                    group.key
                                  )
                                "
                              >
                                <i class="i-lucide-x size-3" />
                              </button>
                            </div>
                          </div>
                          <p
                            v-if="
                              !customFieldGroupsForSection(
                                activeFieldSectionKey
                              ).length
                            "
                            class="m-0 text-xs text-n-slate-10"
                          >
                            {{ t('KANBAN.SETTINGS.SALES.NO_FIELD_GROUPS') }}
                          </p>
                        </div>
                      </details>

                      <div
                        v-if="showRemoveFieldSectionConfirmation"
                        class="grid gap-2 rounded-md border border-n-ruby-6 bg-n-ruby-2 p-3"
                      >
                        <p class="m-0 text-xs text-n-ruby-11">
                          {{
                            t(
                              'KANBAN.SETTINGS.SALES.REMOVE_FIELD_SECTION_WARNING'
                            )
                          }}
                        </p>
                        <div class="flex flex-wrap items-end gap-2">
                          <label
                            class="grid gap-1 text-xs font-medium text-n-slate-11"
                          >
                            {{
                              t(
                                'KANBAN.SETTINGS.SALES.FIELD_SECTION_DESTINATION'
                              )
                            }}
                            <select
                              v-model="sectionRemovalDestination"
                              data-testid="kanban-settings-section-destination"
                              class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-2 text-sm font-normal text-n-slate-12 outline-none focus:border-n-brand"
                            >
                              <option
                                v-for="destination in customFieldLayoutSections.filter(
                                  section =>
                                    section.key !== sectionPendingRemoval?.key
                                )"
                                :key="destination.key"
                                :value="destination.key"
                              >
                                {{ destination.label }}
                              </option>
                            </select>
                          </label>
                          <Button
                            type="button"
                            data-testid="kanban-settings-confirm-remove-section"
                            icon="i-lucide-check"
                            :label="
                              t(
                                'KANBAN.SETTINGS.SALES.CONFIRM_REMOVE_FIELD_SECTION'
                              )
                            "
                            color="blue"
                            size="sm"
                            @click="removeCustomFieldSection"
                          />
                        </div>
                      </div>

                      <div
                        v-for="section in customFieldLayoutSections.filter(
                          item => item.key === activeFieldSectionKey
                        )"
                        :key="section.key"
                        class="grid min-w-0 content-start gap-2"
                      >
                        <div class="flex items-center justify-between gap-2">
                          <h5 class="mb-0 text-xs font-medium text-n-slate-12">
                            {{ section.label }}
                          </h5>
                          <Button
                            type="button"
                            data-testid="kanban-settings-add-field-to-active-section"
                            icon="i-lucide-plus"
                            :label="
                              t('KANBAN.SETTINGS.SALES.ADD_FIELD_TO_SECTION')
                            "
                            color="slate"
                            size="xs"
                            @click="addCustomField"
                          />
                        </div>

                        <div
                          v-if="customFieldGroupsForSection(section.key).length"
                          class="grid gap-2 md:grid-cols-2"
                        >
                          <article
                            v-for="group in customFieldGroupsForSection(
                              section.key
                            )"
                            :key="group.key"
                            class="grid min-w-0 content-start gap-1.5 rounded-md border border-n-weak bg-n-surface-1 p-2"
                            @dragover.prevent
                            @drop="
                              moveCustomFieldToGroup(
                                section.key,
                                group.key,
                                $event
                              )
                            "
                          >
                            <div class="flex items-center gap-2 px-1">
                              <span
                                class="size-2.5 shrink-0 rounded-full"
                                :class="
                                  getKanbanStageColorOption(group.color)
                                    .swatchClass
                                "
                                aria-hidden="true"
                              />
                              <span
                                class="min-w-0 flex-1 truncate text-xs font-medium text-n-slate-12"
                              >
                                {{ group.label }}
                              </span>
                              <span class="text-[11px] text-n-slate-10">
                                {{
                                  customFieldsForLayoutGroup(
                                    section.key,
                                    group.key
                                  ).length
                                }}
                              </span>
                            </div>
                            <Draggable
                              :model-value="
                                customFieldsForLayoutGroup(
                                  section.key,
                                  group.key
                                )
                              "
                              item-key="clientId"
                              group="kanban-custom-field-layout"
                              :data-testid="`kanban-settings-field-group-dropzone-${group.key}`"
                              class="grid min-h-12 content-start gap-1 rounded border border-dashed border-n-weak p-1.5"
                              @change="
                                moveCustomFieldInGroup(
                                  section.key,
                                  group.key,
                                  $event
                                )
                              "
                            >
                              <template #item="{ element }">
                                <button
                                  type="button"
                                  class="flex min-w-0 cursor-grab items-center gap-2 rounded border border-n-weak bg-n-surface-2 px-2 py-1.5 text-left text-xs text-n-slate-12 outline-none focus:ring-2 focus:ring-inset focus:ring-n-brand/40"
                                  @click="selectCustomField(element)"
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
                                    !customFieldsForLayoutGroup(
                                      section.key,
                                      group.key
                                    ).length
                                  "
                                  class="m-0 py-2 text-center text-[11px] text-n-slate-10"
                                >
                                  {{ t('KANBAN.SETTINGS.SALES.EMPTY_TAB') }}
                                </p>
                              </template>
                            </Draggable>
                          </article>
                        </div>

                        <Draggable
                          :model-value="
                            customFieldsForLayoutSection(section.key).filter(
                              definition => !definition.layoutGroup
                            )
                          "
                          item-key="clientId"
                          group="kanban-custom-field-layout"
                          :data-section-key="section.key"
                          class="grid min-h-12 content-start gap-1 rounded-md border border-dashed border-n-weak bg-n-surface-2 p-1.5"
                          @dragover.prevent
                          @drop="onCustomFieldDrop(section.key, $event)"
                          @change="moveCustomFieldInLayout(section.key, $event)"
                        >
                          <template #item="{ element }">
                            <button
                              type="button"
                              class="flex min-w-0 cursor-grab items-center gap-2 rounded border border-n-weak bg-n-surface-1 px-2 py-1.5 text-left text-xs text-n-slate-12 outline-none focus:ring-2 focus:ring-inset focus:ring-n-brand/40"
                              @click="selectCustomField(element)"
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
                                !customFieldsForLayoutSection(
                                  section.key
                                ).filter(definition => !definition.layoutGroup)
                                  .length
                              "
                              class="m-0 py-2 text-center text-[11px] text-n-slate-10"
                            >
                              {{ t('KANBAN.SETTINGS.SALES.EMPTY_TAB') }}
                            </p>
                          </template>
                        </Draggable>
                      </div>
                    </section>

                    <article
                      v-if="selectedCustomField"
                      :key="selectedCustomField.clientId"
                      data-testid="kanban-settings-custom-field-row"
                      class="grid gap-3 rounded-md border border-n-weak bg-n-surface-2 p-3"
                    >
                      <div class="flex items-center justify-between gap-3">
                        <div class="min-w-0">
                          <p class="m-0 text-xs font-medium text-n-slate-10">
                            {{
                              t('KANBAN.SETTINGS.SALES.FIELD_BASIC_SETTINGS')
                            }}
                          </p>
                          <p class="m-0 truncate text-sm text-n-slate-12">
                            {{
                              selectedCustomField.label ||
                              t('KANBAN.SETTINGS.SALES.UNNAMED_FIELD')
                            }}
                          </p>
                        </div>
                        <button
                          type="button"
                          class="flex size-8 shrink-0 items-center justify-center rounded-md text-n-slate-10 hover:bg-n-alpha-2 hover:text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand/40"
                          :aria-label="
                            t('KANBAN.SETTINGS.SALES.REMOVE_CUSTOM_FIELD')
                          "
                          @click="
                            removeCustomFieldById(selectedCustomField.clientId)
                          "
                        >
                          <i class="i-lucide-trash-2 size-4" />
                        </button>
                      </div>

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
                          {{ t('KANBAN.SETTINGS.SALES.FIELD_GROUP') }}
                          <select
                            v-model="selectedCustomField.layoutGroup"
                            data-testid="kanban-settings-field-group"
                            class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm font-normal text-n-slate-12 outline-none focus:border-n-brand"
                            @change="syncCustomFieldDefinitionsText"
                          >
                            <option value="">
                              {{ t('KANBAN.SETTINGS.SALES.FIELD_GROUP_NONE') }}
                            </option>
                            <option
                              v-for="group in customFieldGroupsForSection(
                                selectedCustomField.layoutSection
                              )"
                              :key="group.key"
                              :value="group.key"
                            >
                              {{ group.label }}
                            </option>
                          </select>
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
                            class="flex size-9 shrink-0 items-center justify-center rounded-md border border-n-weak text-n-slate-11 outline-none hover:bg-n-alpha-2 focus:ring-2 focus:ring-n-brand/40"
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
                              class="flex size-4 items-center justify-center text-n-slate-10 outline-none hover:text-n-ruby-11 focus:ring-2 focus:ring-n-ruby-8"
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

                      <fieldset
                        data-testid="kanban-settings-required-stage-list"
                        class="grid gap-2 rounded-md border border-n-weak bg-n-surface-1 p-3"
                      >
                        <legend
                          class="px-1 text-xs font-medium text-n-slate-11"
                        >
                          {{ t('KANBAN.SETTINGS.SALES.REQUIRED_STAGES') }}
                        </legend>
                        <p class="m-0 text-xs text-n-slate-10">
                          {{ t('KANBAN.SETTINGS.SALES.REQUIRED_STAGES_HELP') }}
                        </p>
                        <div class="grid grid-cols-2 gap-2 md:grid-cols-3">
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
                        </div>
                      </fieldset>

                      <details
                        class="rounded-md border border-n-weak bg-n-surface-1"
                      >
                        <summary
                          class="flex cursor-pointer list-none flex-wrap items-center justify-between gap-x-3 gap-y-1 px-3 py-2 text-xs font-medium text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-inset focus:ring-n-brand/40"
                        >
                          <span>
                            {{
                              t('KANBAN.SETTINGS.SALES.FIELD_ADVANCED_SETTINGS')
                            }}
                          </span>
                          <span
                            class="text-[11px] font-normal text-n-slate-10 lg:text-right"
                          >
                            {{
                              t(
                                'KANBAN.SETTINGS.SALES.FIELD_ADVANCED_SETTINGS_DESCRIPTION'
                              )
                            }}
                          </span>
                        </summary>
                        <div class="grid gap-3 border-t border-n-weak p-3">
                          <div class="grid gap-3 md:grid-cols-4">
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
                                @change="
                                  updateCustomFieldSection(selectedCustomField)
                                "
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

                          <div class="grid gap-3 md:grid-cols-2">
                            <label
                              class="grid gap-1 text-xs font-medium text-n-slate-11"
                            >
                              {{ t('KANBAN.SETTINGS.SALES.CONDITION_FIELD') }}
                              <select
                                v-model="selectedCustomField.conditionFieldKey"
                                data-testid="kanban-settings-condition-field"
                                class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm font-normal text-n-slate-12 outline-none focus:border-n-brand"
                                @change="
                                  updateConditionField(selectedCustomField)
                                "
                              >
                                <option value="">
                                  {{
                                    t('KANBAN.SETTINGS.SALES.CONDITION_NONE')
                                  }}
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
                                  conditionValueOptions(selectedCustomField)
                                    .length
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
                                :type="
                                  conditionValueInputType(selectedCustomField)
                                "
                                :step="
                                  conditionValueInputType(
                                    selectedCustomField
                                  ) === 'number'
                                    ? 'any'
                                    : undefined
                                "
                                :disabled="
                                  !selectedCustomField.conditionFieldKey
                                "
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
                        </div>
                      </details>

                      <div
                        class="flex flex-wrap items-start justify-between gap-3"
                      >
                        <div class="flex flex-wrap items-center gap-4">
                          <div class="grid max-w-64 gap-1">
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
                            <span class="pl-6 text-xs text-n-slate-10">
                              {{ t('KANBAN.SETTINGS.SALES.SHOW_ON_CARD_HELP') }}
                            </span>
                          </div>
                          <div class="grid max-w-64 gap-1">
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
                            <span class="pl-6 text-xs text-n-slate-10">
                              {{
                                t('KANBAN.SETTINGS.SALES.IMPORTANT_FIELD_HELP')
                              }}
                            </span>
                          </div>
                        </div>
                      </div>

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
                        <label class="mt-1 grid gap-1 font-sans">
                          {{ t('KANBAN.SETTINGS.SALES.FORMULA_RESULT_TYPE') }}
                          <select
                            v-model="selectedCustomField.formulaResultType"
                            data-testid="kanban-settings-formula-result-type"
                            class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm font-normal text-n-slate-12 outline-none focus:border-n-brand"
                          >
                            <option value="number">
                              {{
                                t(
                                  'KANBAN.SETTINGS.SALES.FORMULA_RESULT_TYPES.NUMBER'
                                )
                              }}
                            </option>
                            <option value="date">
                              {{
                                t(
                                  'KANBAN.SETTINGS.SALES.FORMULA_RESULT_TYPES.DATE'
                                )
                              }}
                            </option>
                            <option value="datetime">
                              {{
                                t(
                                  'KANBAN.SETTINGS.SALES.FORMULA_RESULT_TYPES.DATETIME'
                                )
                              }}
                            </option>
                          </select>
                        </label>
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
                        <div
                          v-if="formulaPreviewCandidates.length"
                          data-testid="kanban-settings-formula-preview"
                          class="grid gap-2 rounded-md bg-n-surface-2 p-2"
                        >
                          <span class="text-xs font-medium text-n-slate-11">
                            {{ t('KANBAN.SETTINGS.SALES.FORMULA_PREVIEW') }}
                          </span>
                          <div class="flex flex-wrap gap-2">
                            <label
                              v-for="candidate in formulaPreviewCandidates"
                              :key="candidate.key"
                              class="grid min-w-32 gap-1 text-xs font-normal text-n-slate-11"
                            >
                              {{ candidate.label }}
                              <input
                                v-model="formulaPreviewValues[candidate.key]"
                                :data-testid="`kanban-settings-formula-preview-${candidate.key}`"
                                type="number"
                                class="h-8 rounded-md border border-n-weak bg-n-surface-1 px-2 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                              />
                            </label>
                          </div>
                          <span
                            data-testid="kanban-settings-formula-preview-result"
                            class="text-sm font-semibold text-n-slate-12"
                          >
                            {{
                              formulaPreviewResult ??
                              t(
                                'KANBAN.SETTINGS.SALES.FORMULA_PREVIEW_INCOMPLETE'
                              )
                            }}
                          </span>
                        </div>
                      </label>
                    </article>

                    <button
                      v-for="definition in form.customFieldDefinitions.filter(
                        item => item.clientId !== selectedCustomField?.clientId
                      )"
                      :key="`field-proxy-${definition.clientId}`"
                      type="button"
                      data-testid="kanban-settings-custom-field-row"
                      class="sr-only"
                      @click="selectedCustomFieldId = definition.clientId"
                    >
                      {{ definition.label }}
                    </button>

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
                  class="flex justify-end gap-2 border-t border-n-weak px-4 py-3"
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

          <div class="grid gap-2 rounded-lg border border-n-weak p-3">
            <h3 class="mb-0 text-sm font-medium text-n-slate-12">
              {{ t('KANBAN.SETTINGS.SALES.APPOINTMENT_REMINDERS') }}
            </h3>
            <p class="mb-0 text-sm text-n-slate-11">
              {{ t('KANBAN.SETTINGS.SALES.APPOINTMENT_REMINDERS_DESCRIPTION') }}
            </p>
            <label
              for="kanban-settings-appointment-reminder-hours"
              class="grid gap-1 text-sm font-medium text-n-slate-12 sm:grid-cols-[minmax(0,1fr)_12rem] sm:items-center sm:gap-3"
            >
              <span>{{
                t('KANBAN.SETTINGS.SALES.APPOINTMENT_REMINDER_LEAD_TIME')
              }}</span>
              <span class="flex items-center gap-2">
                <input
                  id="kanban-settings-appointment-reminder-hours"
                  v-model="form.appointmentReminderHours"
                  data-testid="kanban-settings-appointment-reminder-hours"
                  type="number"
                  min="0"
                  max="168"
                  :placeholder="
                    t(
                      'KANBAN.SETTINGS.SALES.APPOINTMENT_REMINDER_HOURS_PLACEHOLDER'
                    )
                  "
                  class="h-9 min-w-0 flex-1 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm font-normal text-n-slate-12 outline-none focus:border-n-brand"
                />
                <span class="text-xs font-normal text-n-slate-10">
                  {{
                    t('KANBAN.SETTINGS.SALES.APPOINTMENT_REMINDER_HOURS_SUFFIX')
                  }}
                </span>
              </span>
            </label>
          </div>
        </section>

        <section
          v-show="activeSettingsSection === 'automation'"
          class="grid gap-4 border-b border-n-weak pb-6 lg:col-start-2"
        >
          <div class="flex flex-wrap items-start justify-between gap-3">
            <div>
              <h2 class="text-base font-medium text-n-slate-12">
                {{ t('KANBAN.SETTINGS.AUTOMATIONS.TITLE') }}
              </h2>
              <p class="mt-1 max-w-2xl text-sm text-n-slate-11">
                {{ t('KANBAN.SETTINGS.AUTOMATIONS.DESCRIPTION') }}
              </p>
            </div>
            <Button
              type="button"
              data-testid="kanban-settings-new-automation-rule"
              icon="i-lucide-plus"
              :label="t('KANBAN.SETTINGS.AUTOMATIONS.RULES.NEW')"
              color="blue"
              size="sm"
              @click="resetAutomationRuleForm"
            />
          </div>

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

          <section
            data-testid="kanban-settings-appointment-reminders"
            class="grid gap-3 rounded-md border border-n-weak bg-n-surface-2 p-3"
          >
            <div>
              <h3 class="m-0 text-sm font-medium text-n-slate-12">
                {{ t('KANBAN.SETTINGS.AUTOMATIONS.APPOINTMENT.TITLE') }}
              </h3>
              <p class="m-0 mt-1 text-xs text-n-slate-11">
                {{ t('KANBAN.SETTINGS.AUTOMATIONS.APPOINTMENT.DESCRIPTION') }}
              </p>
            </div>
            <p
              v-if="appointmentReminderError"
              class="m-0 text-sm text-n-ruby-11"
              role="alert"
            >
              {{ appointmentReminderError }}
            </p>
            <div class="grid gap-2 md:grid-cols-2">
              <label class="grid gap-1 text-xs font-medium text-n-slate-11">
                {{ t('KANBAN.SETTINGS.AUTOMATIONS.APPOINTMENT.TRIGGER_STAGE') }}
                <select
                  v-model="appointmentReminderForm.triggerStageId"
                  data-testid="kanban-settings-appointment-stage"
                  class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-2 text-sm font-normal text-n-slate-12 outline-none focus:border-n-brand"
                >
                  <option value="">
                    {{
                      t('KANBAN.SETTINGS.AUTOMATIONS.APPOINTMENT.SELECT_STAGE')
                    }}
                  </option>
                  <option
                    v-for="stage in stages"
                    :key="stage.id"
                    :value="String(stage.id)"
                  >
                    {{ stage.name }}
                  </option>
                </select>
              </label>
              <label class="grid gap-1 text-xs font-medium text-n-slate-11">
                {{ t('KANBAN.SETTINGS.AUTOMATIONS.APPOINTMENT.DATE_FIELD') }}
                <select
                  v-model="appointmentReminderForm.fieldKey"
                  data-testid="kanban-settings-appointment-field"
                  class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-2 text-sm font-normal text-n-slate-12 outline-none focus:border-n-brand"
                >
                  <option value="system_starts_at">
                    {{
                      t('KANBAN.SETTINGS.AUTOMATIONS.APPOINTMENT.SYSTEM_DATE')
                    }}
                  </option>
                  <option
                    v-for="field in form.customFieldDefinitions.filter(item =>
                      ['date', 'datetime'].includes(item.fieldType)
                    )"
                    :key="field.key"
                    :value="field.key"
                  >
                    {{ field.label || field.key }}
                  </option>
                </select>
              </label>
            </div>
            <div class="grid gap-2 md:grid-cols-[minmax(0,1fr)_auto]">
              <label class="grid gap-1 text-xs font-medium text-n-slate-11">
                {{ t('KANBAN.SETTINGS.AUTOMATIONS.APPOINTMENT.ADVANCE_HOURS') }}
                <input
                  v-model="appointmentReminderForm.offsets"
                  data-testid="kanban-settings-appointment-offsets"
                  type="text"
                  :placeholder="
                    t(
                      'KANBAN.SETTINGS.AUTOMATIONS.APPOINTMENT.PLACEHOLDER_HOURS'
                    )
                  "
                  class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm font-normal text-n-slate-12 outline-none focus:border-n-brand"
                />
              </label>
              <div class="flex items-end gap-3 pb-1 text-xs text-n-slate-11">
                <label class="flex items-center gap-2">
                  <input
                    v-model="appointmentReminderForm.channels"
                    value="whatsapp"
                    type="checkbox"
                    class="size-4"
                  />
                  {{ t('KANBAN.SETTINGS.AUTOMATIONS.BIRTHDAY.WHATSAPP') }}
                </label>
                <label class="flex items-center gap-2">
                  <input
                    v-model="appointmentReminderForm.channels"
                    value="email"
                    type="checkbox"
                    class="size-4"
                  />
                  {{ t('KANBAN.SETTINGS.AUTOMATIONS.BIRTHDAY.EMAIL') }}
                </label>
              </div>
            </div>
            <label class="grid gap-1 text-xs font-medium text-n-slate-11">
              {{ t('KANBAN.SETTINGS.AUTOMATIONS.APPOINTMENT.OPT_IN') }}
              <input
                v-model="appointmentReminderForm.optInAttributeKey"
                data-testid="kanban-settings-appointment-opt-in"
                type="text"
                class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm font-normal text-n-slate-12 outline-none focus:border-n-brand"
              />
            </label>
            <div
              v-if="appointmentReminderOffsets.length"
              class="grid gap-2 rounded-md border border-n-weak bg-n-surface-1 p-3"
            >
              <p class="m-0 text-xs font-medium text-n-slate-11">
                {{
                  t('KANBAN.SETTINGS.AUTOMATIONS.APPOINTMENT.MESSAGES_TITLE')
                }}
              </p>
              <label
                v-for="offset in appointmentReminderOffsets"
                :key="offset"
                class="grid gap-1 text-xs font-medium text-n-slate-11"
              >
                <span>
                  {{
                    t('KANBAN.SETTINGS.AUTOMATIONS.APPOINTMENT.MESSAGE_FOR', {
                      hours: offset,
                    })
                  }}
                </span>
                <textarea
                  :data-testid="`kanban-settings-appointment-message-${offset}`"
                  :value="
                    appointmentReminderForm.messageTemplates[offset] ||
                    defaultAppointmentReminderMessage
                  "
                  rows="2"
                  class="resize-y rounded-md border border-n-weak bg-n-surface-2 px-3 py-2 text-sm font-normal text-n-slate-12 outline-none focus:border-n-brand"
                  @input="
                    appointmentReminderForm.messageTemplates[offset] =
                      $event.target.value
                  "
                />
              </label>
            </div>
            <div class="flex justify-end">
              <Button
                type="button"
                data-testid="kanban-settings-save-appointment-reminder"
                icon="i-lucide-calendar-clock"
                :label="t('KANBAN.SETTINGS.AUTOMATIONS.APPOINTMENT.ACTIVATE')"
                color="blue"
                size="sm"
                :is-loading="
                  appointmentReminderSaving || appointmentReminderLoading
                "
                @click="saveAppointmentReminderRule"
              />
            </div>
            <div v-if="appointmentReminderRules.length" class="grid gap-2">
              <article
                v-for="rule in appointmentReminderRules"
                :key="rule.id"
                class="flex items-center justify-between gap-3 rounded-md border border-n-weak bg-n-surface-1 px-3 py-2"
              >
                <p class="m-0 text-xs text-n-slate-11">
                  {{ rule.offsets.join(', ')
                  }}{{
                    t('KANBAN.SETTINGS.AUTOMATIONS.APPOINTMENT.HOURS_BEFORE')
                  }}
                  {{ rule.channels.join(', ') }}
                </p>
                <Button
                  type="button"
                  icon="i-lucide-trash-2"
                  color="ruby"
                  size="xs"
                  :aria-label="
                    t('KANBAN.SETTINGS.AUTOMATIONS.APPOINTMENT.DISABLE')
                  "
                  @click="deleteAppointmentReminderRule(rule)"
                />
              </article>
            </div>
          </section>

          <section
            data-testid="kanban-settings-birthday-automation"
            class="grid gap-3 rounded-md border border-n-weak bg-n-surface-2 p-3"
          >
            <div class="flex flex-wrap items-start justify-between gap-3">
              <div>
                <h3 class="m-0 text-sm font-medium text-n-slate-12">
                  {{ t('KANBAN.SETTINGS.AUTOMATIONS.BIRTHDAY.TITLE') }}
                </h3>
                <p class="m-0 mt-1 max-w-2xl text-xs text-n-slate-11">
                  {{ t('KANBAN.SETTINGS.AUTOMATIONS.BIRTHDAY.DESCRIPTION') }}
                </p>
              </div>
              <span
                v-if="isLoadingBirthdayAutomation"
                class="text-xs text-n-slate-10"
              >
                {{ t('KANBAN.SETTINGS.AUTOMATIONS.BIRTHDAY.LOADING') }}
              </span>
            </div>

            <p
              v-if="birthdayAutomationError"
              class="m-0 text-sm text-n-ruby-11"
              role="alert"
            >
              {{ birthdayAutomationError }}
            </p>

            <label class="flex items-start gap-2 text-sm text-n-slate-12">
              <input
                v-model="birthdayAutomation.active"
                data-testid="kanban-settings-birthday-active"
                type="checkbox"
                class="mt-0.5 size-4 rounded border-n-weak text-n-brand focus:ring-n-brand"
              />
              <span>
                {{ t('KANBAN.SETTINGS.AUTOMATIONS.BIRTHDAY.ACTIVE') }}
              </span>
            </label>

            <fieldset class="grid gap-2">
              <legend class="text-xs font-medium text-n-slate-11">
                {{ t('KANBAN.SETTINGS.AUTOMATIONS.BIRTHDAY.CHANNELS') }}
              </legend>
              <div class="flex flex-wrap gap-x-4 gap-y-2">
                <label class="flex items-center gap-2 text-sm text-n-slate-12">
                  <input
                    v-model="birthdayAutomation.deliveryChannels"
                    type="checkbox"
                    value="whatsapp"
                    data-testid="kanban-settings-birthday-whatsapp"
                    class="size-4 rounded border-n-weak text-n-brand focus:ring-n-brand"
                  />
                  {{ t('KANBAN.SETTINGS.AUTOMATIONS.BIRTHDAY.WHATSAPP') }}
                </label>
                <label class="flex items-center gap-2 text-sm text-n-slate-12">
                  <input
                    v-model="birthdayAutomation.deliveryChannels"
                    type="checkbox"
                    value="email"
                    data-testid="kanban-settings-birthday-email"
                    class="size-4 rounded border-n-weak text-n-brand focus:ring-n-brand"
                  />
                  {{ t('KANBAN.SETTINGS.AUTOMATIONS.BIRTHDAY.EMAIL') }}
                </label>
              </div>
            </fieldset>

            <div class="grid gap-3 md:grid-cols-4">
              <label class="grid gap-1 text-xs font-medium text-n-slate-11">
                {{ t('KANBAN.SETTINGS.AUTOMATIONS.BIRTHDAY.DAYS_BEFORE') }}
                <input
                  v-model="birthdayAutomation.daysBefore"
                  data-testid="kanban-settings-birthday-days-before"
                  type="number"
                  min="0"
                  max="30"
                  class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm font-normal text-n-slate-12 outline-none focus:border-n-brand"
                />
              </label>
              <label class="grid gap-1 text-xs font-medium text-n-slate-11">
                {{ t('KANBAN.SETTINGS.AUTOMATIONS.BIRTHDAY.OPT_IN_KEY') }}
                <input
                  v-model="birthdayAutomation.optInAttributeKey"
                  data-testid="kanban-settings-birthday-opt-in-key"
                  type="text"
                  class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm font-normal text-n-slate-12 outline-none focus:border-n-brand"
                />
              </label>
              <label class="grid gap-1 text-xs font-medium text-n-slate-11">
                {{ t('KANBAN.SETTINGS.AUTOMATIONS.BIRTHDAY.MESSAGE_LOCALE') }}
                <select
                  v-model="birthdayAutomation.messageLocale"
                  data-testid="kanban-settings-birthday-message-locale"
                  class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm font-normal text-n-slate-12 outline-none focus:border-n-brand"
                >
                  <option value="pt_BR">
                    {{ t('KANBAN.SETTINGS.AUTOMATIONS.BIRTHDAY.PT_BR') }}
                  </option>
                  <option value="pt_PT">
                    {{ t('KANBAN.SETTINGS.AUTOMATIONS.BIRTHDAY.PT_PT') }}
                  </option>
                </select>
              </label>
              <label class="grid gap-1 text-xs font-medium text-n-slate-11">
                {{ t('KANBAN.SETTINGS.AUTOMATIONS.BIRTHDAY.SEND_TIME') }}
                <input
                  v-model="birthdayAutomation.sendTime"
                  data-testid="kanban-settings-birthday-send-time"
                  type="time"
                  class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm font-normal text-n-slate-12 outline-none focus:border-n-brand"
                />
              </label>
            </div>

            <div class="grid gap-3 md:grid-cols-2">
              <label class="grid gap-1 text-xs font-medium text-n-slate-11">
                {{ t('KANBAN.SETTINGS.AUTOMATIONS.BIRTHDAY.TIMEZONE') }}
                <input
                  v-model="birthdayAutomation.timezone"
                  data-testid="kanban-settings-birthday-timezone"
                  type="text"
                  :placeholder="birthdayAutomation.timezoneName"
                  class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm font-normal text-n-slate-12 outline-none focus:border-n-brand"
                />
              </label>
              <p class="m-0 self-end text-xs text-n-slate-10">
                {{ t('KANBAN.SETTINGS.AUTOMATIONS.BIRTHDAY.OPT_IN_HELP') }}
              </p>
            </div>

            <label class="grid gap-1 text-xs font-medium text-n-slate-11">
              {{ t('KANBAN.SETTINGS.AUTOMATIONS.BIRTHDAY.MESSAGE') }}
              <textarea
                v-model="birthdayAutomation.messageTemplate"
                data-testid="kanban-settings-birthday-message"
                rows="2"
                class="resize-y rounded-md border border-n-weak bg-n-surface-1 px-3 py-2 text-sm font-normal text-n-slate-12 outline-none focus:border-n-brand"
              />
            </label>

            <div class="flex justify-end">
              <Button
                type="button"
                data-testid="kanban-settings-save-birthday"
                icon="i-lucide-save"
                :label="t('KANBAN.SETTINGS.AUTOMATIONS.BIRTHDAY.SAVE')"
                color="blue"
                size="sm"
                :is-loading="isSavingBirthdayAutomation"
                @click="saveBirthdayAutomation"
              />
            </div>
          </section>

          <section
            data-testid="kanban-settings-cadences"
            class="grid gap-3 rounded-md border border-n-weak bg-n-surface-2 p-3"
          >
            <div class="flex flex-wrap items-start justify-between gap-3">
              <div>
                <h3 class="m-0 text-sm font-medium text-n-slate-12">
                  {{ t('KANBAN.SETTINGS.AUTOMATIONS.CADENCES.TITLE') }}
                </h3>
                <p class="m-0 mt-1 text-xs text-n-slate-11">
                  {{ t('KANBAN.SETTINGS.AUTOMATIONS.CADENCES.DESCRIPTION') }}
                </p>
              </div>
              <span v-if="cadencesLoading" class="text-xs text-n-slate-10">
                {{ t('KANBAN.SETTINGS.AUTOMATIONS.CADENCES.LOADING') }}
              </span>
            </div>

            <p
              v-if="cadenceError"
              data-testid="kanban-settings-cadence-error"
              class="m-0 text-sm text-n-ruby-11"
              role="alert"
            >
              {{ cadenceError }}
            </p>

            <div class="grid gap-2 md:grid-cols-[minmax(0,1fr)_auto]">
              <input
                v-model="cadenceForm.name"
                data-testid="kanban-settings-cadence-name"
                type="text"
                :placeholder="
                  t('KANBAN.SETTINGS.AUTOMATIONS.CADENCES.NAME_PLACEHOLDER')
                "
                class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
              />
              <select
                v-model="cadenceForm.triggerType"
                data-testid="kanban-settings-cadence-trigger"
                class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-2 text-sm text-n-slate-12 outline-none focus:border-n-brand"
              >
                <option value="manual">
                  {{ t('KANBAN.SETTINGS.AUTOMATIONS.CADENCES.TRIGGER_MANUAL') }}
                </option>
                <option value="stage_entered">
                  {{ t('KANBAN.SETTINGS.AUTOMATIONS.CADENCES.TRIGGER_STAGE') }}
                </option>
              </select>
              <select
                v-if="cadenceForm.triggerType === 'stage_entered'"
                v-model="cadenceForm.triggerStageId"
                data-testid="kanban-settings-cadence-trigger-stage"
                class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-2 text-sm text-n-slate-12 outline-none focus:border-n-brand"
              >
                <option value="">
                  {{ t('KANBAN.SETTINGS.AUTOMATIONS.CADENCES.SELECT_STAGE') }}
                </option>
                <option
                  v-for="stage in stages"
                  :key="stage.id"
                  :value="String(stage.id)"
                >
                  {{ stage.name }}
                </option>
              </select>
              <label class="flex items-center gap-2 text-xs text-n-slate-11">
                <input
                  v-model="cadenceForm.pauseOnIncomingMessage"
                  type="checkbox"
                  class="size-4 rounded border-n-weak text-n-brand focus:ring-n-brand"
                />
                {{
                  t('KANBAN.SETTINGS.AUTOMATIONS.CADENCES.PAUSE_ON_INCOMING')
                }}
              </label>
            </div>

            <div class="grid gap-2">
              <div class="flex items-center justify-between gap-2">
                <span class="text-xs font-medium text-n-slate-11">
                  {{ t('KANBAN.SETTINGS.AUTOMATIONS.CADENCES.STEPS') }}
                </span>
                <Button
                  type="button"
                  icon="i-lucide-plus"
                  :label="t('KANBAN.SETTINGS.AUTOMATIONS.CADENCES.ADD_STEP')"
                  color="slate"
                  size="xs"
                  @click="cadenceForm.steps.push(blankCadenceStep())"
                />
              </div>
              <div
                v-for="(step, stepIndex) in cadenceForm.steps"
                :key="stepIndex"
                class="grid gap-2 md:grid-cols-[6rem_minmax(0,1fr)_minmax(0,1fr)_2rem]"
              >
                <input
                  v-model="step.delayHours"
                  type="number"
                  min="0"
                  step="1"
                  :aria-label="
                    t('KANBAN.SETTINGS.AUTOMATIONS.CADENCES.DELAY_HOURS')
                  "
                  class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-2 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                />
                <input
                  v-model="step.actionType"
                  :data-testid="`kanban-settings-cadence-action-${stepIndex}`"
                  :placeholder="
                    t('KANBAN.SETTINGS.AUTOMATIONS.CADENCES.ACTION_PLACEHOLDER')
                  "
                  class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                />
                <input
                  v-model="step.note"
                  :data-testid="`kanban-settings-cadence-note-${stepIndex}`"
                  :placeholder="
                    t('KANBAN.SETTINGS.AUTOMATIONS.CADENCES.NOTE_PLACEHOLDER')
                  "
                  class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                />
                <Button
                  v-if="cadenceForm.steps.length > 1"
                  type="button"
                  icon="i-lucide-trash-2"
                  color="ruby"
                  size="xs"
                  :aria-label="
                    t('KANBAN.SETTINGS.AUTOMATIONS.CADENCES.REMOVE_STEP')
                  "
                  @click="cadenceForm.steps.splice(stepIndex, 1)"
                />
              </div>
            </div>

            <div class="flex justify-end">
              <Button
                type="button"
                data-testid="kanban-settings-save-cadence"
                icon="i-lucide-save"
                :label="t('KANBAN.SETTINGS.AUTOMATIONS.CADENCES.SAVE')"
                color="blue"
                size="sm"
                :is-loading="cadenceSaving"
                @click="saveCadence"
              />
            </div>

            <div v-if="cadences.length" class="grid gap-2">
              <article
                v-for="cadence in cadences"
                :key="cadence.id"
                class="flex items-center justify-between gap-3 rounded-md border border-n-weak bg-n-surface-1 px-3 py-2"
              >
                <div class="min-w-0">
                  <p class="m-0 truncate text-sm font-medium text-n-slate-12">
                    {{ cadence.name }}
                  </p>
                  <p class="m-0 text-xs text-n-slate-10">
                    {{ cadence.steps?.length || 0 }}
                    {{ t('KANBAN.SETTINGS.AUTOMATIONS.CADENCES.STEP_COUNT') }}
                  </p>
                </div>
                <Button
                  type="button"
                  icon="i-lucide-trash-2"
                  color="ruby"
                  size="xs"
                  :aria-label="t('KANBAN.SETTINGS.AUTOMATIONS.CADENCES.DELETE')"
                  @click="deleteCadence(cadence)"
                />
              </article>
            </div>
          </section>

          <p
            v-if="automationRulesError"
            data-testid="kanban-settings-automation-error"
            class="m-0 text-sm text-n-ruby-11"
            role="alert"
          >
            {{ automationRulesError }}
          </p>

          <div
            class="grid gap-3 rounded-md border border-n-weak bg-n-surface-2 p-3"
          >
            <div class="flex items-center justify-between gap-2">
              <h3 class="m-0 text-sm font-medium text-n-slate-12">
                {{
                  selectedAutomationRuleId
                    ? t('KANBAN.SETTINGS.AUTOMATIONS.RULES.EDIT_TITLE')
                    : t('KANBAN.SETTINGS.AUTOMATIONS.RULES.NEW_TITLE')
                }}
              </h3>
              <Button
                v-if="selectedAutomationRuleId"
                type="button"
                data-testid="kanban-settings-cancel-automation-rule"
                :label="t('KANBAN.ACTIONS.CANCEL')"
                color="slate"
                size="sm"
                @click="resetAutomationRuleForm"
              />
            </div>

            <div class="grid gap-3 md:grid-cols-2">
              <label class="grid gap-1 text-xs font-medium text-n-slate-11">
                {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.NAME') }}
                <input
                  v-model="automationRuleForm.name"
                  data-testid="kanban-settings-automation-name"
                  type="text"
                  class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm font-normal text-n-slate-12 outline-none focus:border-n-brand"
                />
              </label>
              <label class="grid gap-1 text-xs font-medium text-n-slate-11">
                {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.EVENT') }}
                <select
                  v-model="automationRuleForm.eventName"
                  data-testid="kanban-settings-automation-event"
                  class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm font-normal text-n-slate-12 outline-none focus:border-n-brand"
                >
                  <option
                    v-for="option in automationEventOptions"
                    :key="option.value"
                    :value="option.value"
                  >
                    {{ option.label }}
                  </option>
                </select>
              </label>
            </div>

            <label class="grid gap-1 text-xs font-medium text-n-slate-11">
              {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.DESCRIPTION') }}
              <input
                v-model="automationRuleForm.description"
                data-testid="kanban-settings-automation-description"
                type="text"
                class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm font-normal text-n-slate-12 outline-none focus:border-n-brand"
              />
            </label>

            <div class="grid gap-2">
              <h4 class="m-0 text-xs font-medium text-n-slate-11">
                {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.CONDITIONS') }}
              </h4>
              <div class="grid gap-2 md:grid-cols-3">
                <select
                  v-model="automationRuleForm.stageId"
                  data-testid="kanban-settings-automation-stage"
                  class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                >
                  <option value="">
                    {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.ANY_STAGE') }}
                  </option>
                  <option
                    v-for="stage in stages"
                    :key="stage.id"
                    :value="stage.id"
                  >
                    {{ stage.name }}
                  </option>
                </select>
                <select
                  v-model="automationRuleForm.ownerId"
                  data-testid="kanban-settings-automation-owner"
                  class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                >
                  <option value="">
                    {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.ANY_OWNER') }}
                  </option>
                  <option
                    v-for="agent in agentOptions"
                    :key="agent.value"
                    :value="agent.value"
                  >
                    {{ agent.label }}
                  </option>
                </select>
                <select
                  v-model="automationRuleForm.fieldKey"
                  data-testid="kanban-settings-automation-field"
                  class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                >
                  <option value="">
                    {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.ANY_FIELD') }}
                  </option>
                  <option
                    v-for="field in automationFieldOptions"
                    :key="field.key"
                    :value="field.key"
                  >
                    {{ field.label }}
                  </option>
                </select>
              </div>
              <div
                v-if="automationRuleForm.fieldKey"
                class="grid gap-2 md:grid-cols-[10rem_minmax(0,1fr)]"
              >
                <select
                  v-model="automationRuleForm.fieldOperator"
                  data-testid="kanban-settings-automation-operator"
                  class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                >
                  <option value="equals">
                    {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.EQUALS') }}
                  </option>
                  <option value="not_equals">
                    {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.NOT_EQUALS') }}
                  </option>
                  <option value="contains">
                    {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.CONTAINS') }}
                  </option>
                  <option value="exists">
                    {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.EXISTS') }}
                  </option>
                  <option value="greater_than">
                    {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.GREATER_THAN') }}
                  </option>
                  <option value="less_than">
                    {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.LESS_THAN') }}
                  </option>
                </select>
                <input
                  v-model="automationRuleForm.fieldValue"
                  data-testid="kanban-settings-automation-value"
                  type="text"
                  :placeholder="t('KANBAN.SETTINGS.AUTOMATIONS.RULES.VALUE')"
                  class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                />
              </div>
            </div>

            <div class="grid gap-2">
              <div class="flex items-center justify-between gap-2">
                <h4 class="m-0 text-xs font-medium text-n-slate-11">
                  {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.ACTIONS') }}
                </h4>
                <Button
                  type="button"
                  data-testid="kanban-settings-add-automation-action"
                  icon="i-lucide-plus"
                  :label="t('KANBAN.SETTINGS.AUTOMATIONS.RULES.ADD_ACTION')"
                  color="slate"
                  size="xs"
                  @click="
                    automationRuleForm.actions.push(blankAutomationAction())
                  "
                />
              </div>
              <div
                v-for="(action, actionIndex) in automationRuleForm.actions"
                :key="actionIndex"
                class="grid gap-2 rounded-md border border-n-weak bg-n-surface-1 p-2 md:grid-cols-[minmax(0,1fr)_2rem]"
              >
                <div class="grid gap-2 md:grid-cols-2">
                  <select
                    v-model="action.actionName"
                    :data-testid="`kanban-settings-automation-action-${actionIndex}`"
                    class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                  >
                    <option
                      v-for="option in automationActionOptions"
                      :key="option.value"
                      :value="option.value"
                    >
                      {{ option.label }}
                    </option>
                  </select>
                  <select
                    v-if="action.actionName === 'move_stage'"
                    v-model="action.stageId"
                    class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                  >
                    <option value="">
                      {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.SELECT_STAGE') }}
                    </option>
                    <option
                      v-for="stage in stages"
                      :key="stage.id"
                      :value="stage.id"
                    >
                      {{ stage.name }}
                    </option>
                  </select>
                  <select
                    v-else-if="action.actionName === 'assign_owner'"
                    v-model="action.ownerId"
                    class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                  >
                    <option value="">
                      {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.SELECT_OWNER') }}
                    </option>
                    <option
                      v-for="agent in agentOptions"
                      :key="agent.value"
                      :value="agent.value"
                    >
                      {{ agent.label }}
                    </option>
                  </select>
                  <select
                    v-else-if="action.actionName === 'set_field'"
                    v-model="action.fieldKey"
                    class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                  >
                    <option value="">
                      {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.SELECT_FIELD') }}
                    </option>
                    <option
                      v-for="field in form.customFieldDefinitions"
                      :key="field.key"
                      :value="field.key"
                    >
                      {{ field.label || field.key }}
                    </option>
                  </select>
                  <input
                    v-if="action.actionName === 'set_field'"
                    v-model="action.fieldValue"
                    type="text"
                    :placeholder="t('KANBAN.SETTINGS.AUTOMATIONS.RULES.VALUE')"
                    class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                  />
                  <select
                    v-else-if="action.actionName === 'set_next_action'"
                    v-model="action.nextActionType"
                    class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                  >
                    <option value="">
                      {{
                        t(
                          'KANBAN.SETTINGS.AUTOMATIONS.RULES.SELECT_NEXT_ACTION'
                        )
                      }}
                    </option>
                    <option
                      v-for="type in linesFromText(form.nextActionTypesText)"
                      :key="type"
                      :value="type"
                    >
                      {{ type }}
                    </option>
                  </select>
                  <input
                    v-if="action.actionName === 'set_next_action'"
                    v-model="action.nextActionAt"
                    type="datetime-local"
                    class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                  />
                  <input
                    v-if="action.actionName === 'set_next_action'"
                    v-model="action.nextActionNote"
                    type="text"
                    :placeholder="t('KANBAN.SETTINGS.AUTOMATIONS.RULES.NOTE')"
                    class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand md:col-span-2"
                  />
                </div>
                <Button
                  v-if="automationRuleForm.actions.length > 1"
                  type="button"
                  icon="i-lucide-trash-2"
                  color="ruby"
                  size="xs"
                  :aria-label="
                    t('KANBAN.SETTINGS.AUTOMATIONS.RULES.REMOVE_ACTION')
                  "
                  :title="t('KANBAN.SETTINGS.AUTOMATIONS.RULES.REMOVE_ACTION')"
                  @click="automationRuleForm.actions.splice(actionIndex, 1)"
                />
              </div>
            </div>

            <div class="flex flex-wrap items-center justify-between gap-2">
              <label class="flex items-center gap-2 text-sm text-n-slate-12">
                <input
                  v-model="automationRuleForm.active"
                  type="checkbox"
                  class="size-4 rounded border-n-weak text-n-brand focus:ring-n-brand"
                />
                {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.ACTIVE') }}
              </label>
              <Button
                type="button"
                data-testid="kanban-settings-save-automation-rule"
                icon="i-lucide-save"
                :label="t('KANBAN.SETTINGS.AUTOMATIONS.RULES.SAVE')"
                color="blue"
                size="sm"
                :is-loading="automationRulesSaving"
                @click="saveAutomationRule"
              />
            </div>
          </div>

          <div class="grid gap-2">
            <div class="flex items-center justify-between gap-2">
              <h3 class="m-0 text-sm font-medium text-n-slate-12">
                {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.LIST_TITLE') }}
              </h3>
              <span
                v-if="automationRulesLoading"
                class="text-xs text-n-slate-10"
              >
                {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.LOADING') }}
              </span>
            </div>
            <p
              v-if="!automationRulesLoading && !automationRules.length"
              class="m-0 text-sm text-n-slate-11"
            >
              {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.EMPTY') }}
            </p>
            <article
              v-for="rule in automationRules"
              :key="rule.id"
              class="grid gap-2 rounded-md border border-n-weak bg-n-surface-1 p-3"
              :class="rule.active ? '' : 'opacity-60'"
            >
              <div class="flex flex-wrap items-start justify-between gap-2">
                <div class="min-w-0">
                  <h4 class="m-0 truncate text-sm font-medium text-n-slate-12">
                    {{ rule.name }}
                  </h4>
                  <p class="m-0 text-xs text-n-slate-10">
                    {{
                      automationEventOptions.find(
                        option => option.value === rule.eventName
                      )?.label || rule.eventName
                    }}
                  </p>
                </div>
                <div class="flex items-center gap-1">
                  <Button
                    type="button"
                    icon="i-lucide-pencil"
                    color="slate"
                    size="xs"
                    :aria-label="t('KANBAN.SETTINGS.AUTOMATIONS.RULES.EDIT')"
                    :title="t('KANBAN.SETTINGS.AUTOMATIONS.RULES.EDIT')"
                    @click="applyAutomationRule(rule)"
                  />
                  <Button
                    type="button"
                    icon="i-lucide-trash-2"
                    color="ruby"
                    size="xs"
                    :aria-label="t('KANBAN.SETTINGS.AUTOMATIONS.RULES.DELETE')"
                    :title="t('KANBAN.SETTINGS.AUTOMATIONS.RULES.DELETE')"
                    @click="deleteAutomationRule(rule)"
                  />
                </div>
              </div>
              <label class="flex items-center gap-2 text-xs text-n-slate-11">
                <input
                  :checked="rule.active"
                  type="checkbox"
                  class="size-4 rounded border-n-weak text-n-brand focus:ring-n-brand"
                  @change="toggleAutomationRule(rule)"
                />
                {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.ACTIVE') }}
              </label>
              <div
                class="flex flex-wrap items-center gap-2 border-t border-n-weak pt-2"
              >
                <input
                  v-model="automationTestCardId"
                  type="number"
                  min="1"
                  :placeholder="
                    t('KANBAN.SETTINGS.AUTOMATIONS.RULES.TEST_CARD_ID')
                  "
                  class="h-8 w-40 rounded-md border border-n-weak bg-n-surface-1 px-2 text-xs text-n-slate-12 outline-none focus:border-n-brand"
                />
                <Button
                  type="button"
                  icon="i-lucide-play"
                  :label="t('KANBAN.SETTINGS.AUTOMATIONS.RULES.TEST')"
                  color="slate"
                  size="xs"
                  :disabled="!automationTestCardId"
                  @click="testAutomationRule(rule)"
                />
                <span v-if="rule.lastExecution" class="text-xs text-n-slate-10">
                  {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.LAST_EXECUTION') }}
                  {{ rule.lastExecution.status }}
                </span>
              </div>
              <p
                v-if="
                  selectedAutomationRuleId === rule.id && automationTestResult
                "
                class="m-0 text-xs"
                :class="
                  automationTestResult.matches
                    ? 'text-n-teal-11'
                    : 'text-n-ruby-11'
                "
                role="status"
              >
                {{ automationTestResult.message }}
              </p>
            </article>
          </div>
        </section>

        <section
          v-show="activeSettingsSection === 'danger'"
          class="grid gap-3 border-b border-n-weak pb-6 lg:col-start-2"
        >
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
          class="text-sm text-n-ruby-11 lg:col-start-2"
          role="alert"
        >
          {{ saveError }}
          <button
            v-if="
              saveError && saveError === t('KANBAN.SETTINGS.STALE_SETTINGS')
            "
            type="button"
            data-testid="kanban-settings-reload-after-conflict"
            class="ml-2 font-medium underline"
            @click="reloadSettingsAfterConflict"
          >
            {{ t('KANBAN.SETTINGS.RELOAD') }}
          </button>
        </p>

        <div class="flex justify-end gap-2 lg:col-start-2">
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
        v-model:show="showDuplicateConfirmation"
        :on-close="closeDuplicateConfirmation"
      >
        <div
          class="flex w-full max-w-lg flex-col gap-4 rounded-lg bg-n-surface-1 p-6 text-n-slate-12"
          data-testid="kanban-settings-duplicate-modal"
        >
          <div class="grid gap-1">
            <h2 class="text-lg font-medium">
              {{ t('KANBAN.SETTINGS.DUPLICATE.TITLE') }}
            </h2>
            <p class="text-sm text-n-slate-11">
              {{ t('KANBAN.SETTINGS.DUPLICATE.MESSAGE') }}
            </p>
          </div>
          <footer class="flex justify-end gap-2">
            <Button
              type="button"
              :label="t('KANBAN.ACTIONS.CANCEL')"
              color="slate"
              size="sm"
              @click="closeDuplicateConfirmation"
            />
            <Button
              type="button"
              data-testid="kanban-settings-confirm-duplicate"
              icon="i-lucide-copy"
              :label="t('KANBAN.SETTINGS.DUPLICATE.CONFIRM')"
              color="blue"
              size="sm"
              :is-loading="isDuplicating"
              @click="duplicateBoard"
            />
          </footer>
        </div>
      </woot-modal>

      <woot-delete-modal
        v-model:show="showUnsavedChangesConfirmation"
        :on-close="() => (showUnsavedChangesConfirmation = false)"
        :on-confirm="discardUnsavedSettings"
        :title="t('KANBAN.SETTINGS.UNSAVED.TITLE')"
        :message="t('KANBAN.SETTINGS.UNSAVED.MESSAGE')"
        :confirm-text="t('KANBAN.SETTINGS.UNSAVED.DISCARD')"
        :reject-text="t('KANBAN.ACTIONS.CANCEL')"
      />

      <woot-modal
        v-model:show="showAutomationDeleteConfirmation"
        :on-close="closeAutomationDeleteConfirmation"
      >
        <div
          class="flex w-full max-w-md flex-col gap-4 rounded-lg bg-n-surface-1 p-6 text-n-slate-12"
          data-testid="kanban-automation-delete-modal"
        >
          <div class="grid gap-1">
            <h3 class="text-lg font-medium">
              {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.DELETE') }}
            </h3>
            <p class="text-sm text-n-slate-11">
              {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.DELETE_CONFIRM') }}
            </p>
          </div>
          <div class="flex justify-end gap-2">
            <Button
              type="button"
              data-testid="kanban-automation-delete-cancel"
              :label="t('KANBAN.ACTIONS.CANCEL')"
              color="slate"
              size="sm"
              @click="closeAutomationDeleteConfirmation"
            />
            <Button
              type="button"
              data-testid="kanban-automation-delete-confirm"
              icon="i-lucide-trash-2"
              :label="t('KANBAN.SETTINGS.AUTOMATIONS.RULES.DELETE')"
              color="ruby"
              size="sm"
              :is-loading="automationRulesSaving"
              @click="confirmDeleteAutomationRule"
            />
          </div>
        </div>
      </woot-modal>

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
            role="alert"
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
