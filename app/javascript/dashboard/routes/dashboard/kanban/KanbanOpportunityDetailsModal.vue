<script setup>
import { computed, nextTick, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';

import KanbanBoardsAPI from 'dashboard/api/kanbanBoards';
import ContactAPI from 'dashboard/api/contacts';
import FinanceAPI from 'dashboard/api/finance';
import FormsAPI from 'dashboard/api/forms';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Label from 'dashboard/components-next/label/Label.vue';
import RaevoField from 'dashboard/components-next/raevo/RaevoField.vue';
import RaevoFieldRow from 'dashboard/components-next/raevo/RaevoFieldRow.vue';
import NextInput from 'dashboard/components-next/input/Input.vue';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { copyTextToClipboard } from 'shared/helpers/clipboard';
import KanbanCalendarAppointmentsSection from './KanbanCalendarAppointmentsSection.vue';
import KanbanOpportunityPipelineMenu from './KanbanOpportunityPipelineMenu.vue';
import FinancePaymentDialog from '../finance/FinancePaymentDialog.vue';
import FinancePaymentDetailsDialog from '../finance/FinancePaymentDetailsDialog.vue';
import FormsInvitationDialog from '../forms/FormsInvitationDialog.vue';
import FormsSubmissionDetailsDialog from '../forms/FormsSubmissionDetailsDialog.vue';
import KanbanFormSubmissionRow from './KanbanFormSubmissionRow.vue';
import { useAccountCurrency } from 'dashboard/composables/useAccountCurrency';

const props = defineProps({
  boardId: {
    type: [Number, String],
    required: true,
  },
  boardName: {
    type: String,
    default: '',
  },
  boards: {
    type: Array,
    default: () => [],
  },
  stages: {
    type: Array,
    default: () => [],
  },
  cardId: {
    type: [Number, String],
    required: true,
  },
  nextActionTypes: {
    type: Array,
    default: () => [],
  },
  lostReasonOptions: {
    type: Array,
    default: () => [],
  },
  customFieldDefinitions: {
    type: Array,
    default: () => [],
  },
  customFieldSections: {
    type: Array,
    default: () => [],
  },
  calendarEnabled: {
    type: Boolean,
    default: false,
  },
  calendarBookingStageIds: {
    type: Array,
    default: () => [],
  },
  calendarProcedureIds: {
    type: Array,
    default: () => [],
  },
  ownerOptions: {
    type: Array,
    default: () => [],
  },
  canManageFields: {
    type: Boolean,
    default: false,
  },
  drawerMode: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits([
  'close',
  'updated',
  'openConversation',
  'sendPaymentLink',
  'sendFormLink',
  'manageFields',
  'transferred',
]);

const { t } = useI18n();
const store = useStore();
const accountLabels = useMapGetter('labels/getLabels');
const currentAccount = useMapGetter('getCurrentAccount');
const getAttributesByModel = useMapGetter('attributes/getAttributesByModel');
const contactAttributeDefinitions = computed(
  () => getAttributesByModel.value('contact_attribute') || []
);

const financeStatusLabels = {
  draft: () => t('FINANCE.PAYMENTS.STATUS.DRAFT'),
  pending: () => t('FINANCE.PAYMENTS.STATUS.PENDING'),
  confirmed: () => t('FINANCE.PAYMENTS.STATUS.CONFIRMED'),
  received: () => t('FINANCE.PAYMENTS.STATUS.RECEIVED'),
  overdue: () => t('FINANCE.PAYMENTS.STATUS.OVERDUE'),
  refunded: () => t('FINANCE.PAYMENTS.STATUS.REFUNDED'),
  chargeback: () => t('FINANCE.PAYMENTS.STATUS.CHARGEBACK'),
  canceled: () => t('FINANCE.PAYMENTS.STATUS.CANCELED'),
  failed: () => t('FINANCE.PAYMENTS.STATUS.FAILED'),
};

const card = ref(null);
const subject = ref('');
const description = ref('');
const ownerId = ref('');
const stageId = ref('');
const amountValue = ref('');
const { currency: accountCurrency } = useAccountCurrency();
const amountCurrency = ref('');
const expectedCloseDate = ref('');
const customFieldValues = ref({});
const timeline = ref([]);
const financeModule = ref(null);
const financeConnections = ref([]);
const financePayments = ref([]);
const isLoadingFinance = ref(false);
const financeError = ref('');
const paymentDialog = ref(null);
const paymentDetailsDialog = ref(null);
const formsInvitationDialog = ref(null);
const formsSubmissionDialog = ref(null);
const formsContext = ref({
  invitations: [],
  submissions: [],
  contact_submissions: [],
});
const isLoadingFormsContext = ref(false);
const formsContextError = ref('');
const invitationPendingRevocation = ref(null);
const isRevokingFormInvitation = ref(false);
const formInvitationRevocationConfirmButton = ref(null);
const copiedFinancePaymentId = ref(null);
const isLoadingTimeline = ref(false);
const timelineError = ref('');
const startsAt = ref('');
const dueAt = ref('');
const nextActionType = ref('');
const nextActionAt = ref('');
const nextActionNote = ref('');
const lostReason = ref('');
const isLoading = ref(false);
const isSaving = ref(false);
const isLoadingLabels = ref(false);
const isSavingLabels = ref(false);
const loadError = ref('');
const saveError = ref('');
const formSnapshot = ref('');
const showUnsavedChanges = ref(false);
const keepEditingButton = ref(null);
const headerSubjectInput = ref(null);
const isEditingSubject = ref(false);
const labelsLoadError = ref('');
const labelsSaveError = ref('');
const subjectError = ref('');
const lostReasonError = ref('');
const selectedLabelTitles = ref([]);
const showLabelsPopover = ref(false);
const pendingPipelineTransfer = ref(null);
const activeTabKey = ref('details');
const contactDraft = ref({
  name: '',
  phone_number: '',
  email: '',
  identifier: '',
  custom_attributes: {},
  additional_attributes: {},
});
const isSavingContact = ref(false);
const contactSaveError = ref('');
const expandedGroupKeys = ref({
  organization: false,
  labels: false,
});
const tabList = ref(null);

const modalTitle = computed(() =>
  props.boardName
    ? t('KANBAN.OPPORTUNITY_DETAILS.TITLE_WITH_BOARD', {
        boardName: props.boardName,
      })
    : t('KANBAN.OPPORTUNITY_DETAILS.TITLE')
);
const headerTitle = computed(() => subject.value || modalTitle.value);
const cardDisplayId = computed(() => card.value?.id || props.cardId);
const hasConversation = computed(() => !!card.value?.conversationId);
const contactName = computed(
  () =>
    card.value?.contact?.name ||
    card.value?.contact?.email ||
    card.value?.contact?.phone_number ||
    t('KANBAN.OPPORTUNITY_DETAILS.NO_CONTACT')
);
const selectedStage = computed(() =>
  props.stages.find(stage => String(stage.id) === String(stageId.value))
);
const stageEnteredAt = computed(() => card.value?.stageEnteredAt || '');
const selectedStageIsLost = computed(
  () => selectedStage.value?.category === 'lost'
);
const financeEnabled = computed(() => financeModule.value?.enabled === true);
const financePermissions = computed(
  () => currentAccount.value?.permissions || []
);
const canCreateFinancePayment = computed(() =>
  ['administrator', 'agent', 'finance_create'].some(permission =>
    financePermissions.value.includes(permission)
  )
);
const canManageFinancePayments = computed(() =>
  ['administrator', 'agent', 'finance_manage'].some(permission =>
    financePermissions.value.includes(permission)
  )
);
const canRefundFinancePayments = computed(() =>
  ['administrator', 'finance_refund'].some(permission =>
    financePermissions.value.includes(permission)
  )
);
const canCreateFormInvitation = computed(() =>
  financePermissions.value.includes('administrator')
);
const connectedFinanceConnections = computed(() =>
  financeConnections.value.filter(
    connection => connection.status === 'connected'
  )
);
const financeSummary = computed(() => {
  const receivedPayments = financePayments.value.filter(
    payment => payment.status === 'received'
  );
  const latestPayment = financePayments.value[0];
  const latestReceivedAt = receivedPayments
    .map(payment => payment.paid_at)
    .filter(Boolean)
    .sort()
    .at(-1);

  return {
    status: latestPayment?.status,
    receivedCents: receivedPayments.reduce(
      (total, payment) => total + Number(payment.amount_cents || 0),
      0
    ),
    currency:
      latestPayment?.currency || amountCurrency.value || accountCurrency.value,
    latestReceivedAt,
  };
});
const contactDetails = computed(() => [
  {
    key: 'name',
    label: t('KANBAN.OPPORTUNITY_DETAILS.CONTACT_NAME'),
    value: contactDraft.value.name,
  },
  {
    key: 'phone',
    label: t('KANBAN.OPPORTUNITY_DETAILS.CONTACT_PHONE'),
    value: contactDraft.value.phone_number,
  },
  {
    key: 'email',
    label: t('KANBAN.OPPORTUNITY_DETAILS.CONTACT_EMAIL'),
    value: contactDraft.value.email,
  },
  {
    key: 'identifier',
    label: t('KANBAN.OPPORTUNITY_DETAILS.CONTACT_IDENTIFIER'),
    value: contactDraft.value.identifier,
  },
]);
const formatContactAttributeLabel = key =>
  String(key)
    .replace(/[_-]+/g, ' ')
    .replace(/^./, character => character.toUpperCase());

// A lista sai das definicoes da conta, nao dos valores gravados no contato:
// um atributo que este contato nunca preencheu tem de continuar alcancavel.
const contactAttributeEntries = computed(() => {
  const custom = contactDraft.value.custom_attributes || {};
  const defined = contactAttributeDefinitions.value.map(definition => ({
    key: definition.attribute_key,
    value: custom[definition.attribute_key],
    source: 'custom_attributes',
    label:
      definition.attribute_display_name ||
      formatContactAttributeLabel(definition.attribute_key),
    displayType: definition.attribute_display_type,
    options: definition.attribute_values || [],
  }));
  const definedKeys = new Set(defined.map(entry => entry.key));

  const toEntry =
    source =>
    ([key, value]) => ({
      key,
      value,
      source,
      label: formatContactAttributeLabel(key),
      displayType: typeof value === 'boolean' ? 'checkbox' : 'text',
      options: [],
    });

  return [
    ...Object.entries(contactDraft.value.additional_attributes || {}).map(
      toEntry('additional_attributes')
    ),
    ...defined,
    // valores gravados que perderam a definicao continuam visiveis
    ...Object.entries(custom)
      .filter(([key]) => !definedKeys.has(key))
      .map(toEntry('custom_attributes')),
  ];
});

// As etiquetas chegam do serializador como títulos; a cor vem do vocabulário
// da conta, para o ponto colorido ser o mesmo em todo o produto.
const contactLabels = computed(() => {
  const titles = card.value?.contact?.labels || [];
  const porTitulo = new Map(
    (accountLabels.value || []).map(label => [label.title, label])
  );

  return titles.map(title => porTitulo.get(title) || { title });
});

const hasAttributeValue = value =>
  value !== '' && value !== null && value !== undefined;

// Campos abertos manualmente nesta sessao: sem isto, limpar um valor
// faria a linha desaparecer e nao haveria como redigitar.
const revealedAttributeKeys = ref(new Set());

const visibleContactAttributes = computed(() =>
  contactAttributeEntries.value.filter(
    entry =>
      hasAttributeValue(entry.value) ||
      revealedAttributeKeys.value.has(entry.key)
  )
);
const availableContactAttributes = computed(() =>
  contactAttributeEntries.value.filter(
    entry =>
      !hasAttributeValue(entry.value) &&
      !revealedAttributeKeys.value.has(entry.key)
  )
);
const attributeToAdd = ref('');
const revealContactAttribute = () => {
  if (!attributeToAdd.value) return;

  revealedAttributeKeys.value = new Set(revealedAttributeKeys.value).add(
    attributeToAdd.value
  );
  attributeToAdd.value = '';
};
const formatContactAttributeValue = value => {
  // Um campo aberto e ainda vazio desenhava a string "undefined" na linha em
  // repouso. Vazio é ausência de valor, e quem desenha ausência é o RaevoFieldRow.
  if (!hasAttributeValue(value)) return '';
  if (Array.isArray(value)) return value.join(', ');
  if (typeof value === 'boolean') {
    return value
      ? t('KANBAN.OPPORTUNITY_DETAILS.CONTACT_VALUE_TRUE')
      : t('KANBAN.OPPORTUNITY_DETAILS.CONTACT_VALUE_FALSE');
  }

  return String(value);
};
const setContactAttributeValue = (entry, value) => {
  contactDraft.value = {
    ...contactDraft.value,
    [entry.source]: {
      ...contactDraft.value[entry.source],
      [entry.key]: value,
    },
  };
};
const selectedLabelTitleSet = computed(
  () => new Set(selectedLabelTitles.value)
);
const defaultNextActionTypes = computed(() => [
  t('KANBAN.OPPORTUNITY_DETAILS.ACTION_TYPES.CALL_BACK'),
  t('KANBAN.OPPORTUNITY_DETAILS.ACTION_TYPES.SEND_PROPOSAL'),
  t('KANBAN.OPPORTUNITY_DETAILS.ACTION_TYPES.SEND_PAYMENT_LINK'),
  t('KANBAN.OPPORTUNITY_DETAILS.ACTION_TYPES.FOLLOW_UP'),
  t('KANBAN.OPPORTUNITY_DETAILS.ACTION_TYPES.CONFIRM_PAYMENT'),
  t('KANBAN.OPPORTUNITY_DETAILS.ACTION_TYPES.SEND_CONTRACT'),
  t('KANBAN.OPPORTUNITY_DETAILS.ACTION_TYPES.OTHER'),
]);
const selectableNextActionTypes = computed(() => {
  const configuredOptions = props.nextActionTypes.length
    ? props.nextActionTypes
    : defaultNextActionTypes.value;
  const options = [...configuredOptions];

  if (nextActionType.value && !options.includes(nextActionType.value)) {
    options.unshift(nextActionType.value);
  }

  return options;
});
const nextActionTypeOptions = computed(() => [
  {
    value: '',
    label: t('KANBAN.OPPORTUNITY_DETAILS.ACTION_TYPES.NONE'),
  },
  ...selectableNextActionTypes.value.map(option => ({
    value: option,
    label: option,
  })),
]);

// Valores de exibição da linha em repouso: o utilizador lê o rótulo da opção,
// nunca o id guardado. Data em formato local, valor com moeda.
const rotuloDaOpcao = (opcoes, valor) =>
  opcoes.find(opcao => String(opcao.value) === String(valor))?.label || '';

const ownerDisplay = computed(() =>
  rotuloDaOpcao(props.ownerOptions || [], ownerId.value)
);
const nextActionTypeDisplay = computed(() =>
  rotuloDaOpcao(nextActionTypeOptions.value, nextActionType.value)
);
const dataLocal = valor => {
  if (!valor) return '';
  const d = new Date(valor);
  if (Number.isNaN(d.getTime())) return valor;
  return new Intl.DateTimeFormat(undefined, {
    dateStyle: 'short',
    ...(String(valor).includes('T') ? { timeStyle: 'short' } : {}),
  }).format(d);
};
const nextActionAtDisplay = computed(() => dataLocal(nextActionAt.value));
const expectedCloseDateDisplay = computed(() =>
  dataLocal(expectedCloseDate.value)
);
const amountDisplay = computed(() => {
  const bruto = String(amountValue.value ?? '').trim();
  if (!bruto) return '';
  const n = Number(bruto);
  if (Number.isNaN(n)) return bruto;
  return new Intl.NumberFormat(undefined, {
    style: 'currency',
    currency: amountCurrency.value || accountCurrency.value,
  }).format(n);
});
const selectableLostReasonOptions = computed(() => {
  const options = [...props.lostReasonOptions];

  if (lostReason.value && !options.includes(lostReason.value)) {
    options.unshift(lostReason.value);
  }

  return options;
});
const normalizedCustomFieldDefinitions = computed(() =>
  props.customFieldDefinitions
    .map(definition => ({
      ...definition,
      fieldType: definition.fieldType || definition.field_type,
      requiredStageIds:
        definition.requiredStageIds || definition.required_stage_ids || [],
    }))
    .sort(
      (firstDefinition, secondDefinition) =>
        (firstDefinition.layout?.position || 0) -
        (secondDefinition.layout?.position || 0)
    )
);
const canonicalFieldLayoutKey = value =>
  String(value || '')
    .trim()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_|_$/g, '');
const customFieldSectionKey = definition => {
  const key = canonicalFieldLayoutKey(definition.layout?.section);

  return (
    {
      detail: 'details',
      details: 'details',
      general: 'details',
      geral: 'details',
      marketing: 'marketing',
      mkt: 'marketing',
    }[key] ||
    key ||
    'details'
  );
};
const customFieldGroupKey = definition =>
  canonicalFieldLayoutKey(definition.layout?.group);
const customFieldSectionLabel = sectionKey => {
  if (sectionKey === 'details') {
    return t('KANBAN.OPPORTUNITY_DETAILS.TABS.GENERAL');
  }
  if (sectionKey === 'marketing') {
    return t('KANBAN.OPPORTUNITY_DETAILS.TABS.MARKETING');
  }

  return sectionKey
    .replace(/[_-]+/g, ' ')
    .replace(/^./, character => character.toUpperCase());
};
const customFieldGroupLabel = groupKey =>
  groupKey
    .replace(/[_-]+/g, ' ')
    .replace(/^./, character => character.toUpperCase());
const customFieldTabs = computed(() => {
  const sections = new Map([
    [
      'details',
      { key: 'details', label: customFieldSectionLabel('details'), groups: [] },
    ],
    [
      'marketing',
      {
        key: 'marketing',
        label: customFieldSectionLabel('marketing'),
        groups: [],
      },
    ],
  ]);

  props.customFieldSections.forEach(section => {
    const key = customFieldSectionKey({ layout: { section: section.key } });
    const existingSection = sections.get(key);
    sections.set(key, {
      ...section,
      ...existingSection,
      key,
      groups: section.groups || existingSection?.groups || [],
    });
  });

  normalizedCustomFieldDefinitions.value.forEach(definition => {
    const key = customFieldSectionKey(definition);
    if (sections.has(key)) return;

    sections.set(key, {
      key,
      label: customFieldSectionLabel(key),
      groups: [],
    });
  });

  return [...sections.values()];
});
const timelineTab = computed(() => ({
  key: 'timeline',
  label: t('KANBAN.OPPORTUNITY_DETAILS.TABS.TIMELINE'),
}));
const opportunityTabs = computed(() => {
  const fieldTabs = customFieldTabs.value.filter(tab => tab.key !== 'details');

  return [
    {
      key: 'details',
      label: t('KANBAN.OPPORTUNITY_DETAILS.TABS.GENERAL'),
    },
    {
      key: 'contact-details',
      label: t('KANBAN.OPPORTUNITY_DETAILS.CONTACT'),
    },
    ...(props.calendarEnabled
      ? [
          {
            key: 'calendar',
            label: t('KANBAN.OPPORTUNITY_DETAILS.TABS.CALENDAR'),
          },
        ]
      : []),
    ...(financeEnabled.value
      ? [
          {
            key: 'finance',
            label: t('FINANCE.TITLE'),
          },
        ]
      : []),
    ...(canCreateFormInvitation.value
      ? [
          {
            key: 'forms',
            label: t('FORMS.TITLE'),
          },
        ]
      : []),
    ...fieldTabs,
    timelineTab.value,
  ];
});

const normalizeCard = payload =>
  Object.fromEntries(
    Object.entries({
      ...payload,
      accountId: payload.accountId ?? payload.account_id,
      kanbanBoardId: payload.kanbanBoardId ?? payload.kanban_board_id,
      kanbanStageId: payload.kanbanStageId ?? payload.kanban_stage_id,
      conversationId: payload.conversationId ?? payload.conversation_id,
      ownerId: payload.ownerId ?? payload.owner_id,
      amountCents: payload.amountCents ?? payload.amount_cents,
      amountCurrency: payload.amountCurrency ?? payload.amount_currency,
      expectedCloseDate:
        payload.expectedCloseDate ?? payload.expected_close_date,
      customFieldValues:
        payload.customFieldValues ?? payload.custom_field_values,
      startsAt: payload.startsAt ?? payload.starts_at,
      dueAt: payload.dueAt ?? payload.due_at,
      nextActionType: payload.nextActionType ?? payload.next_action_type,
      nextActionAt: payload.nextActionAt ?? payload.next_action_at,
      nextActionNote: payload.nextActionNote ?? payload.next_action_note,
      nextActionCompletedAt:
        payload.nextActionCompletedAt ??
        payload.next_action_completed_at ??
        null,
      nextActionHistory:
        payload.nextActionHistory ?? payload.next_action_history ?? [],
      lostReason: payload.lostReason ?? payload.lost_reason,
    }).filter(([, value]) => value !== undefined)
  );

const formatDateTimeInput = value => {
  if (!value) return '';

  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return String(value).slice(0, 16);

  const offset = date.getTimezoneOffset();
  const localDate = new Date(date.getTime() - offset * 60000);
  return localDate.toISOString().slice(0, 16);
};

const toIso8601 = value => (value ? new Date(value).toISOString() : null);
const formatAmountInput = amountCents =>
  amountCents === null || amountCents === undefined
    ? ''
    : (Number(amountCents) / 100).toFixed(2);
const toAmountCents = value => {
  const normalizedValue = String(value || '')
    .replace(',', '.')
    .trim();
  if (!normalizedValue) return null;

  const amount = Number(normalizedValue);
  return Number.isNaN(amount) ? null : Math.round(amount * 100);
};
function isCustomFieldVisible(definition) {
  const condition = definition.condition || {};
  if (!condition.fieldKey && !condition.field_key) return true;

  const fieldKey = condition.fieldKey || condition.field_key;
  return (
    String(customFieldValues.value[fieldKey] ?? '') === String(condition.equals)
  );
}
const visibleCustomFieldDefinitions = computed(() =>
  normalizedCustomFieldDefinitions.value.filter(definition =>
    isCustomFieldVisible(definition)
  )
);
const activeTabCustomFieldDefinitions = computed(() =>
  visibleCustomFieldDefinitions.value.filter(
    definition => customFieldSectionKey(definition) === activeTabKey.value
  )
);
const activeTabGroups = computed(() => {
  const activeSection = customFieldTabs.value.find(
    section => section.key === activeTabKey.value
  );
  const definitions = activeTabCustomFieldDefinitions.value;
  const seenGroupKeys = new Set();
  const groups = (activeSection?.groups || []).flatMap(group => {
    const key = canonicalFieldLayoutKey(group.key);
    if (!key || seenGroupKeys.has(key)) return [];

    seenGroupKeys.add(key);
    return [
      {
        ...group,
        key,
        definitions: definitions.filter(
          definition => customFieldGroupKey(definition) === key
        ),
      },
    ];
  });
  const ungrouped = definitions.filter(
    definition => !customFieldGroupKey(definition)
  );

  if (ungrouped.length) {
    // Quando a aba não tem grupos, os seus campos são a aba — não «outros».
    // Estavam a ser empurrados para debaixo de um cabeçalho genérico, abaixo
    // dos campos nativos, como se fossem sobras.
    groups.push({
      key: 'ungrouped',
      label: groups.length
        ? t('KANBAN.OPPORTUNITY_DETAILS.UNGROUPED_FIELDS')
        : '',
      color: 'slate',
      definitions: ungrouped,
    });
  }

  definitions
    .filter(definition => {
      const groupKey = customFieldGroupKey(definition);
      return groupKey && !seenGroupKeys.has(groupKey);
    })
    .forEach(definition => {
      const key = customFieldGroupKey(definition);
      if (seenGroupKeys.has(key)) return;

      seenGroupKeys.add(key);
      groups.push({
        key,
        label: customFieldGroupLabel(key),
        color: 'slate',
        definitions: definitions.filter(
          groupedDefinition => customFieldGroupKey(groupedDefinition) === key
        ),
      });
    });

  return groups.filter(group => group.definitions.length);
});
const customFieldGroupClass = color =>
  ({
    slate: 'border-l-n-slate-7',
    blue: 'border-l-n-blue-7',
    teal: 'border-l-n-teal-7',
    green: 'border-l-green-600',
    amber: 'border-l-n-amber-7',
    orange: 'border-l-orange-600',
    ruby: 'border-l-n-ruby-7',
    rose: 'border-l-rose-600',
    violet: 'border-l-n-violet-7',
    iris: 'border-l-n-iris-7',
  })[color] || 'border-l-n-slate-7';
const groupToggleKey = (sectionKey, groupKey) => `${sectionKey}:${groupKey}`;
const isGroupExpanded = groupKey => expandedGroupKeys.value[groupKey] !== false;
const toggleGroup = groupKey => {
  expandedGroupKeys.value = {
    ...expandedGroupKeys.value,
    [groupKey]: !isGroupExpanded(groupKey),
  };
};
const hasCustomFields = computed(
  () => activeTabCustomFieldDefinitions.value.length > 0
);
const getCustomFieldValue = definition =>
  customFieldValues.value[definition.key] ?? '';

/**
 * O valor como se lê, para a linha em repouso.
 *
 * Os campos personalizados desenhavam uma linha só deles — rótulo de 9rem,
 * outro espaçamento, sempre em edição — enquanto os nativos usavam o
 * `RaevoFieldRow`. Duas linhas diferentes para a mesma coisa no mesmo painel.
 */
const customFieldDisplayValue = definition => {
  const valor = getCustomFieldValue(definition);

  if (definition.fieldType === 'boolean') {
    return valor
      ? t('KANBAN.OPPORTUNITY_DETAILS.BOOLEAN_YES')
      : t('KANBAN.OPPORTUNITY_DETAILS.BOOLEAN_NO');
  }
  if (Array.isArray(valor)) return valor.join(', ');

  return valor === '' || valor === null || valor === undefined
    ? ''
    : String(valor);
};

/**
 * A largura escolhida na configuração.
 *
 * `layout.width` era guardada, aparecia no editor e nunca chegava aqui: quem
 * escolhia «metade» estava a configurar o nada. Meia largura ocupa uma coluna;
 * o resto atravessa as duas, como já acontecia com tudo.
 */
const customFieldSpanClass = definition =>
  definition.layout?.width === 'half' ? '' : 'sm:col-span-2';

const customFieldRowVariant = definition => {
  if (['select', 'multiselect'].includes(definition.fieldType)) return 'select';
  if (definition.fieldType === 'textarea') return 'textarea';

  return 'input';
};
const setCustomFieldValue = (definition, value) => {
  customFieldValues.value = {
    ...customFieldValues.value,
    [definition.key]: value,
  };
};
const selectedMultiselectValues = event =>
  Array.from(event.target.selectedOptions).map(option => option.value);

const getErrorMessage = (error, fallback) => {
  const errors = error?.response?.data?.errors;

  if (Array.isArray(errors)) return errors.join(', ');
  if (typeof errors === 'string') return errors;
  if (errors && typeof errors === 'object') {
    return Object.values(errors).flat().join(', ');
  }

  return error?.response?.data?.message || error?.message || fallback;
};

const currentFormState = () => ({
  subject: subject.value,
  description: description.value,
  ownerId: ownerId.value,
  stageId: stageId.value,
  amountValue: amountValue.value,
  amountCurrency: amountCurrency.value,
  expectedCloseDate: expectedCloseDate.value,
  customFieldValues: customFieldValues.value,
  startsAt: startsAt.value,
  dueAt: dueAt.value,
  nextActionType: nextActionType.value,
  nextActionAt: nextActionAt.value,
  nextActionNote: nextActionNote.value,
  lostReason: lostReason.value,
});
const serializeFormState = () => JSON.stringify(currentFormState());
const isFormDirty = computed(
  () => !!formSnapshot.value && formSnapshot.value !== serializeFormState()
);

const setFormState = payload => {
  card.value = normalizeCard(payload);
  contactDraft.value = {
    name: card.value.contact?.name || '',
    phone_number: card.value.contact?.phone_number || '',
    email: card.value.contact?.email || '',
    identifier: card.value.contact?.identifier || '',
    custom_attributes: { ...(card.value.contact?.custom_attributes || {}) },
    additional_attributes: {
      ...(card.value.contact?.additional_attributes || {}),
    },
  };
  revealedAttributeKeys.value = new Set();
  attributeToAdd.value = '';
  subject.value = card.value.subject || '';
  description.value = card.value.description || '';
  ownerId.value = card.value.ownerId ? String(card.value.ownerId) : '';
  stageId.value = card.value.kanbanStageId
    ? String(card.value.kanbanStageId)
    : '';
  amountValue.value = formatAmountInput(card.value.amountCents);
  amountCurrency.value = card.value.amountCurrency || accountCurrency.value;
  expectedCloseDate.value = card.value.expectedCloseDate || '';
  customFieldValues.value = card.value.customFieldValues || {};
  startsAt.value = formatDateTimeInput(card.value.startsAt);
  dueAt.value = formatDateTimeInput(card.value.dueAt);
  nextActionType.value = card.value.nextActionType || '';
  nextActionAt.value = formatDateTimeInput(card.value.nextActionAt);
  nextActionNote.value = card.value.nextActionNote || '';
  lostReason.value = card.value.lostReason || '';
  formSnapshot.value = serializeFormState();
};

const getLabelsPayload = response =>
  response?.data?.payload || response?.data || [];

const loadLabels = async () => {
  isLoadingLabels.value = true;
  labelsLoadError.value = '';

  try {
    const [assignedLabelsResponse] = await Promise.all([
      KanbanBoardsAPI.getCardLabels(props.boardId, props.cardId),
      store.dispatch('labels/get'),
    ]);
    selectedLabelTitles.value = getLabelsPayload(assignedLabelsResponse).map(
      label => label.title || label
    );
  } catch (error) {
    labelsLoadError.value = getErrorMessage(
      error,
      t('KANBAN.OPPORTUNITY_DETAILS.LOAD_LABELS_ERROR')
    );
  } finally {
    isLoadingLabels.value = false;
  }
};

const loadCard = async () => {
  isLoading.value = true;
  loadError.value = '';

  try {
    const response = await KanbanBoardsAPI.showCardById(
      props.boardId,
      props.cardId
    );
    setFormState(response.data || {});
  } catch (error) {
    loadError.value = getErrorMessage(
      error,
      t('KANBAN.OPPORTUNITY_DETAILS.LOAD_ERROR')
    );
  } finally {
    isLoading.value = false;
  }
};

const loadTimeline = async () => {
  isLoadingTimeline.value = true;
  timelineError.value = '';

  try {
    const response = await KanbanBoardsAPI.getCardTimeline(
      props.boardId,
      props.cardId
    );
    timeline.value = response?.data || [];
  } catch (error) {
    timelineError.value = getErrorMessage(
      error,
      t('KANBAN.OPPORTUNITY_DETAILS.TIMELINE.LOAD_ERROR')
    );
  } finally {
    isLoadingTimeline.value = false;
  }
};

const loadFinanceModule = async () => {
  try {
    const { data } = await FinanceAPI.getModule();
    financeModule.value = data;
    if (data.enabled) {
      const connectionsResponse = await FinanceAPI.getProviderConnections();
      financeConnections.value = connectionsResponse.data;
    }
  } catch {
    financeModule.value = null;
    financeConnections.value = [];
  }
};

const loadFinancePayments = async () => {
  if (!financeEnabled.value || isLoadingFinance.value) return;

  isLoadingFinance.value = true;
  financeError.value = '';
  try {
    const { data } = await FinanceAPI.getPayments({
      kanban_card_id: props.cardId,
    });
    financePayments.value = data;
  } catch {
    financeError.value = t('FINANCE.ERROR.LOAD');
  } finally {
    isLoadingFinance.value = false;
  }
};

const openFinancePaymentDialog = () => {
  paymentDialog.value?.open();
};

const openFormsInvitationDialog = () => {
  formsInvitationDialog.value?.open();
};

/**
 * Resolve o que o formulário propôs mas não aplicou.
 *
 * Uma ação em modo «deixar para confirmar» ficou à espera de quem conhece o
 * caso. Confirmar aplica-a; descartar tira-a da frente. Nos dois casos ela sai
 * da lista, porque proposta que fica para sempre deixa de ser lida.
 */
const resolvingAction = ref(null);
const pendingActionError = ref('');

const resolvePendingAction = async (submission, action, decision) => {
  if (resolvingAction.value) return;

  resolvingAction.value = `${submission.id}-${action.index}`;
  pendingActionError.value = '';
  try {
    const { data } = await FormsAPI.resolvePendingAction(
      submission.id,
      action.index,
      decision
    );
    submission.pending_actions = (data.pending_actions || []).map(
      (pendente, index) => ({ index, kind: pendente.kind })
    );
    // Confirmar pode ter movido a etapa: o card tem de ser relido.
    // Confirmar pode ter movido a etapa: quem abriu o card tem de reler.
    if (decision === 'confirm') emit('updated');
  } catch (error) {
    pendingActionError.value = getErrorMessage(
      error,
      t('FORMS.SUBMISSION_ACTIONS.RESOLVE_ERROR')
    );
  } finally {
    resolvingAction.value = null;
  }
};

// A linha emite um evento só; quem resolve continua a ser esta função.
const onResolvePendingAction = ({ submission, action, decision }) =>
  resolvePendingAction(submission, action, decision);

const openFormsSubmission = submission => {
  formsSubmissionDialog.value?.open(submission.id);
};

const requestFormInvitationRevocation = invitation => {
  if (invitation.status !== 'active') return;

  invitationPendingRevocation.value = invitation;
};

const revokeFormInvitation = async () => {
  const invitation = invitationPendingRevocation.value;
  if (!invitation || isRevokingFormInvitation.value) return;

  isRevokingFormInvitation.value = true;
  formsContextError.value = '';
  try {
    const { data } = await FormsAPI.revokeInvitation(invitation.id);
    formsContext.value = {
      ...formsContext.value,
      invitations: formsContext.value.invitations.map(item =>
        item.id === data.id ? { ...item, ...data } : item
      ),
    };
    invitationPendingRevocation.value = null;
  } catch {
    formsContextError.value = t('FORMS.ERROR.REVOKE');
  } finally {
    isRevokingFormInvitation.value = false;
  }
};

const loadFormsContext = async () => {
  if (!card.value?.id || isLoadingFormsContext.value) return;

  isLoadingFormsContext.value = true;
  formsContextError.value = '';
  try {
    const { data } = await FormsAPI.getCardContext(card.value.id);
    formsContext.value = data;
  } catch {
    formsContext.value = {
      invitations: [],
      submissions: [],
      contact_submissions: [],
    };
    formsContextError.value = t('FORMS.ERROR.LOAD');
  } finally {
    isLoadingFormsContext.value = false;
  }
};

const formInvitationStatusLabel = status => {
  const labels = {
    active: t('FORMS.INVITATION.STATUS.ACTIVE'),
    abandoned: t('FORMS.INVITATION.STATUS.ABANDONED'),
    consumed: t('FORMS.INVITATION.STATUS.CONSUMED'),
    expired: t('FORMS.INVITATION.STATUS.EXPIRED'),
    revoked: t('FORMS.INVITATION.STATUS.REVOKED'),
  };
  return labels[status] || status;
};

const formatFormInvitationDate = value => {
  if (!value) return '';

  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return '';

  return date.toLocaleString();
};

const sendFormsInvitationLink = url => {
  if (!hasConversation.value || !url) return;

  emit('sendFormLink', { card: card.value, url });
};

const openFinancePaymentDetails = payment => {
  paymentDetailsDialog.value?.open(payment.id);
};

const addFinancePayment = payment => {
  financePayments.value = [payment, ...financePayments.value];
};

const updateFinancePayment = updatedPayment => {
  financePayments.value = financePayments.value.map(payment =>
    payment.id === updatedPayment.id ? updatedPayment : payment
  );
};

const copyFinancePaymentLink = async payment => {
  if (!payment.invoice_url) return;

  await copyTextToClipboard(payment.invoice_url);
  copiedFinancePaymentId.value = payment.id;
  window.setTimeout(() => {
    copiedFinancePaymentId.value = null;
  }, 2000);
};

const formatFinanceAmount = (amountCents, currency) =>
  new Intl.NumberFormat(undefined, {
    style: 'currency',
    currency: currency || accountCurrency.value,
  }).format(Number(amountCents || 0) / 100);

const formatFinanceDate = value => {
  if (!value) return t('FINANCE.SUMMARY.NO_PAYMENT_DATE');

  return new Intl.DateTimeFormat(undefined, { dateStyle: 'medium' }).format(
    new Date(value)
  );
};

const financeStatusLabel = status => {
  if (!status) return t('FINANCE.SUMMARY.NO_STATUS');

  return (
    financeStatusLabels[status.toString().toLowerCase()]?.() ||
    t('FINANCE.SUMMARY.NO_STATUS')
  );
};

const sendFinancePaymentLink = payment => {
  if (!hasConversation.value || !payment.invoice_url) return;

  emit('sendPaymentLink', { card: card.value, payment });
};

const timelineEventLabel = event => {
  const enteredStage = event.metadata?.to_stage?.name;
  const createdStage = event.metadata?.entered_stage?.name;

  if (event.event_type === 'stage_changed' && enteredStage) {
    return t('KANBAN.OPPORTUNITY_DETAILS.TIMELINE.ENTERED_STAGE', {
      stage: enteredStage,
    });
  }
  if (event.event_type === 'card_created' && createdStage) {
    return t('KANBAN.OPPORTUNITY_DETAILS.TIMELINE.CREATED_IN_STAGE', {
      stage: createdStage,
    });
  }

  return String(event.event_type || '')
    .replaceAll('_', ' ')
    .replace(/^./, character => character.toUpperCase());
};
const timelineEventMeta = event => {
  const actorName =
    event.actor?.name || t('KANBAN.OPPORTUNITY_DETAILS.TIMELINE.SYSTEM');
  return `${actorName} - ${new Date(event.occurred_at).toLocaleString()}`;
};

const buildCardPayload = extraPayload => ({
  subject: subject.value.trim(),
  description: description.value.trim() ? description.value : null,
  owner_id: ownerId.value ? Number(ownerId.value) : null,
  kanban_stage_id: stageId.value ? Number(stageId.value) : null,
  amount_cents: toAmountCents(amountValue.value),
  amount_currency: amountCurrency.value || accountCurrency.value,
  expected_close_date: expectedCloseDate.value || null,
  custom_field_values: customFieldValues.value,
  starts_at: toIso8601(startsAt.value),
  due_at: toIso8601(dueAt.value),
  next_action_type: nextActionType.value || null,
  next_action_at: toIso8601(nextActionAt.value),
  next_action_note: nextActionNote.value.trim() ? nextActionNote.value : null,
  lost_reason: selectedStageIsLost.value
    ? lostReason.value.trim() || null
    : null,
  ...extraPayload,
});

const saveCardWith = async (extraPayload = {}) => {
  if (isSaving.value) return;

  const trimmedSubject = subject.value.trim();
  subjectError.value = '';
  saveError.value = '';

  if (!trimmedSubject) {
    subjectError.value = t('KANBAN.OPPORTUNITY_DETAILS.REQUIRED_TITLE');
    return;
  }

  if (selectedStageIsLost.value && !String(lostReason.value || '').trim()) {
    lostReasonError.value = t(
      'KANBAN.OPPORTUNITY_DETAILS.LOST_REASON_REQUIRED'
    );
    return;
  }

  isSaving.value = true;

  try {
    const response = await KanbanBoardsAPI.updateCardDetailsById(
      props.boardId,
      props.cardId,
      buildCardPayload({ subject: trimmedSubject, ...extraPayload })
    );
    const updatedCard = normalizeCard(response.data || {});
    setFormState(updatedCard);
    emit('updated', updatedCard);
  } catch (error) {
    saveError.value = getErrorMessage(
      error,
      t('KANBAN.OPPORTUNITY_DETAILS.SAVE_ERROR')
    );
  } finally {
    isSaving.value = false;
  }
};

const saveCard = () => saveCardWith();

const completeNextAction = () =>
  saveCardWith({
    next_action_completed_at: new Date().toISOString(),
  });

const transferPipelineStage = async ({
  boardId,
  stageId: targetStageId,
  lostReason: transferLostReason,
}) => {
  isSaving.value = true;
  saveError.value = '';
  try {
    const response = await KanbanBoardsAPI.transferCardById(
      props.boardId,
      props.cardId,
      {
        kanban_board_id: boardId,
        kanban_stage_id: targetStageId,
        lock_version: card.value?.lockVersion,
        lost_reason: transferLostReason || undefined,
      }
    );
    pendingPipelineTransfer.value = null;
    emit('transferred', {
      boardId,
      card: normalizeCard(response.data || {}),
    });
  } catch (error) {
    saveError.value = getErrorMessage(
      error,
      t('KANBAN.OPPORTUNITY_DETAILS.SAVE_ERROR')
    );
  } finally {
    isSaving.value = false;
  }
};

const selectPipelineStage = async ({
  boardId,
  stageId: targetStageId,
  stage,
}) => {
  if (isSaving.value || !targetStageId) return;

  if (Number(boardId) === Number(props.boardId)) {
    stageId.value = String(targetStageId);
    return;
  }

  if (isFormDirty.value) {
    saveError.value = t('KANBAN.OPPORTUNITY_DETAILS.SAVE_BEFORE_TRANSFER');
    return;
  }

  if (stage?.category === 'lost') {
    pendingPipelineTransfer.value = {
      boardId,
      stageId: targetStageId,
      stage,
      lostReason: '',
    };
    return;
  }

  await transferPipelineStage({ boardId, stageId: targetStageId });
};

const confirmPipelineTransfer = async () => {
  const transfer = pendingPipelineTransfer.value;
  if (!transfer || !transfer.lostReason.trim()) return;

  await transferPipelineStage({
    boardId: transfer.boardId,
    stageId: transfer.stageId,
    lostReason: transfer.lostReason.trim(),
  });
};

const toggleLabel = title => {
  labelsSaveError.value = '';

  selectedLabelTitles.value = selectedLabelTitleSet.value.has(title)
    ? selectedLabelTitles.value.filter(selectedTitle => selectedTitle !== title)
    : [...selectedLabelTitles.value, title];
};

const saveLabels = async () => {
  if (isSavingLabels.value) return;

  isSavingLabels.value = true;
  labelsSaveError.value = '';

  try {
    const response = await KanbanBoardsAPI.updateCardLabels(
      props.boardId,
      props.cardId,
      selectedLabelTitles.value
    );
    selectedLabelTitles.value = getLabelsPayload(response).map(
      label => label.title || label
    );
  } catch (error) {
    labelsSaveError.value = getErrorMessage(
      error,
      t('KANBAN.OPPORTUNITY_DETAILS.SAVE_LABELS_ERROR')
    );
  } finally {
    isSavingLabels.value = false;
  }
};

const saveContact = async () => {
  const contactId = card.value?.contact?.id;
  if (!contactId || isSavingContact.value) return;

  isSavingContact.value = true;
  contactSaveError.value = '';
  try {
    const response = await ContactAPI.update(contactId, {
      name: contactDraft.value.name.trim(),
      phone_number: contactDraft.value.phone_number.trim(),
      email: contactDraft.value.email.trim(),
      identifier: contactDraft.value.identifier.trim(),
      custom_attributes: contactDraft.value.custom_attributes,
      additional_attributes: contactDraft.value.additional_attributes,
    });
    const updatedContact = response.data || {};
    card.value = {
      ...card.value,
      contact: { ...card.value.contact, ...updatedContact },
    };
    contactDraft.value = {
      ...contactDraft.value,
      ...updatedContact,
      custom_attributes:
        updatedContact.custom_attributes ||
        contactDraft.value.custom_attributes,
      additional_attributes:
        updatedContact.additional_attributes ||
        contactDraft.value.additional_attributes,
    };
  } catch (error) {
    contactSaveError.value = getErrorMessage(
      error,
      t('KANBAN.OPPORTUNITY_DETAILS.SAVE_CONTACT_ERROR')
    );
  } finally {
    isSavingContact.value = false;
  }
};

const openConversation = () => {
  if (!hasConversation.value) return;

  emit('openConversation', card.value);
};

const requestClose = event => {
  if (!isFormDirty.value) {
    emit('close');
    return;
  }

  event?.preventDefault?.();
  showUnsavedChanges.value = true;
};
const keepEditing = () => {
  showUnsavedChanges.value = false;
};
const discardChanges = () => {
  showUnsavedChanges.value = false;
  emit('close');
};
const trapModalFocus = event => {
  if (event.key !== 'Tab') return;

  const focusableElements = [
    ...event.currentTarget.querySelectorAll(
      'button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [href]'
    ),
  ];
  if (!focusableElements.length) return;

  const firstElement = focusableElements[0];
  const lastElement = focusableElements[focusableElements.length - 1];

  if (event.shiftKey && document.activeElement === firstElement) {
    event.preventDefault();
    lastElement.focus();
  } else if (!event.shiftKey && document.activeElement === lastElement) {
    event.preventDefault();
    firstElement.focus();
  }
};

const handleModalKeydown = event => {
  trapModalFocus(event);

  if (event.key !== 'Escape' || !isFormDirty.value) return;

  event.preventDefault();
  event.stopPropagation();
  showUnsavedChanges.value = true;
};

const handleTabKeydown = async event => {
  const currentIndex = opportunityTabs.value.findIndex(
    tab => tab.key === activeTabKey.value
  );
  if (currentIndex < 0) return;

  let nextIndex = currentIndex;
  if (event.key === 'ArrowRight') {
    nextIndex = (currentIndex + 1) % opportunityTabs.value.length;
  } else if (event.key === 'ArrowLeft') {
    nextIndex =
      (currentIndex - 1 + opportunityTabs.value.length) %
      opportunityTabs.value.length;
  } else if (event.key === 'Home') {
    nextIndex = 0;
  } else if (event.key === 'End') {
    nextIndex = opportunityTabs.value.length - 1;
  } else {
    return;
  }

  event.preventDefault();
  activeTabKey.value = opportunityTabs.value[nextIndex].key;
  await nextTick();
  tabList.value
    ?.querySelector(`#kanban-opportunity-tab-${activeTabKey.value}`)
    ?.focus();
};

const editSubject = async () => {
  isEditingSubject.value = true;
  await nextTick();
  headerSubjectInput.value?.focus();
};

defineExpose({ requestClose });

onMounted(() => {
  loadCard();
  loadLabels();
  loadTimeline();
  loadFinanceModule();
  // sem as definicoes carregadas o bloco de contato volta a mostrar
  // apenas os atributos que ja tinham valor
  store.dispatch('attributes/get');
});

watch(activeTabKey, tab => {
  if (tab === 'finance') loadFinancePayments();
  if (tab === 'forms') loadFormsContext();
});

watch(showUnsavedChanges, async visible => {
  if (!visible) return;

  await nextTick();
  keepEditingButton.value?.focus();
});

watch(invitationPendingRevocation, async invitation => {
  if (!invitation) return;

  await nextTick();
  formInvitationRevocationConfirmButton.value?.focus();
});
</script>

<template>
  <div
    class="relative"
    :class="
      drawerMode
        ? 'flex h-full max-h-full w-full flex-col overflow-hidden bg-n-background'
        : 'mx-auto flex max-h-[94vh] w-full max-w-[calc(100vw-1rem)] flex-col overflow-hidden rounded-xl bg-n-background 2xl:max-w-[88rem]'
    "
    @keydown="handleModalKeydown"
  >
    <div
      class="flex items-start justify-between gap-4 border-b border-n-weak px-5 py-3"
    >
      <div class="min-w-0">
        <h2 class="mb-0 truncate text-base font-semibold text-n-slate-12">
          <input
            v-show="isEditingSubject"
            ref="headerSubjectInput"
            v-model="subject"
            data-testid="kanban-opportunity-header-subject"
            class="w-full rounded-md border border-n-weak bg-n-surface-1 px-2 py-1 text-base font-semibold text-n-slate-12 outline-none focus:border-n-brand"
            @input="subjectError = ''"
            @blur="isEditingSubject = false"
            @keydown.enter.prevent="isEditingSubject = false"
          />
          <span v-show="!isEditingSubject">{{ headerTitle }}</span>
        </h2>
        <p v-if="subjectError" class="mb-1 text-xs text-n-ruby-11" role="alert">
          {{ subjectError }}
        </p>
        <div
          v-if="cardDisplayId"
          class="mt-1 flex flex-wrap items-center gap-2"
        >
          <span
            data-testid="kanban-opportunity-card-id"
            class="text-xs text-n-slate-11"
          >
            {{ t('KANBAN.OPPORTUNITY_DETAILS.CARD_ID', { id: cardDisplayId }) }}
          </span>
          <KanbanOpportunityPipelineMenu
            data-testid="kanban-opportunity-header-stage"
            :board-id="boardId"
            :board-name="boardName"
            :boards="boards"
            :stages="stages"
            :selected-stage-id="stageId"
            :stage-entered-at="stageEnteredAt"
            @select-stage="selectPipelineStage"
          />
          <div class="relative">
            <button
              type="button"
              data-testid="kanban-opportunity-toggle-labels"
              class="flex h-7 items-center gap-1 rounded-md border border-solid border-n-weak bg-n-surface-1 px-2 text-xs font-medium text-n-slate-11 outline-none hover:bg-n-alpha-2 hover:text-n-slate-12 focus:ring-2 focus:ring-n-brand/40"
              :aria-expanded="showLabelsPopover"
              aria-controls="kanban-opportunity-labels-popover"
              @click="showLabelsPopover = !showLabelsPopover"
            >
              <i class="i-lucide-tags size-3.5" />
              {{ t('KANBAN.OPPORTUNITY_DETAILS.LABELS') }}
              <span v-if="selectedLabelTitles.length" class="text-n-slate-10">
                {{ selectedLabelTitles.length }}
              </span>
            </button>
            <div
              v-if="showLabelsPopover"
              id="kanban-opportunity-labels-popover"
              class="absolute left-0 z-30 mt-2 grid w-72 gap-3 rounded-lg border border-n-weak bg-n-solid-1 p-3 shadow-lg"
            >
              <div class="flex items-center justify-between gap-3">
                <span class="text-sm font-medium text-n-slate-12">
                  {{ t('KANBAN.OPPORTUNITY_DETAILS.LABELS') }}
                </span>
                <button
                  type="button"
                  data-testid="kanban-opportunity-save-labels"
                  class="flex p-0 size-7 items-center justify-center rounded-md text-n-slate-11 outline-none hover:bg-n-alpha-2 hover:text-n-slate-12 focus:ring-2 focus:ring-n-brand/40 disabled:cursor-not-allowed disabled:opacity-50"
                  :aria-label="
                    isSavingLabels
                      ? t('KANBAN.OPPORTUNITY_DETAILS.SAVING_LABELS')
                      : t('KANBAN.OPPORTUNITY_DETAILS.SAVE_LABELS')
                  "
                  :disabled="isSavingLabels"
                  @click="saveLabels"
                >
                  <i class="i-lucide-save size-4" />
                </button>
              </div>
              <p
                v-if="labelsLoadError || labelsSaveError"
                class="mb-0 text-xs text-n-ruby-11"
                role="alert"
              >
                {{ labelsLoadError || labelsSaveError }}
              </p>
              <div
                v-if="accountLabels.length"
                data-testid="kanban-opportunity-labels"
                class="flex flex-wrap gap-1.5"
              >
                <button
                  v-for="label in accountLabels"
                  :key="label.id || label.title"
                  type="button"
                  data-testid="kanban-opportunity-label"
                  class="flex items-center gap-1.5 rounded-full border border-solid px-2 py-1 text-xs font-medium transition"
                  :class="
                    selectedLabelTitleSet.has(label.title)
                      ? 'border-n-blue-9 bg-n-blue-3 text-n-blue-12'
                      : 'border-n-weak text-n-slate-11 hover:bg-n-alpha-2 hover:text-n-slate-12'
                  "
                  :aria-pressed="selectedLabelTitleSet.has(label.title)"
                  @click="toggleLabel(label.title)"
                >
                  <span
                    class="size-2 rounded-full"
                    :style="{ backgroundColor: label.color }"
                  />
                  <span>{{ label.title }}</span>
                  <i
                    v-if="selectedLabelTitleSet.has(label.title)"
                    class="i-lucide-check size-3"
                  />
                </button>
              </div>
              <p
                v-else-if="!isLoadingLabels"
                data-testid="kanban-opportunity-no-labels"
                class="mb-0 text-xs text-n-slate-11"
              >
                {{ t('KANBAN.OPPORTUNITY_DETAILS.NO_LABELS_AVAILABLE') }}
              </p>
            </div>
          </div>
        </div>
      </div>
      <div class="flex flex-shrink-0 items-center gap-1">
        <button
          v-if="hasConversation"
          type="button"
          data-testid="kanban-opportunity-header-open-conversation"
          class="flex p-0 size-8 items-center justify-center rounded-md text-n-slate-11 outline-none hover:bg-n-alpha-2 hover:text-n-slate-12 focus:ring-2 focus:ring-n-brand/40"
          :aria-label="t('KANBAN.OPPORTUNITY_DETAILS.OPEN_CONVERSATION')"
          :title="t('KANBAN.OPPORTUNITY_DETAILS.OPEN_CONVERSATION')"
          @click="openConversation"
        >
          <i class="i-lucide-message-square size-4" />
        </button>
        <button
          type="button"
          data-testid="kanban-opportunity-edit-subject"
          class="flex p-0 size-8 items-center justify-center rounded-md text-n-slate-11 outline-none hover:bg-n-alpha-2 hover:text-n-slate-12 focus:ring-2 focus:ring-n-brand/40"
          :aria-label="t('KANBAN.OPPORTUNITY_DETAILS.EDIT_TITLE')"
          :title="t('KANBAN.OPPORTUNITY_DETAILS.EDIT_TITLE')"
          @click="editSubject"
        >
          <i class="i-lucide-pencil size-4" />
        </button>
        <button
          v-if="canManageFields"
          type="button"
          data-testid="kanban-opportunity-manage-fields"
          class="flex p-0 size-8 items-center justify-center rounded-md text-n-slate-11 outline-none hover:bg-n-alpha-2 hover:text-n-slate-12 focus:ring-2 focus:ring-n-brand/40"
          :aria-label="t('KANBAN.OPPORTUNITY_DETAILS.MANAGE_FIELDS')"
          :title="t('KANBAN.OPPORTUNITY_DETAILS.MANAGE_FIELDS')"
          @click="emit('manageFields')"
        >
          <i class="i-lucide-settings-2 size-4" />
        </button>
        <button
          type="button"
          data-testid="kanban-opportunity-close"
          class="flex p-0 size-8 items-center justify-center rounded-md text-n-slate-11 outline-none hover:bg-n-alpha-2 hover:text-n-slate-12 focus:ring-2 focus:ring-n-brand/40"
          :aria-label="t('KANBAN.OPPORTUNITY_DETAILS.CLOSE')"
          @click="requestClose"
        >
          <i class="i-lucide-x size-4" />
        </button>
      </div>
    </div>

    <div class="min-h-0 flex-1 overflow-auto px-5 py-4">
      <p
        v-if="isLoading"
        data-testid="kanban-opportunity-loading"
        class="mb-0 text-sm text-n-slate-11"
      >
        {{ t('KANBAN.OPPORTUNITY_DETAILS.LOADING') }}
      </p>

      <p
        v-else-if="loadError"
        data-testid="kanban-opportunity-load-error"
        class="mb-0 text-sm text-n-ruby-11"
        role="alert"
      >
        {{ loadError }}
      </p>

      <form
        v-else-if="card"
        data-testid="kanban-opportunity-form"
        class="grid gap-5"
        @submit.prevent="saveCard"
      >
        <nav
          ref="tabList"
          class="sticky top-0 z-10 flex min-w-0 flex-wrap gap-x-1 border-b border-n-weak bg-n-solid-1"
          :aria-label="t('KANBAN.OPPORTUNITY_DETAILS.TABS.LABEL')"
          role="tablist"
        >
          <button
            v-for="tab in opportunityTabs.filter(tab => tab.key !== 'timeline')"
            :id="`kanban-opportunity-tab-${tab.key}`"
            :key="tab.key"
            type="button"
            :data-testid="`kanban-opportunity-tab-${tab.key}`"
            class="border-solid whitespace-nowrap border-b-2 px-3 py-2.5 text-xs font-semibold focus:outline-none focus:ring-2 focus:ring-n-brand focus:ring-inset"
            role="tab"
            :aria-selected="activeTabKey === tab.key"
            aria-controls="kanban-opportunity-tab-panel"
            :class="
              activeTabKey === tab.key
                ? 'border-n-brand text-n-brand'
                : 'border-transparent text-n-slate-11 hover:text-n-slate-12'
            "
            @click="activeTabKey = tab.key"
            @keydown="handleTabKeydown"
          >
            {{ tab.label }}
          </button>
          <button
            v-if="canManageFields"
            type="button"
            data-testid="kanban-opportunity-add-tab"
            class="flex p-0 size-9 shrink-0 items-center justify-center border-b-2 border-transparent text-n-slate-11 hover:text-n-brand focus:outline-none focus:ring-2 focus:ring-n-brand/40 focus:ring-inset"
            :aria-label="t('KANBAN.OPPORTUNITY_DETAILS.ADD_TAB')"
            :title="t('KANBAN.OPPORTUNITY_DETAILS.ADD_TAB')"
            @click="emit('manageFields', { action: 'newTab' })"
          >
            <i class="i-lucide-plus size-4" />
          </button>
          <button
            :id="`kanban-opportunity-tab-${timelineTab.key}`"
            type="button"
            :data-testid="`kanban-opportunity-tab-${timelineTab.key}`"
            class="border-solid whitespace-nowrap border-b-2 px-3 py-2.5 text-xs font-semibold focus:outline-none focus:ring-2 focus:ring-n-brand focus:ring-inset"
            role="tab"
            :aria-selected="activeTabKey === timelineTab.key"
            aria-controls="kanban-opportunity-tab-panel"
            :class="
              activeTabKey === timelineTab.key
                ? 'border-n-brand text-n-brand'
                : 'border-transparent text-n-slate-11 hover:text-n-slate-12'
            "
            @click="activeTabKey = timelineTab.key"
            @keydown="handleTabKeydown"
          >
            {{ timelineTab.label }}
          </button>
        </nav>

        <div
          id="kanban-opportunity-tab-panel"
          data-testid="kanban-opportunity-layout"
          role="tabpanel"
          :aria-labelledby="`kanban-opportunity-tab-${activeTabKey}`"
          class="grid min-w-0 gap-4"
        >
          <section class="grid min-w-0 content-start gap-4">
            <template v-if="activeTabKey === 'details'">
              <section
                data-testid="kanban-opportunity-next-action-section"
                class="grid gap-2 border-b border-n-weak pb-3"
              >
                <div class="flex items-center justify-between gap-3">
                  <h3 class="mb-0 text-sm font-semibold text-n-slate-12">
                    {{ t('KANBAN.OPPORTUNITY_DETAILS.QUESTIONS.NEXT_ACTION') }}
                  </h3>
                  <NextButton
                    v-if="nextActionAt && !card.nextActionCompletedAt"
                    type="button"
                    xs
                    outline
                    emerald
                    data-testid="kanban-opportunity-complete-next-action"
                    icon="i-lucide-check-check"
                    :label="
                      t('KANBAN.OPPORTUNITY_DETAILS.COMPLETE_NEXT_ACTION')
                    "
                    :disabled="isSaving"
                    @click="completeNextAction"
                  />
                </div>
                <div class="grid">
                  <div class="grid">
                    <RaevoFieldRow
                      row-testid="kanban-row-next-action-type"
                      :label="t('KANBAN.OPPORTUNITY_DETAILS.NEXT_ACTION_TYPE')"
                      :value="nextActionTypeDisplay"
                      variant="select"
                    >
                      <template #control="{ controlClass, fieldId }">
                        <select
                          :id="fieldId"
                          v-model="nextActionType"
                          data-testid="kanban-opportunity-next-action-type"
                          :class="controlClass"
                        >
                          <option
                            v-for="option in nextActionTypeOptions"
                            :key="option.value || 'none'"
                            :value="option.value"
                          >
                            {{ option.label }}
                          </option>
                        </select>
                      </template>
                    </RaevoFieldRow>
                    <RaevoFieldRow
                      row-testid="kanban-row-next-action-at"
                      :label="t('KANBAN.OPPORTUNITY_DETAILS.NEXT_ACTION_AT')"
                      :value="nextActionAtDisplay"
                    >
                      <template #control="{ controlClass, fieldId }">
                        <input
                          :id="fieldId"
                          v-model="nextActionAt"
                          type="datetime-local"
                          data-testid="kanban-opportunity-next-action-at"
                          :class="controlClass"
                        />
                      </template>
                    </RaevoFieldRow>
                  </div>
                  <RaevoFieldRow
                    row-testid="kanban-row-next-action-note"
                    :label="t('KANBAN.OPPORTUNITY_DETAILS.NEXT_ACTION_NOTE')"
                    :value="nextActionNote"
                    variant="textarea"
                  >
                    <template #control="{ controlClass, fieldId }">
                      <textarea
                        :id="fieldId"
                        v-model="nextActionNote"
                        rows="2"
                        data-testid="kanban-opportunity-next-action-note"
                        :class="controlClass"
                        :placeholder="
                          t(
                            'KANBAN.OPPORTUNITY_DETAILS.NEXT_ACTION_NOTE_PLACEHOLDER'
                          )
                        "
                      />
                    </template>
                  </RaevoFieldRow>
                </div>
                <div
                  v-if="card.nextActionHistory?.length"
                  data-testid="kanban-opportunity-next-action-history"
                  class="grid gap-2 border-t border-n-weak pt-3"
                >
                  <h4 class="mb-0 text-xs font-medium text-n-slate-11">
                    {{ t('KANBAN.OPPORTUNITY_DETAILS.NEXT_ACTION_HISTORY') }}
                  </h4>
                  <div
                    v-for="(historyItem, index) in card.nextActionHistory
                      .slice()
                      .reverse()"
                    :key="`${historyItem.completedAt || historyItem.completed_at}-${index}`"
                    class="grid gap-0.5 text-xs text-n-slate-11"
                  >
                    <span class="font-medium text-n-slate-12">
                      {{ historyItem.type }}
                    </span>
                    <span v-if="historyItem.note">{{ historyItem.note }}</span>
                  </div>
                </div>
              </section>
              <section
                data-testid="kanban-opportunity-commercial-group"
                class="grid"
              >
                <!--
                  Bloco achatado: cada campo era uma <section> com título de
                  pergunta e borda própria, o que gastava a altura do painel e
                  transformava o separador em textura. Agora é rótulo acima do
                  campo, na mesma borda esquerda, com um separador só por grupo.
                -->
                <div class="grid py-2 first:pt-0">
                  <RaevoFieldRow
                    row-testid="kanban-row-owner"
                    :label="t('KANBAN.OPPORTUNITY_DETAILS.QUESTIONS.OWNER')"
                    :value="ownerDisplay"
                    variant="select"
                  >
                    <template #control="{ controlClass, fieldId }">
                      <select
                        :id="fieldId"
                        v-model="ownerId"
                        data-testid="kanban-opportunity-owner"
                        :class="controlClass"
                      >
                        <option value="">
                          {{ t('KANBAN.OPPORTUNITY_DETAILS.OWNER_NONE') }}
                        </option>
                        <option
                          v-for="option in ownerOptions"
                          :key="option.value"
                          :value="String(option.value)"
                        >
                          {{ option.label }}
                        </option>
                      </select>
                    </template>
                  </RaevoFieldRow>

                  <RaevoFieldRow
                    row-testid="kanban-row-description"
                    :label="t('KANBAN.OPPORTUNITY_DETAILS.QUESTIONS.AGREEMENT')"
                    :value="description"
                    variant="textarea"
                  >
                    <template #control="{ controlClass, fieldId }">
                      <textarea
                        :id="fieldId"
                        v-model="description"
                        rows="3"
                        data-testid="kanban-opportunity-description"
                        :class="controlClass"
                        :placeholder="
                          t(
                            'KANBAN.OPPORTUNITY_DETAILS.DESCRIPTION_PLACEHOLDER'
                          )
                        "
                      />
                    </template>
                  </RaevoFieldRow>

                  <div class="grid">
                    <RaevoFieldRow
                      row-testid="kanban-row-amount"
                      :label="t('KANBAN.OPPORTUNITY_DETAILS.FIELD_AMOUNT')"
                      :value="amountDisplay"
                      :hint="t('KANBAN.OPPORTUNITY_DETAILS.FIELD_AMOUNT_HINT')"
                    >
                      <template #control="{ controlClass, fieldId }">
                        <input
                          :id="fieldId"
                          v-model="amountValue"
                          data-testid="kanban-opportunity-amount"
                          type="number"
                          min="0"
                          step="0.01"
                          :class="controlClass"
                        />
                      </template>
                    </RaevoFieldRow>
                    <RaevoFieldRow
                      row-testid="kanban-row-expected-close-date"
                      :label="
                        t('KANBAN.OPPORTUNITY_DETAILS.EXPECTED_CLOSE_DATE')
                      "
                      :value="expectedCloseDateDisplay"
                    >
                      <template #control="{ controlClass, fieldId }">
                        <input
                          :id="fieldId"
                          v-model="expectedCloseDate"
                          data-testid="kanban-opportunity-expected-close-date"
                          type="date"
                          :class="controlClass"
                        />
                      </template>
                    </RaevoFieldRow>
                  </div>
                </div>
              </section>

              <section
                v-if="selectedStageIsLost"
                class="grid gap-2 rounded-lg border border-n-ruby-4 bg-n-ruby-2 p-3"
              >
                <label class="grid gap-1.5">
                  <span class="text-sm font-medium text-n-slate-12">
                    {{ t('KANBAN.OPPORTUNITY_DETAILS.LOST_REASON') }}
                  </span>
                  <select
                    v-model="lostReason"
                    data-testid="kanban-opportunity-lost-reason"
                    class="h-10 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                    @change="lostReasonError = ''"
                  >
                    <option value="">
                      {{
                        t('KANBAN.OPPORTUNITY_DETAILS.LOST_REASON_PLACEHOLDER')
                      }}
                    </option>
                    <option
                      v-for="option in selectableLostReasonOptions"
                      :key="option"
                      :value="option"
                    >
                      {{ option }}
                    </option>
                  </select>
                  <span
                    v-if="lostReasonError"
                    class="text-xs text-n-ruby-11"
                    role="alert"
                  >
                    {{ lostReasonError }}
                  </span>
                </label>
              </section>
            </template>

            <section
              v-if="activeTabKey === 'contact-details'"
              data-testid="kanban-opportunity-contact-details"
              class="grid gap-4"
            >
              <section class="grid gap-3 border-b border-n-weak pb-4">
                <div class="flex items-center justify-between gap-3">
                  <h3 class="mb-0 text-sm font-semibold text-n-slate-12">
                    {{ t('KANBAN.OPPORTUNITY_DETAILS.CONTACT') }}
                  </h3>
                  <button
                    type="button"
                    data-testid="kanban-opportunity-save-contact"
                    class="flex p-0 size-8 items-center justify-center rounded-md text-n-slate-11 outline-none hover:bg-n-alpha-2 hover:text-n-slate-12 focus:ring-2 focus:ring-n-brand/40 disabled:cursor-not-allowed disabled:opacity-50"
                    :disabled="isSavingContact || !card.contact?.id"
                    :aria-label="t('KANBAN.OPPORTUNITY_DETAILS.SAVE_CONTACT')"
                    :title="t('KANBAN.OPPORTUNITY_DETAILS.SAVE_CONTACT')"
                    @click="saveContact"
                  >
                    <i class="i-lucide-save size-4" />
                  </button>
                </div>
                <div class="grid gap-1">
                  <!--
                    O rótulo vivia só no placeholder: assim que o campo era
                    preenchido, deixava de haver forma de saber o que ele era.
                    Passa à mesma linha dos campos personalizados — rótulo à
                    esquerda, controlo à direita — para o diálogo deixar de ter
                    três tratamentos de campo.
                  -->
                  <RaevoFieldRow
                    v-for="detail in contactDetails"
                    :key="detail.key"
                    :row-testid="`kanban-row-contact-${detail.key}`"
                    :label="detail.label"
                    :value="detail.value || ''"
                  >
                    <template #control="{ controlClass, fieldId }">
                      <input
                        v-if="detail.key === 'name'"
                        :id="fieldId"
                        v-model="contactDraft.name"
                        data-testid="kanban-opportunity-contact-name"
                        type="text"
                        :class="controlClass"
                        :aria-label="detail.label"
                      />
                      <input
                        v-else-if="detail.key === 'phone'"
                        :id="fieldId"
                        v-model="contactDraft.phone_number"
                        data-testid="kanban-opportunity-contact-phone"
                        type="tel"
                        :class="controlClass"
                        :aria-label="detail.label"
                      />
                      <input
                        v-else-if="detail.key === 'email'"
                        :id="fieldId"
                        v-model="contactDraft.email"
                        data-testid="kanban-opportunity-contact-email"
                        type="email"
                        :class="controlClass"
                        :aria-label="detail.label"
                      />
                      <input
                        v-else
                        :id="fieldId"
                        v-model="contactDraft.identifier"
                        data-testid="kanban-opportunity-contact-identifier"
                        type="text"
                        :class="controlClass"
                        :aria-label="detail.label"
                      />
                    </template>
                  </RaevoFieldRow>
                </div>
                <p
                  v-if="contactSaveError"
                  class="mb-0 text-xs text-n-ruby-11"
                  role="alert"
                >
                  {{ contactSaveError }}
                </p>
                <!--
                  Etiquetas do contato, não da oportunidade. Chegam do WhatsApp
                  e valem para a pessoa em qualquer negócio; por isso são só de
                  leitura aqui — quem as edita é o WhatsApp ou a ficha do
                  contato. As da oportunidade vivem no botão do cabeçalho.
                -->
                <div v-if="contactLabels.length" class="grid gap-2">
                  <h4
                    class="mb-0 text-xs font-medium leading-4 text-n-slate-11"
                  >
                    {{ t('KANBAN.OPPORTUNITY_DETAILS.CONTACT_LABELS') }}
                  </h4>
                  <div
                    class="flex flex-wrap gap-1.5"
                    data-testid="kanban-opportunity-contact-labels"
                  >
                    <Label
                      v-for="label in contactLabels"
                      :key="label.title"
                      :label="label"
                      compact
                    />
                  </div>
                </div>
              </section>
              <section
                v-if="
                  visibleContactAttributes.length ||
                  availableContactAttributes.length
                "
                class="grid gap-3 border-b border-n-weak py-4 last:border-b-0"
              >
                <h3 class="mb-0 text-sm font-semibold text-n-slate-12">
                  {{ t('KANBAN.OPPORTUNITY_DETAILS.CONTACT_ATTRIBUTES') }}
                </h3>
                <div v-if="visibleContactAttributes.length" class="grid gap-1">
                  <RaevoFieldRow
                    v-for="entry in visibleContactAttributes"
                    :key="`${entry.source}-${entry.key}`"
                    :row-testid="`kanban-row-attr-${entry.key}`"
                    :label="entry.label"
                    :value="formatContactAttributeValue(entry.value)"
                  >
                    <template #control="{ controlClass, fieldId }">
                      <select
                        v-if="entry.displayType === 'list'"
                        :id="fieldId"
                        :value="entry.value ?? ''"
                        :class="controlClass"
                        :aria-label="entry.label"
                        @change="
                          setContactAttributeValue(entry, $event.target.value)
                        "
                      >
                        <option value="">
                          {{ t('KANBAN.OPPORTUNITY_DETAILS.ATTRIBUTE_EMPTY') }}
                        </option>
                        <option
                          v-for="option in entry.options"
                          :key="option"
                          :value="option"
                        >
                          {{ option }}
                        </option>
                      </select>
                      <!--
                        O rótulo ao lado já nomeia o campo. Repeti-lo aqui
                        desenhava o mesmo texto duas vezes na mesma linha.
                      -->
                      <span
                        v-else-if="entry.displayType === 'checkbox'"
                        class="flex h-10 items-center"
                      >
                        <input
                          :id="fieldId"
                          :checked="entry.value === true"
                          type="checkbox"
                          class="size-4 rounded border-n-weak text-n-brand focus:ring-n-brand"
                          @change="
                            setContactAttributeValue(
                              entry,
                              $event.target.checked
                            )
                          "
                        />
                      </span>
                      <input
                        v-else
                        :id="fieldId"
                        :value="entry.value ?? ''"
                        :type="entry.displayType === 'date' ? 'date' : 'text'"
                        :class="controlClass"
                        :aria-label="entry.label"
                        @input="
                          setContactAttributeValue(entry, $event.target.value)
                        "
                      />
                    </template>
                  </RaevoFieldRow>
                </div>
                <!--
                  Divulgacao progressiva: os campos vazios ficam atras deste
                  controlo para o bloco nao crescer com a conta, mas continuam
                  todos alcancaveis, inclusive por teclado.
                -->
                <div
                  v-if="availableContactAttributes.length"
                  class="flex items-end gap-2"
                >
                  <RaevoField
                    :label="t('KANBAN.OPPORTUNITY_DETAILS.ADD_ATTRIBUTE')"
                    variant="select"
                    class="flex-1"
                  >
                    <template #default="{ controlClass, fieldId }">
                      <select
                        :id="fieldId"
                        v-model="attributeToAdd"
                        data-testid="kanban-opportunity-add-attribute"
                        :class="controlClass"
                      >
                        <option value="">
                          {{
                            t(
                              'KANBAN.OPPORTUNITY_DETAILS.ADD_ATTRIBUTE_PLACEHOLDER'
                            )
                          }}
                        </option>
                        <option
                          v-for="entry in availableContactAttributes"
                          :key="`${entry.source}-${entry.key}`"
                          :value="entry.key"
                        >
                          {{ entry.label }}
                        </option>
                      </select>
                    </template>
                  </RaevoField>
                  <NextButton
                    :label="
                      t('KANBAN.OPPORTUNITY_DETAILS.ADD_ATTRIBUTE_ACTION')
                    "
                    :disabled="!attributeToAdd"
                    data-testid="kanban-opportunity-add-attribute-action"
                    faded
                    slate
                    sm
                    @click="revealContactAttribute"
                  />
                </div>
              </section>
            </section>

            <section
              v-if="activeTabKey === 'finance'"
              data-testid="kanban-opportunity-finance"
              class="grid gap-3"
            >
              <div
                class="flex items-start justify-between gap-3 border-b border-n-weak pb-3"
              >
                <div>
                  <h3 class="mb-0 text-sm font-semibold text-n-slate-12">
                    {{ t('FINANCE.PAYMENTS.TITLE') }}
                  </h3>
                  <p class="mb-0 mt-1 text-xs text-n-slate-11">
                    {{ t('FINANCE.PAYMENTS.DESCRIPTION') }}
                  </p>
                </div>
                <NextButton
                  v-if="
                    canCreateFinancePayment &&
                    connectedFinanceConnections.length
                  "
                  type="button"
                  sm
                  :label="t('FINANCE.PAYMENTS.CREATE')"
                  data-testid="kanban-opportunity-new-payment"
                  @click="openFinancePaymentDialog"
                />
              </div>

              <dl
                class="grid gap-3 rounded-md bg-n-alpha-2 p-3 sm:grid-cols-3"
                data-testid="kanban-opportunity-finance-summary"
              >
                <div class="min-w-0">
                  <dt class="text-xs font-medium text-n-slate-10">
                    {{ t('FINANCE.SUMMARY.STATUS') }}
                  </dt>
                  <dd
                    class="mb-0 mt-1 truncate text-sm font-semibold text-n-slate-12"
                  >
                    {{ financeStatusLabel(financeSummary.status) }}
                  </dd>
                </div>
                <div class="min-w-0">
                  <dt class="text-xs font-medium text-n-slate-10">
                    {{ t('FINANCE.SUMMARY.RECEIVED_AMOUNT') }}
                  </dt>
                  <dd
                    class="mb-0 mt-1 truncate text-sm font-semibold text-n-slate-12"
                  >
                    {{
                      formatFinanceAmount(
                        financeSummary.receivedCents,
                        financeSummary.currency
                      )
                    }}
                  </dd>
                </div>
                <div class="min-w-0">
                  <dt class="text-xs font-medium text-n-slate-10">
                    {{ t('FINANCE.SUMMARY.LAST_RECEIVED_AT') }}
                  </dt>
                  <dd
                    class="mb-0 mt-1 truncate text-sm font-semibold text-n-slate-12"
                  >
                    {{ formatFinanceDate(financeSummary.latestReceivedAt) }}
                  </dd>
                </div>
              </dl>

              <p v-if="isLoadingFinance" class="mb-0 text-sm text-n-slate-11">
                {{ t('KANBAN.OPPORTUNITY_DETAILS.LOADING') }}
              </p>
              <p
                v-else-if="financeError"
                class="mb-0 text-sm text-n-ruby-11"
                role="alert"
              >
                {{ financeError }}
              </p>
              <p
                v-else-if="financePayments.length === 0"
                class="mb-0 text-sm text-n-slate-11"
              >
                {{ t('FINANCE.PAYMENTS.EMPTY') }}
              </p>
              <div v-else class="grid divide-y divide-n-weak">
                <article
                  v-for="payment in financePayments"
                  :key="payment.id"
                  class="grid gap-2 py-3 sm:grid-cols-[minmax(0,1fr)_auto_auto] sm:items-center sm:gap-4"
                >
                  <div class="min-w-0">
                    <p
                      class="mb-0 truncate text-sm font-medium text-n-slate-12"
                    >
                      {{ payment.description || t('FINANCE.PAYMENTS.TITLE') }}
                    </p>
                    <p class="mb-0 mt-1 text-xs text-n-slate-11">
                      {{ payment.due_on || t('FINANCE.PAYMENTS.NO_DUE_DATE') }}
                    </p>
                  </div>
                  <span class="text-sm font-semibold text-n-slate-12">
                    {{ (payment.amount_cents / 100).toFixed(2) }}
                    {{ payment.currency }}
                  </span>
                  <div class="flex items-center gap-2">
                    <button
                      type="button"
                      data-testid="kanban-opportunity-payment-details"
                      class="flex p-0 size-7 items-center justify-center rounded-md text-n-slate-11 outline-none hover:bg-n-alpha-2 hover:text-n-slate-12 focus:ring-2 focus:ring-n-brand/40"
                      :aria-label="t('FINANCE.PAYMENTS.DETAIL.OPEN')"
                      :title="t('FINANCE.PAYMENTS.DETAIL.OPEN')"
                      @click="openFinancePaymentDetails(payment)"
                    >
                      <i class="i-lucide-history size-4" />
                    </button>
                    <a
                      v-if="payment.invoice_url"
                      :href="payment.invoice_url"
                      target="_blank"
                      rel="noopener noreferrer"
                      class="text-sm font-medium text-n-brand outline-none hover:underline focus:ring-2 focus:ring-n-brand/40"
                    >
                      {{ t('FINANCE.PAYMENTS.OPEN_LINK') }}
                    </a>
                    <button
                      v-if="payment.invoice_url"
                      type="button"
                      data-testid="kanban-opportunity-copy-payment-link"
                      class="flex p-0 size-7 items-center justify-center rounded-md text-n-slate-11 outline-none hover:bg-n-alpha-2 hover:text-n-slate-12 focus:ring-2 focus:ring-n-brand/40"
                      :aria-label="
                        copiedFinancePaymentId === payment.id
                          ? t('FINANCE.PAYMENTS.COPIED')
                          : t('FINANCE.PAYMENTS.COPY_LINK')
                      "
                      :title="
                        copiedFinancePaymentId === payment.id
                          ? t('FINANCE.PAYMENTS.COPIED')
                          : t('FINANCE.PAYMENTS.COPY_LINK')
                      "
                      @click="copyFinancePaymentLink(payment)"
                    >
                      <i
                        class="size-4"
                        :class="
                          copiedFinancePaymentId === payment.id
                            ? 'i-lucide-check'
                            : 'i-lucide-copy'
                        "
                      />
                    </button>
                    <button
                      v-if="hasConversation && payment.invoice_url"
                      type="button"
                      data-testid="kanban-opportunity-send-payment-link"
                      class="flex p-0 size-7 items-center justify-center rounded-md text-n-slate-11 outline-none hover:bg-n-alpha-2 hover:text-n-slate-12 focus:ring-2 focus:ring-n-brand/40"
                      :aria-label="t('FINANCE.PAYMENTS.SEND_TO_CONVERSATION')"
                      :title="t('FINANCE.PAYMENTS.SEND_TO_CONVERSATION')"
                      @click="sendFinancePaymentLink(payment)"
                    >
                      <i class="i-lucide-send size-4" />
                    </button>
                  </div>
                </article>
              </div>
            </section>

            <section
              v-if="activeTabKey === 'forms'"
              data-testid="kanban-opportunity-forms"
              class="grid gap-3"
            >
              <div
                class="flex items-start justify-between gap-3 border-b border-n-weak pb-3"
              >
                <div>
                  <h3 class="mb-0 text-sm font-semibold text-n-slate-12">
                    {{ t('FORMS.TITLE') }}
                  </h3>
                  <p class="mb-0 mt-1 text-xs text-n-slate-11">
                    {{ t('FORMS.INVITATION.DESCRIPTION') }}
                  </p>
                </div>
                <NextButton
                  type="button"
                  sm
                  :label="t('FORMS.INVITATION.OPEN')"
                  data-testid="kanban-opportunity-send-form"
                  @click="openFormsInvitationDialog"
                />
              </div>
              <p
                v-if="formsContextError"
                role="alert"
                class="mb-0 rounded border border-n-ruby-6 bg-n-ruby-2 px-3 py-2 text-sm text-n-ruby-11"
              >
                {{ formsContextError }}
              </p>
              <p
                v-else-if="isLoadingFormsContext"
                class="mb-0 text-sm text-n-slate-11"
              >
                {{ t('KANBAN.OPPORTUNITY_DETAILS.LOADING') }}
              </p>
              <template v-else>
                <section
                  v-if="formsContext.invitations.length"
                  class="grid gap-2"
                >
                  <h4
                    class="mb-0 text-xs font-semibold uppercase tracking-wide text-n-slate-10"
                  >
                    {{ t('FORMS.INVITATION.HISTORY') }}
                  </h4>
                  <article
                    v-for="invitation in formsContext.invitations"
                    :key="invitation.id"
                    class="flex items-center justify-between gap-3 rounded border border-n-weak px-3 py-2"
                  >
                    <div class="min-w-0">
                      <p
                        class="mb-0 break-words text-sm font-medium text-n-slate-12"
                      >
                        {{ invitation.form_name }}
                      </p>
                      <p class="mb-0 mt-0.5 text-xs text-n-slate-10">
                        {{
                          t('FORMS.INVITATION.USES', {
                            used: invitation.uses_count,
                            total: invitation.max_uses,
                          })
                        }}
                      </p>
                      <p
                        v-if="invitation.created_at"
                        class="mb-0 mt-0.5 text-xs text-n-slate-10"
                      >
                        {{
                          t('FORMS.INVITATION.CREATED_AT', {
                            date: formatFormInvitationDate(
                              invitation.created_at
                            ),
                          })
                        }}
                      </p>
                      <p
                        v-if="invitation.expires_at"
                        class="mb-0 mt-0.5 text-xs text-n-slate-10"
                      >
                        {{
                          t('FORMS.INVITATION.EXPIRES_ON', {
                            date: formatFormInvitationDate(
                              invitation.expires_at
                            ),
                          })
                        }}
                      </p>
                      <p
                        v-if="invitation.sent_at"
                        class="mb-0 mt-0.5 text-xs text-n-slate-10"
                      >
                        {{
                          t('FORMS.INVITATION.SENT_AT', {
                            date: formatFormInvitationDate(invitation.sent_at),
                          })
                        }}
                      </p>
                      <p
                        v-if="invitation.opened_at"
                        class="mb-0 mt-0.5 text-xs text-n-slate-10"
                      >
                        {{
                          t('FORMS.INVITATION.OPENED_AT', {
                            date: formatFormInvitationDate(
                              invitation.opened_at
                            ),
                          })
                        }}
                      </p>
                      <p
                        v-if="invitation.completed_at"
                        class="mb-0 mt-0.5 text-xs text-n-slate-10"
                      >
                        {{
                          t('FORMS.INVITATION.COMPLETED_AT', {
                            date: formatFormInvitationDate(
                              invitation.completed_at
                            ),
                          })
                        }}
                      </p>
                    </div>
                    <div class="flex shrink-0 items-center gap-1">
                      <span
                        :data-testid="`kanban-opportunity-form-invitation-status-${invitation.id}`"
                        class="text-xs text-n-slate-11"
                      >
                        {{ formInvitationStatusLabel(invitation.status) }}
                      </span>
                      <button
                        v-if="
                          canCreateFormInvitation &&
                          invitation.status === 'active'
                        "
                        type="button"
                        :data-testid="`kanban-opportunity-revoke-form-invitation-${invitation.id}`"
                        class="flex p-0 size-7 items-center justify-center rounded-md text-n-slate-11 outline-none hover:bg-n-ruby-3 hover:text-n-ruby-11 focus:ring-2 focus:ring-n-ruby-8"
                        :aria-label="t('FORMS.INVITATION.REVOKE')"
                        :title="t('FORMS.INVITATION.REVOKE')"
                        @click="requestFormInvitationRevocation(invitation)"
                      >
                        <i class="i-lucide-ban size-3.5" />
                      </button>
                    </div>
                  </article>
                </section>
                <section
                  v-if="formsContext.submissions.length"
                  class="grid gap-2"
                >
                  <h4
                    class="mb-0 text-xs font-semibold uppercase tracking-wide text-n-slate-10"
                  >
                    {{ t('FORMS.SUBMISSIONS.HISTORY') }}
                  </h4>
                  <KanbanFormSubmissionRow
                    v-for="submission in formsContext.submissions"
                    :key="submission.id"
                    :submission="submission"
                    :resolving-action="resolvingAction"
                    :pending-action-error="pendingActionError"
                    @open="openFormsSubmission"
                    @resolve="onResolvePendingAction"
                  />
                </section>
                <!--
                  O que a pessoa respondeu noutras oportunidades e continua a
                  valer para ela. Separado de propósito: são formulários do
                  doente, não deste negócio.
                -->
                <section
                  v-if="formsContext.contact_submissions?.length"
                  data-testid="kanban-opportunity-contact-forms"
                  class="grid gap-2"
                >
                  <h4
                    class="mb-0 text-xs font-semibold uppercase tracking-wide text-n-slate-10"
                  >
                    {{ t('FORMS.SUBMISSIONS.CONTACT_HISTORY') }}
                  </h4>
                  <p class="mb-0 text-xs text-n-slate-10">
                    {{ t('FORMS.SUBMISSIONS.CONTACT_HISTORY_HINT') }}
                  </p>
                  <KanbanFormSubmissionRow
                    v-for="submission in formsContext.contact_submissions"
                    :key="submission.id"
                    :submission="submission"
                    :resolving-action="resolvingAction"
                    :pending-action-error="pendingActionError"
                    @open="openFormsSubmission"
                    @resolve="onResolvePendingAction"
                  />
                </section>
                <p
                  v-if="
                    !formsContext.invitations.length &&
                    !formsContext.submissions.length &&
                    !formsContext.contact_submissions?.length
                  "
                  class="mb-0 text-sm text-n-slate-10"
                >
                  {{ t('FORMS.INVITATION.HISTORY_EMPTY') }}
                </p>
              </template>
            </section>

            <section
              v-if="activeTabKey === 'timeline'"
              data-testid="kanban-opportunity-timeline"
              class="grid gap-3"
            >
              <p v-if="isLoadingTimeline" class="mb-0 text-sm text-n-slate-11">
                {{ t('KANBAN.OPPORTUNITY_DETAILS.LOADING') }}
              </p>
              <p
                v-else-if="timelineError"
                class="mb-0 text-sm text-n-ruby-11"
                role="alert"
              >
                {{ timelineError }}
              </p>
              <p
                v-else-if="timeline.length === 0"
                class="mb-0 text-sm text-n-slate-11"
              >
                {{ t('KANBAN.OPPORTUNITY_DETAILS.TIMELINE.EMPTY') }}
              </p>
              <template v-else>
                <article
                  v-for="event in timeline"
                  :key="event.id"
                  class="grid gap-1 border-b border-n-weak pb-3 last:border-0"
                >
                  <strong class="text-sm text-n-slate-12">
                    {{ timelineEventLabel(event) }}
                  </strong>
                  <span class="text-xs text-n-slate-11">
                    {{ timelineEventMeta(event) }}
                  </span>
                  <div
                    v-for="automation in event.automations || []"
                    :key="automation.id"
                    class="mt-1 grid gap-1 rounded-md bg-n-surface-2 px-2 py-1.5 text-xs text-n-slate-11"
                  >
                    <span class="font-medium text-n-slate-12">
                      {{ automation.rule_name }}
                    </span>
                    <span>
                      {{ automation.status }}
                      <template v-if="automation.scheduled_at">
                        {{
                          ` - ${new Date(
                            automation.scheduled_at
                          ).toLocaleString()}`
                        }}
                      </template>
                    </span>
                    <span
                      v-if="automation.error_message"
                      class="text-n-ruby-11"
                    >
                      {{ automation.error_message }}
                    </span>
                  </div>
                </article>
              </template>
            </section>

            <section
              v-if="hasCustomFields"
              data-testid="kanban-opportunity-custom-fields"
              class="grid"
            >
              <div class="grid">
                <section
                  v-for="group in activeTabGroups"
                  :key="group.key"
                  class="grid gap-2 border-b border-n-weak py-3 first:pt-0 last:border-b-0 last:pb-0"
                  :class="
                    group.label
                      ? ['border-l-2 pl-3', customFieldGroupClass(group.color)]
                      : ''
                  "
                >
                  <button
                    v-if="group.label"
                    type="button"
                    class="flex items-center justify-between gap-3 text-left"
                    :aria-expanded="
                      isGroupExpanded(groupToggleKey(activeTabKey, group.key))
                    "
                    @click="
                      toggleGroup(groupToggleKey(activeTabKey, group.key))
                    "
                  >
                    <span class="text-sm font-semibold text-n-slate-12">
                      {{ group.label }}
                    </span>
                    <i
                      class="size-4 text-n-slate-10"
                      :class="
                        isGroupExpanded(groupToggleKey(activeTabKey, group.key))
                          ? 'i-lucide-chevron-up'
                          : 'i-lucide-chevron-down'
                      "
                    />
                  </button>
                  <div
                    v-show="
                      !group.label ||
                      isGroupExpanded(groupToggleKey(activeTabKey, group.key))
                    "
                    class="grid gap-x-4 sm:grid-cols-2"
                  >
                    <!--
                      Uma linha só, em todo o painel. Os campos personalizados
                      desenhavam a sua própria — rótulo de 9rem, outro
                      espaçamento, sempre em edição — enquanto os nativos usavam
                      o `RaevoFieldRow`. Passam ao mesmo componente, e com ele
                      ganham o mesmo repouso e a mesma entrada em edição.
                    -->
                    <RaevoFieldRow
                      v-for="definition in group.definitions"
                      :key="definition.key"
                      :class="customFieldSpanClass(definition)"
                      :row-testid="`kanban-row-${definition.key}`"
                      :label="definition.label"
                      :value="customFieldDisplayValue(definition)"
                      :variant="customFieldRowVariant(definition)"
                    >
                      <template #control="{ controlClass, fieldId }">
                        <select
                          v-if="definition.fieldType === 'select'"
                          :id="fieldId"
                          :value="getCustomFieldValue(definition)"
                          :data-testid="`kanban-custom-field-${definition.key}`"
                          :class="controlClass"
                          :aria-label="definition.label"
                          @change="
                            setCustomFieldValue(definition, $event.target.value)
                          "
                        >
                          <!--
                              A opção vazia mostrava o rótulo do campo, e a linha
                              lia-se «Consulta realizada? | Consulta realizada?» —
                              impossível distinguir por preencher de preenchido.
                            -->
                          <option value="">
                            {{ t('KANBAN.OPPORTUNITY_DETAILS.FIELD_EMPTY') }}
                          </option>
                          <option
                            v-for="option in definition.options || []"
                            :key="option"
                            :value="option"
                          >
                            {{ option }}
                          </option>
                        </select>

                        <select
                          v-else-if="definition.fieldType === 'multiselect'"
                          :id="fieldId"
                          multiple
                          :value="getCustomFieldValue(definition)"
                          :data-testid="`kanban-custom-field-${definition.key}`"
                          :class="controlClass"
                          :aria-label="definition.label"
                          @change="
                            setCustomFieldValue(
                              definition,
                              selectedMultiselectValues($event)
                            )
                          "
                        >
                          <option
                            v-for="option in definition.options || []"
                            :key="option"
                            :value="option"
                          >
                            {{ option }}
                          </option>
                        </select>

                        <textarea
                          v-else-if="definition.fieldType === 'textarea'"
                          :id="fieldId"
                          :value="getCustomFieldValue(definition)"
                          rows="3"
                          :data-testid="`kanban-custom-field-${definition.key}`"
                          :class="controlClass"
                          :aria-label="definition.label"
                          @input="
                            setCustomFieldValue(definition, $event.target.value)
                          "
                        />

                        <input
                          v-else-if="definition.fieldType === 'boolean'"
                          :id="fieldId"
                          type="checkbox"
                          :checked="Boolean(getCustomFieldValue(definition))"
                          :data-testid="`kanban-custom-field-${definition.key}`"
                          class="size-4 rounded border-n-weak text-n-brand focus:ring-n-brand"
                          :aria-label="definition.label"
                          @change="
                            setCustomFieldValue(
                              definition,
                              $event.target.checked
                            )
                          "
                        />

                        <input
                          v-else
                          :id="fieldId"
                          :value="getCustomFieldValue(definition)"
                          :type="
                            definition.fieldType === 'integer' ||
                            definition.fieldType === 'decimal' ||
                            definition.fieldType === 'currency' ||
                            definition.fieldType === 'formula'
                              ? 'number'
                              : definition.fieldType === 'date'
                                ? 'date'
                                : definition.fieldType === 'datetime'
                                  ? 'datetime-local'
                                  : definition.fieldType === 'url'
                                    ? 'url'
                                    : 'text'
                          "
                          :step="
                            definition.fieldType === 'decimal'
                              ? '0.01'
                              : undefined
                          "
                          :disabled="definition.fieldType === 'formula'"
                          :data-testid="`kanban-custom-field-${definition.key}`"
                          class="h-8 min-w-0 border-0 bg-transparent px-0 text-sm text-n-slate-12 outline-none disabled:opacity-70 focus:ring-2 focus:ring-n-brand/40"
                          :aria-label="definition.label"
                          @input="
                            setCustomFieldValue(definition, $event.target.value)
                          "
                        />
                      </template>
                    </RaevoFieldRow>
                  </div>
                </section>
              </div>
            </section>
          </section>

          <section
            v-if="
              activeTabKey === 'details' ||
              activeTabKey === 'contact-details' ||
              activeTabKey === 'calendar'
            "
            class="grid min-w-0 content-start gap-3"
          >
            <KanbanCalendarAppointmentsSection
              v-if="activeTabKey === 'calendar' && calendarEnabled"
              :card-id="card.id"
              :contact-id="card.contact?.id"
              :contact-name="contactName"
              :booking-stage="
                calendarBookingStageIds.map(Number).includes(Number(stageId))
              "
              :allowed-procedure-ids="calendarProcedureIds"
            />

            <section
              v-if="activeTabKey === 'details'"
              class="grid gap-3 border-b border-n-weak py-3"
            >
              <button
                type="button"
                class="flex items-center justify-between gap-3 text-left"
                :aria-expanded="isGroupExpanded('organization')"
                @click="toggleGroup('organization')"
              >
                <span class="text-sm font-medium text-n-slate-12">
                  {{ t('KANBAN.OPPORTUNITY_DETAILS.INTERNAL_DATES') }}
                </span>
                <i
                  class="size-4 text-n-slate-10"
                  :class="
                    isGroupExpanded('organization')
                      ? 'i-lucide-chevron-up'
                      : 'i-lucide-chevron-down'
                  "
                />
              </button>
              <div v-show="isGroupExpanded('organization')" class="grid gap-2">
                <p class="mb-0 text-xs text-n-slate-11">
                  {{ t('KANBAN.OPPORTUNITY_DETAILS.INTERNAL_DATES_HELP') }}
                </p>
                <div class="grid">
                  <div
                    class="grid grid-cols-[9rem_1fr] items-center gap-3 border-b border-n-weak py-2"
                  >
                    <span class="text-xs text-n-slate-11">
                      {{ t('KANBAN.OPPORTUNITY_DETAILS.START_DATE') }}
                    </span>
                    <NextInput
                      v-model="startsAt"
                      type="datetime-local"
                      data-testid="kanban-opportunity-starts-at"
                      class="w-full [&_input]:h-8 [&_input]:border-0 [&_input]:bg-transparent [&_input]:px-0 [&_input]:focus:ring-2 [&_input]:focus:ring-n-brand/40"
                      :aria-label="t('KANBAN.OPPORTUNITY_DETAILS.START_DATE')"
                    />
                  </div>
                  <div
                    class="grid grid-cols-[9rem_1fr] items-center gap-3 py-2"
                  >
                    <span class="text-xs text-n-slate-11">
                      {{ t('KANBAN.OPPORTUNITY_DETAILS.DUE_DATE') }}
                    </span>
                    <NextInput
                      v-model="dueAt"
                      type="datetime-local"
                      data-testid="kanban-opportunity-due-at"
                      class="w-full [&_input]:h-8 [&_input]:border-0 [&_input]:bg-transparent [&_input]:px-0 [&_input]:focus:ring-2 [&_input]:focus:ring-n-brand/40"
                      :aria-label="t('KANBAN.OPPORTUNITY_DETAILS.DUE_DATE')"
                    />
                  </div>
                </div>
              </div>
            </section>
          </section>
        </div>

        <p
          v-if="saveError"
          data-testid="kanban-opportunity-save-error"
          class="mb-0 text-sm text-n-ruby-11"
          role="alert"
        >
          {{ saveError }}
        </p>

        <div
          class="sticky bottom-0 z-20 -mx-1 flex items-center justify-end gap-3 border-t border-n-weak bg-n-background px-1 pb-4 pt-4"
        >
          <NextButton
            type="button"
            outline
            slate
            sm
            data-testid="kanban-opportunity-cancel"
            :label="t('KANBAN.OPPORTUNITY_DETAILS.CANCEL')"
            @click="requestClose"
          />
          <NextButton
            type="submit"
            sm
            data-testid="kanban-opportunity-save"
            icon="i-lucide-save"
            :label="
              isSaving
                ? t('KANBAN.OPPORTUNITY_DETAILS.SAVING')
                : t('KANBAN.OPPORTUNITY_DETAILS.SAVE')
            "
            :disabled="isSaving"
            :is-loading="isSaving"
          />
        </div>
      </form>
    </div>

    <FinancePaymentDialog
      v-if="financeEnabled && card"
      ref="paymentDialog"
      :connections="financeConnections"
      :contact="card.contact"
      :kanban-card-id="card.id"
      :market="financeModule.market"
      @created="addFinancePayment"
    />
    <FinancePaymentDetailsDialog
      v-if="financeEnabled && card"
      ref="paymentDetailsDialog"
      :can-manage="canManageFinancePayments"
      :can-refund="canRefundFinancePayments"
      @canceled="updateFinancePayment"
      @received="updateFinancePayment"
      @refund-requested="updateFinancePayment"
    />
    <FormsInvitationDialog
      v-if="
        activeTabKey === 'forms' && canCreateFormInvitation && card?.contact
      "
      ref="formsInvitationDialog"
      :contact="card.contact"
      :kanban-card-id="card.id"
      :can-send-to-conversation="hasConversation"
      @created="loadFormsContext"
      @send="sendFormsInvitationLink"
    />
    <FormsSubmissionDetailsDialog
      v-if="activeTabKey === 'forms'"
      ref="formsSubmissionDialog"
    />
    <div
      v-if="invitationPendingRevocation"
      class="absolute inset-0 z-20 grid place-items-center bg-black/20 p-4"
      role="presentation"
    >
      <section
        class="grid w-full max-w-sm gap-4 rounded-lg border border-n-weak bg-n-solid-1 p-5 shadow-lg"
        role="alertdialog"
        aria-modal="true"
        aria-labelledby="kanban-form-invitation-revoke-title"
        @keydown.stop="trapModalFocus"
      >
        <div>
          <h3
            id="kanban-form-invitation-revoke-title"
            class="mb-1 text-base font-semibold text-n-slate-12"
          >
            {{ t('FORMS.INVITATION.REVOKE_TITLE') }}
          </h3>
          <p class="mb-0 text-sm text-n-slate-11">
            {{ t('FORMS.INVITATION.REVOKE_DESCRIPTION') }}
          </p>
        </div>
        <div class="flex justify-end gap-2">
          <button
            type="button"
            data-testid="kanban-opportunity-cancel-form-invitation-revocation"
            class="rounded-md px-3 py-2 text-sm font-medium text-n-slate-11 outline-none hover:bg-n-alpha-2 focus:ring-2 focus:ring-n-brand/40"
            :disabled="isRevokingFormInvitation"
            @click="invitationPendingRevocation = null"
          >
            {{ t('KANBAN.OPPORTUNITY_DETAILS.CANCEL') }}
          </button>
          <button
            ref="formInvitationRevocationConfirmButton"
            type="button"
            data-testid="form-invitation-revoke-confirm"
            class="rounded-md bg-n-ruby-9 px-3 py-2 text-sm font-medium text-white outline-none hover:bg-n-ruby-10 focus:ring-2 focus:ring-n-ruby-8 disabled:cursor-not-allowed disabled:opacity-50"
            :disabled="isRevokingFormInvitation"
            @click="revokeFormInvitation"
          >
            {{ t('FORMS.INVITATION.REVOKE') }}
          </button>
        </div>
      </section>
    </div>

    <div
      v-if="showUnsavedChanges"
      data-testid="kanban-opportunity-unsaved-changes"
      class="absolute inset-0 z-20 grid place-items-center bg-black/20 p-4"
      role="presentation"
    >
      <section
        class="grid w-full max-w-sm gap-4 rounded-lg border border-n-weak bg-n-solid-1 p-5 shadow-lg"
        role="alertdialog"
        aria-modal="true"
        aria-labelledby="kanban-unsaved-title"
        @keydown.stop="trapModalFocus"
      >
        <div>
          <h3
            id="kanban-unsaved-title"
            class="mb-1 text-base font-semibold text-n-slate-12"
          >
            {{ t('KANBAN.OPPORTUNITY_DETAILS.UNSAVED_CHANGES.TITLE') }}
          </h3>
          <p class="mb-0 text-sm text-n-slate-11">
            {{ t('KANBAN.OPPORTUNITY_DETAILS.UNSAVED_CHANGES.DESCRIPTION') }}
          </p>
        </div>
        <div class="flex justify-end gap-2">
          <button
            ref="keepEditingButton"
            type="button"
            data-testid="kanban-opportunity-keep-editing"
            class="rounded-md px-3 py-2 text-sm font-medium text-n-slate-11 outline-none hover:bg-n-alpha-2 focus:ring-2 focus:ring-n-brand/40"
            @click="keepEditing"
          >
            {{ t('KANBAN.OPPORTUNITY_DETAILS.UNSAVED_CHANGES.KEEP_EDITING') }}
          </button>
          <button
            type="button"
            data-testid="kanban-opportunity-discard-changes"
            class="rounded-md bg-n-ruby-9 px-3 py-2 text-sm font-medium text-white outline-none hover:bg-n-ruby-10 focus:ring-2 focus:ring-n-ruby-8"
            @click="discardChanges"
          >
            {{ t('KANBAN.OPPORTUNITY_DETAILS.UNSAVED_CHANGES.DISCARD') }}
          </button>
        </div>
      </section>
    </div>

    <div
      v-if="pendingPipelineTransfer"
      class="absolute inset-0 z-20 grid place-items-center bg-black/20 p-4"
      role="presentation"
    >
      <section
        class="grid w-full max-w-sm gap-4 rounded-lg border border-n-weak bg-n-solid-1 p-5 shadow-lg"
        role="dialog"
        aria-modal="true"
        aria-labelledby="kanban-transfer-loss-title"
      >
        <div>
          <h3
            id="kanban-transfer-loss-title"
            class="mb-1 text-base font-semibold text-n-slate-12"
          >
            {{ t('KANBAN.OPPORTUNITY_DETAILS.TRANSFER_LOSS.TITLE') }}
          </h3>
          <p class="mb-0 text-sm text-n-slate-11">
            {{
              t('KANBAN.OPPORTUNITY_DETAILS.TRANSFER_LOSS.DESCRIPTION', {
                stage: pendingPipelineTransfer.stage.name,
              })
            }}
          </p>
        </div>
        <label class="grid gap-1.5">
          <span class="text-sm font-medium text-n-slate-12">
            {{ t('KANBAN.OPPORTUNITY_DETAILS.LOST_REASON') }}
          </span>
          <select
            v-model="pendingPipelineTransfer.lostReason"
            data-testid="kanban-opportunity-transfer-lost-reason"
            class="h-10 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
          >
            <option value="">
              {{ t('KANBAN.OPPORTUNITY_DETAILS.LOST_REASON_PLACEHOLDER') }}
            </option>
            <option
              v-for="option in selectableLostReasonOptions"
              :key="option"
              :value="option"
            >
              {{ option }}
            </option>
          </select>
        </label>
        <div class="flex justify-end gap-2">
          <button
            type="button"
            class="rounded-md px-3 py-2 text-sm font-medium text-n-slate-11 outline-none hover:bg-n-alpha-2 focus:ring-2 focus:ring-n-brand/40"
            @click="pendingPipelineTransfer = null"
          >
            {{ t('KANBAN.OPPORTUNITY_DETAILS.CANCEL') }}
          </button>
          <button
            type="button"
            data-testid="kanban-opportunity-confirm-transfer"
            class="rounded-md bg-n-ruby-9 px-3 py-2 text-sm font-medium text-white outline-none hover:bg-n-ruby-10 focus:ring-2 focus:ring-n-ruby-8 disabled:opacity-50"
            :disabled="isSaving || !pendingPipelineTransfer.lostReason.trim()"
            @click="confirmPipelineTransfer"
          >
            {{ t('KANBAN.OPPORTUNITY_DETAILS.TRANSFER_LOSS.CONFIRM') }}
          </button>
        </div>
      </section>
    </div>
  </div>
</template>
