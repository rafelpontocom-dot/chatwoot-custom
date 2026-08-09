<script setup>
import { computed, nextTick, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';

import KanbanBoardsAPI from 'dashboard/api/kanbanBoards';
import NextButton from 'dashboard/components-next/button/Button.vue';
import NextInput from 'dashboard/components-next/input/Input.vue';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import KanbanCalendarAppointmentsSection from './KanbanCalendarAppointmentsSection.vue';

const props = defineProps({
  boardId: {
    type: [Number, String],
    required: true,
  },
  boardName: {
    type: String,
    default: '',
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
  'manageFields',
]);

const { t } = useI18n();
const store = useStore();
const accountLabels = useMapGetter('labels/getLabels');

const card = ref(null);
const subject = ref('');
const description = ref('');
const ownerId = ref('');
const stageId = ref('');
const amountValue = ref('');
const amountCurrency = ref('BRL');
const expectedCloseDate = ref('');
const customFieldValues = ref({});
const timeline = ref([]);
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
const activeTabKey = ref('details');
const expandedGroupKeys = ref({
  commercial: true,
  nextAction: true,
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
const conversationAssignee = computed(
  () => card.value?.conversation?.meta?.assignee || card.value?.assignee
);
const assigneeName = computed(
  () =>
    conversationAssignee.value?.name ||
    t('KANBAN.OPPORTUNITY_DETAILS.UNASSIGNED')
);
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
const selectedStageIsLost = computed(
  () => selectedStage.value?.category === 'lost'
);
const contactDetails = computed(() => {
  const contact = card.value?.contact || {};

  return [
    {
      key: 'name',
      label: t('KANBAN.OPPORTUNITY_DETAILS.CONTACT_NAME'),
      value: contact.name,
    },
    {
      key: 'phone',
      label: t('KANBAN.OPPORTUNITY_DETAILS.CONTACT_PHONE'),
      value: contact.phone_number,
    },
    {
      key: 'email',
      label: t('KANBAN.OPPORTUNITY_DETAILS.CONTACT_EMAIL'),
      value: contact.email,
    },
    {
      key: 'identifier',
      label: t('KANBAN.OPPORTUNITY_DETAILS.CONTACT_IDENTIFIER'),
      value: contact.identifier,
    },
  ].filter(detail => detail.value);
});
const contactAttributeEntries = computed(() => {
  const contact = card.value?.contact || {};
  const attributes = {
    ...(contact.additional_attributes || {}),
    ...(contact.custom_attributes || {}),
  };

  return Object.entries(attributes).filter(
    ([, value]) => value !== '' && value !== null && value !== undefined
  );
});
const formatContactAttributeLabel = key =>
  String(key)
    .replace(/[_-]+/g, ' ')
    .replace(/^./, character => character.toUpperCase());
const formatContactAttributeValue = value => {
  if (Array.isArray(value)) return value.join(', ');
  if (typeof value === 'boolean') {
    return value
      ? t('KANBAN.OPPORTUNITY_DETAILS.CONTACT_VALUE_TRUE')
      : t('KANBAN.OPPORTUNITY_DETAILS.CONTACT_VALUE_FALSE');
  }

  return String(value);
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
    {
      key: 'agent-details',
      label: t('KANBAN.OPPORTUNITY_DETAILS.ASSIGNEE'),
    },
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
    groups.push({
      key: 'ungrouped',
      label: t('KANBAN.OPPORTUNITY_DETAILS.UNGROUPED_FIELDS'),
      color: 'slate',
      definitions: ungrouped,
    });
  }

  return groups.filter(group => group.definitions.length);
});
const customFieldGroupClass = color =>
  ({
    slate: 'border-n-weak bg-n-surface-2',
    blue: 'border-n-blue-4 bg-n-blue-2',
    teal: 'border-n-teal-4 bg-n-teal-2',
    green: 'border-green-200 bg-green-50',
    amber: 'border-n-amber-4 bg-n-amber-2',
    orange: 'border-orange-200 bg-orange-50',
    ruby: 'border-n-ruby-4 bg-n-ruby-2',
    rose: 'border-rose-200 bg-rose-50',
    violet: 'border-n-violet-4 bg-n-violet-2',
    iris: 'border-n-iris-4 bg-n-iris-2',
  })[color] || 'border-n-weak bg-n-surface-2';
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
const setCustomFieldValue = (definition, value) => {
  customFieldValues.value = {
    ...customFieldValues.value,
    [definition.key]: value,
  };
};
const customFieldLayoutClass = definition => {
  const width = definition.layout?.width || 'full';
  return {
    full: 'md:col-span-6',
    half: 'md:col-span-3',
    third: 'md:col-span-2',
  }[width];
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
  subject.value = card.value.subject || '';
  description.value = card.value.description || '';
  ownerId.value = card.value.ownerId ? String(card.value.ownerId) : '';
  stageId.value = card.value.kanbanStageId
    ? String(card.value.kanbanStageId)
    : '';
  amountValue.value = formatAmountInput(card.value.amountCents);
  amountCurrency.value = card.value.amountCurrency || 'BRL';
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
  amount_currency: amountCurrency.value || 'BRL',
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
});

watch(showUnsavedChanges, async visible => {
  if (!visible) return;

  await nextTick();
  keepEditingButton.value?.focus();
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
          <span
            class="max-w-32 truncate border-l border-n-weak pl-2 text-xs text-n-slate-11"
          >
            {{ boardName }}
          </span>
          <select
            v-model="stageId"
            data-testid="kanban-opportunity-header-stage"
            class="h-7 max-w-44 rounded-md border border-n-weak bg-n-surface-1 px-2 text-xs font-medium text-n-slate-12 outline-none focus:border-n-brand focus:ring-2 focus:ring-n-brand/20"
            :aria-label="t('KANBAN.OPPORTUNITY_DETAILS.STAGE')"
          >
            <option
              v-for="stage in stages"
              :key="stage.id"
              :value="String(stage.id)"
            >
              {{ stage.name }}
            </option>
          </select>
        </div>
      </div>
      <div class="flex flex-shrink-0 items-center gap-1">
        <button
          v-if="hasConversation"
          type="button"
          data-testid="kanban-opportunity-header-open-conversation"
          class="flex size-8 items-center justify-center rounded-md text-n-slate-11 outline-none hover:bg-n-alpha-2 hover:text-n-slate-12 focus:ring-2 focus:ring-n-brand/40"
          :aria-label="t('KANBAN.OPPORTUNITY_DETAILS.OPEN_CONVERSATION')"
          :title="t('KANBAN.OPPORTUNITY_DETAILS.OPEN_CONVERSATION')"
          @click="openConversation"
        >
          <i class="i-lucide-message-square size-4" />
        </button>
        <button
          type="button"
          data-testid="kanban-opportunity-edit-subject"
          class="flex size-8 items-center justify-center rounded-md text-n-slate-11 outline-none hover:bg-n-alpha-2 hover:text-n-slate-12 focus:ring-2 focus:ring-n-brand/40"
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
          class="flex size-8 items-center justify-center rounded-md text-n-slate-11 outline-none hover:bg-n-alpha-2 hover:text-n-slate-12 focus:ring-2 focus:ring-n-brand/40"
          :aria-label="t('KANBAN.OPPORTUNITY_DETAILS.MANAGE_FIELDS')"
          :title="t('KANBAN.OPPORTUNITY_DETAILS.MANAGE_FIELDS')"
          @click="emit('manageFields')"
        >
          <i class="i-lucide-settings-2 size-4" />
        </button>
        <button
          type="button"
          data-testid="kanban-opportunity-close"
          class="flex size-8 items-center justify-center rounded-md text-n-slate-11 outline-none hover:bg-n-alpha-2 hover:text-n-slate-12 focus:ring-2 focus:ring-n-brand/40"
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
          class="sticky top-0 z-10 flex min-w-0 gap-1 overflow-x-auto border-b border-n-weak bg-n-background"
          :aria-label="t('KANBAN.OPPORTUNITY_DETAILS.TABS.LABEL')"
          role="tablist"
        >
          <button
            v-for="tab in opportunityTabs.filter(tab => tab.key !== 'timeline')"
            :id="`kanban-opportunity-tab-${tab.key}`"
            :key="tab.key"
            type="button"
            :data-testid="`kanban-opportunity-tab-${tab.key}`"
            class="whitespace-nowrap border-b-2 px-3 py-2 text-sm font-medium focus:outline-none focus:ring-2 focus:ring-n-brand/40 focus:ring-inset"
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
            class="flex size-9 shrink-0 items-center justify-center border-b-2 border-transparent text-n-slate-11 hover:text-n-brand focus:outline-none focus:ring-2 focus:ring-n-brand/40 focus:ring-inset"
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
            class="whitespace-nowrap border-b-2 px-3 py-2 text-sm font-medium focus:outline-none focus:ring-2 focus:ring-n-brand/40 focus:ring-inset"
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
                data-testid="kanban-opportunity-commercial-group"
                class="grid gap-3 rounded-lg border border-n-weak bg-n-surface-2 p-3"
              >
                <button
                  type="button"
                  class="flex items-center justify-between gap-3 text-left"
                  :aria-expanded="isGroupExpanded('commercial')"
                  @click="toggleGroup('commercial')"
                >
                  <span class="text-sm font-semibold text-n-slate-12">
                    {{ t('KANBAN.OPPORTUNITY_DETAILS.GROUPS.COMMERCIAL') }}
                  </span>
                  <i
                    class="size-4 text-n-slate-10"
                    :class="
                      isGroupExpanded('commercial')
                        ? 'i-lucide-chevron-up'
                        : 'i-lucide-chevron-down'
                    "
                  />
                </button>
                <div v-show="isGroupExpanded('commercial')" class="grid gap-3">
                  <label class="grid gap-1.5">
                    <span class="text-sm font-medium text-n-slate-12">
                      {{ t('KANBAN.OPPORTUNITY_DETAILS.OWNER') }}
                    </span>
                    <select
                      v-model="ownerId"
                      data-testid="kanban-opportunity-owner"
                      class="h-10 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                    >
                      <option value="">
                        {{ t('KANBAN.OPPORTUNITY_DETAILS.UNASSIGNED') }}
                      </option>
                      <option
                        v-for="option in ownerOptions"
                        :key="option.value"
                        :value="String(option.value)"
                      >
                        {{ option.label }}
                      </option>
                    </select>
                  </label>
                  <label class="grid gap-1.5">
                    <span class="text-sm font-medium text-n-slate-12">
                      {{ t('KANBAN.OPPORTUNITY_DETAILS.FIELD_DESCRIPTION') }}
                    </span>
                    <textarea
                      v-model="description"
                      rows="3"
                      data-testid="kanban-opportunity-description"
                      class="min-h-20 max-w-full w-full min-w-0 resize-y rounded-md border border-n-weak bg-n-surface-1 px-3 py-2 text-sm text-n-slate-12 outline-none placeholder:text-n-slate-10 focus:border-n-brand focus:ring-2 focus:ring-n-brand/20"
                      :placeholder="
                        t('KANBAN.OPPORTUNITY_DETAILS.DESCRIPTION_PLACEHOLDER')
                      "
                    />
                  </label>

                  <div class="grid gap-4 sm:grid-cols-2">
                    <NextInput
                      v-model="amountValue"
                      data-testid="kanban-opportunity-amount"
                      class="w-full"
                      type="number"
                      min="0"
                      step="0.01"
                      :label="t('KANBAN.OPPORTUNITY_DETAILS.FIELD_AMOUNT')"
                    />

                    <NextInput
                      v-model="expectedCloseDate"
                      data-testid="kanban-opportunity-expected-close-date"
                      class="w-full"
                      type="date"
                      :label="
                        t('KANBAN.OPPORTUNITY_DETAILS.EXPECTED_CLOSE_DATE')
                      "
                    />
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
              <section
                class="grid gap-3 rounded-lg border border-n-weak bg-n-surface-2 p-3"
              >
                <h3 class="mb-0 text-sm font-semibold text-n-slate-12">
                  {{ t('KANBAN.OPPORTUNITY_DETAILS.CONTACT') }}
                </h3>
                <dl class="grid gap-3 sm:grid-cols-2">
                  <div
                    v-for="detail in contactDetails"
                    :key="detail.key"
                    class="grid gap-0.5"
                  >
                    <dt class="text-xs text-n-slate-11">{{ detail.label }}</dt>
                    <dd class="m-0 text-sm font-medium text-n-slate-12">
                      {{ detail.value }}
                    </dd>
                  </div>
                </dl>
              </section>
              <section
                v-if="contactAttributeEntries.length"
                class="grid gap-3 rounded-lg border border-n-weak p-3"
              >
                <h3 class="mb-0 text-sm font-semibold text-n-slate-12">
                  {{ t('KANBAN.OPPORTUNITY_DETAILS.CONTACT_ATTRIBUTES') }}
                </h3>
                <dl class="grid gap-3 sm:grid-cols-2">
                  <div
                    v-for="[key, value] in contactAttributeEntries"
                    :key="key"
                    class="grid gap-0.5"
                  >
                    <dt class="text-xs text-n-slate-11">
                      {{ formatContactAttributeLabel(key) }}
                    </dt>
                    <dd class="m-0 break-words text-sm text-n-slate-12">
                      {{ formatContactAttributeValue(value) }}
                    </dd>
                  </div>
                </dl>
              </section>
            </section>

            <section
              v-if="activeTabKey === 'agent-details'"
              data-testid="kanban-opportunity-agent-details"
              class="grid gap-3 rounded-lg border border-n-weak bg-n-surface-2 p-3"
            >
              <div class="flex items-center gap-2">
                <i class="i-lucide-user-round size-4 text-n-slate-10" />
                <h3 class="mb-0 text-sm font-semibold text-n-slate-12">
                  {{ t('KANBAN.OPPORTUNITY_DETAILS.ASSIGNEE') }}
                </h3>
              </div>
              <p
                data-testid="kanban-opportunity-assignee"
                class="mb-0 text-sm text-n-slate-12"
              >
                {{ assigneeName }}
              </p>
              <p class="mb-0 text-xs text-n-slate-11">
                {{ t('KANBAN.OPPORTUNITY_DETAILS.ASSIGNEE_HELP') }}
              </p>
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
              class="grid gap-3"
            >
              <div class="grid gap-3">
                <section
                  v-for="group in activeTabGroups"
                  :key="group.key"
                  class="grid gap-3 rounded-md border p-3"
                  :class="customFieldGroupClass(group.color)"
                >
                  <button
                    type="button"
                    class="flex items-center justify-between gap-3 text-left"
                    :aria-expanded="
                      isGroupExpanded(groupToggleKey(activeTabKey, group.key))
                    "
                    @click="
                      toggleGroup(groupToggleKey(activeTabKey, group.key))
                    "
                  >
                    <span class="text-xs font-semibold text-n-slate-12">
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
                      isGroupExpanded(groupToggleKey(activeTabKey, group.key))
                    "
                    class="grid gap-3 md:grid-cols-6"
                  >
                    <label
                      v-for="definition in group.definitions"
                      :key="definition.key"
                      class="grid gap-1.5"
                      :class="customFieldLayoutClass(definition)"
                    >
                      <span class="text-sm font-medium text-n-slate-12">
                        {{ definition.label }}
                        <i
                          v-if="definition.important"
                          class="i-lucide-asterisk ml-1 inline-block size-3 text-n-amber-11"
                          :title="
                            t('KANBAN.OPPORTUNITY_DETAILS.IMPORTANT_FIELD')
                          "
                        />
                      </span>

                      <select
                        v-if="definition.fieldType === 'select'"
                        :value="getCustomFieldValue(definition)"
                        :data-testid="`kanban-custom-field-${definition.key}`"
                        class="h-10 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                        @change="
                          setCustomFieldValue(definition, $event.target.value)
                        "
                      >
                        <option value="" />
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
                        multiple
                        :value="getCustomFieldValue(definition)"
                        :data-testid="`kanban-custom-field-${definition.key}`"
                        class="min-h-24 rounded-md border border-n-weak bg-n-surface-1 px-3 py-2 text-sm text-n-slate-12 outline-none focus:border-n-brand"
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
                        :value="getCustomFieldValue(definition)"
                        rows="3"
                        :data-testid="`kanban-custom-field-${definition.key}`"
                        class="min-h-20 rounded-md border border-n-weak bg-n-surface-1 px-3 py-2 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                        @input="
                          setCustomFieldValue(definition, $event.target.value)
                        "
                      />

                      <input
                        v-else-if="definition.fieldType === 'boolean'"
                        type="checkbox"
                        :checked="Boolean(getCustomFieldValue(definition))"
                        :data-testid="`kanban-custom-field-${definition.key}`"
                        class="size-4 rounded border-n-weak text-n-brand focus:ring-n-brand"
                        @change="
                          setCustomFieldValue(definition, $event.target.checked)
                        "
                      />

                      <input
                        v-else
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
                        class="h-10 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none disabled:opacity-70 focus:border-n-brand"
                        @input="
                          setCustomFieldValue(definition, $event.target.value)
                        "
                      />
                    </label>
                  </div>
                </section>
              </div>
            </section>
          </section>

          <section
            v-if="
              activeTabKey === 'details' || activeTabKey === 'contact-details'
            "
            class="grid min-w-0 content-start gap-3"
          >
            <section
              v-if="activeTabKey === 'contact-details'"
              class="grid gap-3 rounded-lg border border-n-weak p-3"
            >
              <div class="flex items-center justify-between gap-3">
                <button
                  type="button"
                  class="flex min-w-0 flex-1 items-center justify-between gap-3 text-left"
                  :aria-expanded="isGroupExpanded('labels')"
                  @click="toggleGroup('labels')"
                >
                  <span class="text-sm font-medium text-n-slate-12">
                    {{ t('KANBAN.OPPORTUNITY_DETAILS.LABELS') }}
                  </span>
                  <i
                    class="size-4 text-n-slate-10"
                    :class="
                      isGroupExpanded('labels')
                        ? 'i-lucide-chevron-up'
                        : 'i-lucide-chevron-down'
                    "
                  />
                </button>
                <button
                  type="button"
                  data-testid="kanban-opportunity-save-labels"
                  class="flex size-7 items-center justify-center rounded-md text-n-slate-11 outline-none hover:bg-n-alpha-2 hover:text-n-slate-12 focus:ring-2 focus:ring-n-brand/40 disabled:cursor-not-allowed disabled:opacity-50"
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
              <div v-show="isGroupExpanded('labels')" class="grid gap-3">
                <p
                  v-if="labelsLoadError"
                  data-testid="kanban-opportunity-labels-load-error"
                  class="mb-0 text-sm text-n-ruby-11"
                  role="alert"
                >
                  {{ labelsLoadError }}
                </p>

                <div
                  v-if="accountLabels.length"
                  data-testid="kanban-opportunity-labels"
                  class="flex flex-wrap gap-2"
                >
                  <button
                    v-for="label in accountLabels"
                    :key="label.id || label.title"
                    type="button"
                    data-testid="kanban-opportunity-label"
                    class="flex items-center gap-2 rounded-full border px-3 py-1 text-xs font-medium transition"
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
                  class="mb-0 text-sm text-n-slate-11"
                >
                  {{ t('KANBAN.OPPORTUNITY_DETAILS.NO_LABELS_AVAILABLE') }}
                </p>

                <p
                  v-if="labelsSaveError"
                  data-testid="kanban-opportunity-labels-save-error"
                  class="mb-0 text-sm text-n-ruby-11"
                  role="alert"
                >
                  {{ labelsSaveError }}
                </p>
              </div>
            </section>

            <KanbanCalendarAppointmentsSection
              v-if="activeTabKey === 'details' && calendarEnabled"
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
              class="grid gap-3 rounded-lg border border-n-weak p-3"
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
              <div v-show="isGroupExpanded('organization')" class="grid gap-3">
                <p class="mb-0 text-xs text-n-slate-11">
                  {{ t('KANBAN.OPPORTUNITY_DETAILS.INTERNAL_DATES_HELP') }}
                </p>
                <NextInput
                  v-model="startsAt"
                  type="datetime-local"
                  data-testid="kanban-opportunity-starts-at"
                  :label="t('KANBAN.OPPORTUNITY_DETAILS.START_DATE')"
                />
                <NextInput
                  v-model="dueAt"
                  type="datetime-local"
                  data-testid="kanban-opportunity-due-at"
                  :label="t('KANBAN.OPPORTUNITY_DETAILS.DUE_DATE')"
                />
              </div>
            </section>

            <section
              v-if="activeTabKey === 'details'"
              data-testid="kanban-opportunity-next-action-section"
              class="grid gap-3 rounded-lg border border-n-weak p-3"
            >
              <div class="flex items-center justify-between gap-3">
                <button
                  type="button"
                  class="flex min-w-0 flex-1 items-center justify-between gap-3 text-left"
                  :aria-expanded="isGroupExpanded('nextAction')"
                  @click="toggleGroup('nextAction')"
                >
                  <span class="text-sm font-medium text-n-slate-12">
                    {{ t('KANBAN.OPPORTUNITY_DETAILS.NEXT_ACTION') }}
                  </span>
                  <i
                    class="size-4 text-n-slate-10"
                    :class="
                      isGroupExpanded('nextAction')
                        ? 'i-lucide-chevron-up'
                        : 'i-lucide-chevron-down'
                    "
                  />
                </button>
                <NextButton
                  v-if="nextActionAt && !card.nextActionCompletedAt"
                  type="button"
                  xs
                  outline
                  emerald
                  data-testid="kanban-opportunity-complete-next-action"
                  icon="i-lucide-check-check"
                  :label="t('KANBAN.OPPORTUNITY_DETAILS.COMPLETE_NEXT_ACTION')"
                  :disabled="isSaving"
                  @click="completeNextAction"
                />
              </div>
              <div v-show="isGroupExpanded('nextAction')" class="grid gap-3">
                <label class="grid gap-1.5">
                  <span class="text-sm font-medium text-n-slate-12">
                    {{ t('KANBAN.OPPORTUNITY_DETAILS.NEXT_ACTION_TYPE') }}
                  </span>
                  <select
                    v-model="nextActionType"
                    data-testid="kanban-opportunity-next-action-type"
                    class="h-10 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                  >
                    <option
                      v-for="option in nextActionTypeOptions"
                      :key="option.value || 'none'"
                      :value="option.value"
                    >
                      {{ option.label }}
                    </option>
                  </select>
                </label>
                <NextInput
                  v-model="nextActionAt"
                  type="datetime-local"
                  data-testid="kanban-opportunity-next-action-at"
                  :label="t('KANBAN.OPPORTUNITY_DETAILS.NEXT_ACTION_AT')"
                />
                <label class="grid gap-1.5">
                  <span class="text-sm font-medium text-n-slate-12">
                    {{ t('KANBAN.OPPORTUNITY_DETAILS.NEXT_ACTION_NOTE') }}
                  </span>
                  <textarea
                    v-model="nextActionNote"
                    rows="3"
                    data-testid="kanban-opportunity-next-action-note"
                    class="min-h-20 max-w-full w-full min-w-0 resize-y rounded-md border border-n-weak bg-n-surface-1 px-3 py-2 text-sm text-n-slate-12 outline-none placeholder:text-n-slate-10 focus:border-n-brand"
                    :placeholder="
                      t(
                        'KANBAN.OPPORTUNITY_DETAILS.NEXT_ACTION_NOTE_PLACEHOLDER'
                      )
                    "
                  />
                </label>
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
          class="sticky bottom-0 flex items-center justify-end gap-3 border-t border-n-weak bg-n-background pt-4"
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
  </div>
</template>
