<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';

import KanbanBoardsAPI from 'dashboard/api/kanbanBoards';
import NextButton from 'dashboard/components-next/button/Button.vue';
import NextInput from 'dashboard/components-next/input/Input.vue';
import { useMapGetter, useStore } from 'dashboard/composables/store';

const props = defineProps({
  boardId: {
    type: [Number, String],
    required: true,
  },
  boardName: {
    type: String,
    default: '',
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
  ownerOptions: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['close', 'updated', 'openConversation']);

const { t } = useI18n();
const store = useStore();
const accountLabels = useMapGetter('labels/getLabels');

const card = ref(null);
const subject = ref('');
const description = ref('');
const ownerId = ref('');
const amountValue = ref('');
const amountCurrency = ref('BRL');
const customFieldValues = ref({});
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
const labelsLoadError = ref('');
const labelsSaveError = ref('');
const subjectError = ref('');
const lostReasonError = ref('');
const selectedLabelTitles = ref([]);

const modalTitle = computed(() =>
  props.boardName
    ? t('KANBAN.OPPORTUNITY_DETAILS.TITLE_WITH_BOARD', {
        boardName: props.boardName,
      })
    : t('KANBAN.OPPORTUNITY_DETAILS.TITLE')
);
const cardDisplayId = computed(() => card.value?.id || props.cardId);
const hasConversation = computed(() => !!card.value?.conversationId);
const conversationDisplayId = computed(
  () => card.value?.conversationId || card.value?.conversation?.id
);
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
const hasCustomFields = computed(
  () => visibleCustomFieldDefinitions.value.length > 0
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

const setFormState = payload => {
  card.value = normalizeCard(payload);
  subject.value = card.value.subject || '';
  description.value = card.value.description || '';
  ownerId.value = card.value.ownerId ? String(card.value.ownerId) : '';
  amountValue.value = formatAmountInput(card.value.amountCents);
  amountCurrency.value = card.value.amountCurrency || 'BRL';
  customFieldValues.value = card.value.customFieldValues || {};
  startsAt.value = formatDateTimeInput(card.value.startsAt);
  dueAt.value = formatDateTimeInput(card.value.dueAt);
  nextActionType.value = card.value.nextActionType || '';
  nextActionAt.value = formatDateTimeInput(card.value.nextActionAt);
  nextActionNote.value = card.value.nextActionNote || '';
  lostReason.value = card.value.lostReason || '';
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

const buildCardPayload = extraPayload => ({
  subject: subject.value.trim(),
  description: description.value.trim() ? description.value : null,
  owner_id: ownerId.value ? Number(ownerId.value) : null,
  amount_cents: toAmountCents(amountValue.value),
  amount_currency: amountCurrency.value || 'BRL',
  custom_field_values: customFieldValues.value,
  starts_at: toIso8601(startsAt.value),
  due_at: toIso8601(dueAt.value),
  next_action_type: nextActionType.value || null,
  next_action_at: toIso8601(nextActionAt.value),
  next_action_note: nextActionNote.value.trim() ? nextActionNote.value : null,
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

const markWon = () =>
  saveCardWith({
    won_at: new Date().toISOString(),
  });

const completeNextAction = () =>
  saveCardWith({
    next_action_completed_at: new Date().toISOString(),
  });

const markLost = () => {
  const trimmedReason = String(lostReason.value || '').trim();
  lostReasonError.value = '';

  if (!trimmedReason) {
    lostReasonError.value = t(
      'KANBAN.OPPORTUNITY_DETAILS.LOST_REASON_REQUIRED'
    );
    return;
  }

  saveCardWith({
    lost_at: new Date().toISOString(),
    lost_reason: trimmedReason,
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

const openConversation = () => {
  if (!hasConversation.value) return;

  emit('openConversation', card.value);
};

onMounted(() => {
  loadCard();
  loadLabels();
});
</script>

<template>
  <div
    class="mx-auto flex max-h-[92vh] w-full max-w-[calc(100vw-2rem)] flex-col overflow-hidden rounded-xl bg-n-background 2xl:max-w-[96rem]"
  >
    <div
      class="flex items-start justify-between gap-4 border-b border-n-weak px-5 py-4"
    >
      <div class="min-w-0">
        <h2 class="mb-1 truncate text-base font-semibold text-n-slate-12">
          {{ modalTitle }}
        </h2>
        <p
          v-if="cardDisplayId"
          data-testid="kanban-opportunity-card-id"
          class="mb-0 text-xs text-n-slate-11"
        >
          {{ t('KANBAN.OPPORTUNITY_DETAILS.CARD_ID', { id: cardDisplayId }) }}
        </p>
      </div>
      <button
        type="button"
        data-testid="kanban-opportunity-close"
        class="flex size-8 flex-shrink-0 items-center justify-center rounded-md text-n-slate-11 hover:bg-n-alpha-2 hover:text-n-slate-12"
        :aria-label="t('KANBAN.OPPORTUNITY_DETAILS.CLOSE')"
        @click="emit('close')"
      >
        <i class="i-lucide-x size-4" />
      </button>
    </div>

    <div class="overflow-auto px-5 py-4">
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
      >
        {{ loadError }}
      </p>

      <form
        v-else-if="card"
        data-testid="kanban-opportunity-form"
        class="grid gap-5"
        @submit.prevent="saveCard"
      >
        <div
          data-testid="kanban-opportunity-layout"
          class="grid min-w-0 gap-5 xl:grid-cols-[minmax(0,4fr)_minmax(16rem,1fr)]"
        >
          <section class="grid min-w-0 content-start gap-4">
            <NextInput
              v-model="subject"
              data-testid="kanban-opportunity-subject"
              class="w-full"
              :label="t('KANBAN.OPPORTUNITY_DETAILS.FIELD_TITLE')"
              :message="subjectError"
              :message-type="subjectError ? 'error' : 'info'"
              autofocus
              @input="subjectError = ''"
            />

            <label class="grid gap-1.5">
              <span class="text-sm font-medium text-n-slate-12">
                {{ t('KANBAN.OPPORTUNITY_DETAILS.FIELD_DESCRIPTION') }}
              </span>
              <textarea
                v-model="description"
                rows="4"
                data-testid="kanban-opportunity-description"
                class="min-h-24 max-w-full w-full min-w-0 resize-y rounded-md border border-n-weak bg-n-surface-1 px-3 py-2 text-sm text-n-slate-12 outline-none placeholder:text-n-slate-10 focus:border-n-brand"
                :placeholder="
                  t('KANBAN.OPPORTUNITY_DETAILS.DESCRIPTION_PLACEHOLDER')
                "
              />
            </label>

            <NextInput
              v-model="amountValue"
              data-testid="kanban-opportunity-amount"
              class="w-full"
              type="number"
              min="0"
              step="0.01"
              :label="t('KANBAN.OPPORTUNITY_DETAILS.FIELD_AMOUNT')"
            />

            <section
              v-if="hasCustomFields"
              data-testid="kanban-opportunity-custom-fields"
              class="grid gap-3 rounded-lg border border-n-weak p-3"
            >
              <h3 class="mb-0 text-sm font-medium text-n-slate-12">
                {{ t('KANBAN.OPPORTUNITY_DETAILS.CUSTOM_FIELDS') }}
              </h3>

              <div class="grid gap-3 md:grid-cols-6">
                <label
                  v-for="definition in visibleCustomFieldDefinitions"
                  :key="definition.key"
                  class="grid gap-1.5"
                  :class="customFieldLayoutClass(definition)"
                >
                  <span class="text-sm font-medium text-n-slate-12">
                    {{ definition.label }}
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
                      definition.fieldType === 'decimal' ? '0.01' : undefined
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
          </section>

          <aside class="grid min-w-0 content-start gap-4">
            <section class="grid gap-3 rounded-lg border border-n-weak p-3">
              <h3 class="mb-0 text-sm font-medium text-n-slate-12">
                {{ t('KANBAN.OPPORTUNITY_DETAILS.OWNER') }}
              </h3>
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
            </section>

            <section class="grid gap-2 rounded-lg border border-n-weak p-3">
              <h3 class="mb-0 text-sm font-medium text-n-slate-12">
                {{ t('KANBAN.OPPORTUNITY_DETAILS.ASSIGNEE') }}
              </h3>
              <p
                data-testid="kanban-opportunity-assignee"
                class="mb-0 text-sm text-n-slate-11"
              >
                {{ assigneeName }}
              </p>
            </section>

            <section class="grid gap-3 rounded-lg border border-n-weak p-3">
              <div class="flex items-center justify-between gap-3">
                <h3 class="mb-0 text-sm font-medium text-n-slate-12">
                  {{ t('KANBAN.OPPORTUNITY_DETAILS.LABELS') }}
                </h3>
                <button
                  type="button"
                  data-testid="kanban-opportunity-save-labels"
                  class="flex size-7 items-center justify-center rounded-md text-n-slate-11 hover:bg-n-alpha-2 hover:text-n-slate-12 disabled:cursor-not-allowed disabled:opacity-50"
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
                v-if="labelsLoadError"
                data-testid="kanban-opportunity-labels-load-error"
                class="mb-0 text-sm text-n-ruby-11"
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
              >
                {{ labelsSaveError }}
              </p>
            </section>

            <section class="grid gap-3 rounded-lg border border-n-weak p-3">
              <h3 class="mb-0 text-sm font-medium text-n-slate-12">
                {{ t('KANBAN.OPPORTUNITY_DETAILS.CONVERSATION') }}
              </h3>
              <p
                v-if="hasConversation"
                data-testid="kanban-opportunity-conversation"
                class="mb-0 text-sm text-n-slate-11"
              >
                {{
                  t('KANBAN.OPPORTUNITY_DETAILS.CONVERSATION_ID', {
                    id: conversationDisplayId,
                  })
                }}
              </p>
              <p
                v-else
                data-testid="kanban-opportunity-no-conversation"
                class="mb-0 flex items-center gap-2 text-sm text-n-slate-11"
              >
                <i class="i-lucide-message-square-off size-4" />
                {{ t('KANBAN.OPPORTUNITY_DETAILS.NO_LINKED_CONVERSATION') }}
              </p>
              <NextButton
                v-if="hasConversation"
                type="button"
                outline
                slate
                xs
                data-testid="kanban-opportunity-open-conversation"
                icon="i-lucide-message-square"
                :label="t('KANBAN.OPPORTUNITY_DETAILS.OPEN_CONVERSATION')"
                @click="openConversation"
              />
            </section>

            <section class="grid gap-2 rounded-lg border border-n-weak p-3">
              <h3 class="mb-0 text-sm font-medium text-n-slate-12">
                {{ t('KANBAN.OPPORTUNITY_DETAILS.CONTACT') }}
              </h3>
              <p
                data-testid="kanban-opportunity-contact"
                class="mb-0 text-sm text-n-slate-11"
              >
                {{ contactName }}
              </p>
            </section>

            <section class="grid gap-3 rounded-lg border border-n-weak p-3">
              <h3 class="mb-0 text-sm font-medium text-n-slate-12">
                {{ t('KANBAN.OPPORTUNITY_DETAILS.DATES') }}
              </h3>
              <div class="grid gap-3">
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

            <section class="grid gap-3 rounded-lg border border-n-weak p-3">
              <h3 class="mb-0 text-sm font-medium text-n-slate-12">
                {{ t('KANBAN.OPPORTUNITY_DETAILS.NEXT_ACTION') }}
              </h3>
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
                    t('KANBAN.OPPORTUNITY_DETAILS.NEXT_ACTION_NOTE_PLACEHOLDER')
                  "
                />
              </label>
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

            <section class="grid gap-3 rounded-lg border border-n-weak p-3">
              <h3 class="mb-0 text-sm font-medium text-n-slate-12">
                {{ t('KANBAN.OPPORTUNITY_DETAILS.CLOSE_STATUS') }}
              </h3>
              <NextButton
                type="button"
                xs
                emerald
                data-testid="kanban-opportunity-mark-won"
                icon="i-lucide-circle-check"
                :label="t('KANBAN.OPPORTUNITY_DETAILS.MARK_WON')"
                :disabled="isSaving"
                @click="markWon"
              />
              <label class="grid gap-1.5">
                <span class="text-sm font-medium text-n-slate-12">
                  {{ t('KANBAN.OPPORTUNITY_DETAILS.LOST_REASON') }}
                </span>
                <select
                  v-model="lostReason"
                  data-testid="kanban-opportunity-lost-reason"
                  class="h-10 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none placeholder:text-n-slate-10 focus:border-n-brand"
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
                <span v-if="lostReasonError" class="text-xs text-n-ruby-11">
                  {{ lostReasonError }}
                </span>
              </label>
              <NextButton
                type="button"
                xs
                ruby
                data-testid="kanban-opportunity-mark-lost"
                icon="i-lucide-circle-x"
                :label="t('KANBAN.OPPORTUNITY_DETAILS.MARK_LOST')"
                :disabled="isSaving"
                @click="markLost"
              />
            </section>
          </aside>
        </div>

        <p
          v-if="saveError"
          data-testid="kanban-opportunity-save-error"
          class="mb-0 text-sm text-n-ruby-11"
        >
          {{ saveError }}
        </p>

        <div
          class="flex items-center justify-end gap-3 border-t border-n-weak pt-4"
        >
          <NextButton
            type="button"
            outline
            slate
            sm
            data-testid="kanban-opportunity-cancel"
            :label="t('KANBAN.OPPORTUNITY_DETAILS.CANCEL')"
            @click="emit('close')"
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
  </div>
</template>
