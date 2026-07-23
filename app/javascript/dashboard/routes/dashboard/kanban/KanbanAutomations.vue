<script setup>
import { computed, onMounted, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import camelcaseKeys from 'camelcase-keys';

import { useAlert } from 'dashboard/composables';
import { useMapGetter } from 'dashboard/composables/store';
import KanbanBoardsAPI from 'dashboard/api/kanbanBoards';
import Button from 'dashboard/components-next/button/Button.vue';
import { copyTextToClipboard } from 'shared/helpers/clipboard';
import KanbanWorkflowBuilder from './components/KanbanWorkflowBuilder.vue';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const agents = useMapGetter('agents/getAgents');

const boardId = computed(() => Number(route.params.boardId));
const activeTab = ref('flows');
const isLoading = ref(false);
const isSaving = ref(false);
const error = ref('');
const rules = ref([]);
const appointmentReminders = ref([]);
const connections = ref([]);
const executions = ref([]);
const settings = ref({});
const selectedRuleId = ref(null);
const showEditor = ref(false);
const showReminderForm = ref(false);
const showConnectionForm = ref(false);
const isSavingReminder = ref(false);
const isSavingConnection = ref(false);
const connectionSecret = ref('');
const expandedConnectionId = ref(null);
const testRuleId = ref(null);
const testCards = ref([]);
const selectedTestCardId = ref('');
const testResult = ref(null);
const isLoadingTestCards = ref(false);
const isTestingRule = ref(false);
const testError = ref('');

const blankAction = () => ({
  actionName: 'move_stage',
  stageId: '',
  ownerId: '',
  fieldKey: '',
  fieldValue: '',
  nextActionType: '',
  nextActionAt: '',
  nextActionNote: '',
});

const form = reactive({
  name: '',
  description: '',
  eventName: 'kanban.card.stage_changed',
  active: true,
  stageId: '',
  ownerId: '',
  fieldKey: '',
  fieldOperator: 'equals',
  fieldValue: '',
  actions: [blankAction()],
  flowDefinition: {},
});

const reminderForm = reactive({
  triggerStageId: '',
  fieldKey: 'system_starts_at',
  offsets: '48,24,2',
  channels: ['whatsapp'],
  optInAttributeKey: 'appointment_reminders_opt_in',
  messageTemplates: {},
});
const connectionForm = reactive({ name: '', webhookUrl: '' });
const defaultReminderMessage =
  'Olá, {{contact_name}}! Lembramos que sua consulta será em {{appointment_date}}.';

const eventOptions = computed(() => [
  {
    value: 'kanban.card.created',
    label: t('KANBAN.SETTINGS.AUTOMATIONS.EVENTS.CREATED'),
  },
  {
    value: 'kanban.card.stage_changed',
    label: t('KANBAN.SETTINGS.AUTOMATIONS.EVENTS.STAGE_CHANGED'),
  },
  {
    value: 'kanban.card.customer_message_received',
    label: t('KANBAN.SETTINGS.AUTOMATIONS.EVENTS.CUSTOMER_MESSAGE_RECEIVED'),
  },
  {
    value: 'kanban.card.webhook_received',
    label: t('KANBAN.SETTINGS.AUTOMATIONS.EVENTS.WEBHOOK_RECEIVED'),
  },
  {
    value: 'kanban.card.owner_changed',
    label: t('KANBAN.SETTINGS.AUTOMATIONS.EVENTS.OWNER_CHANGED'),
  },
  {
    value: 'kanban.card.amount_changed',
    label: t('KANBAN.SETTINGS.AUTOMATIONS.EVENTS.AMOUNT_CHANGED'),
  },
  {
    value: 'kanban.card.custom_fields_changed',
    label: t('KANBAN.SETTINGS.AUTOMATIONS.EVENTS.CUSTOM_FIELDS_CHANGED'),
  },
  {
    value: 'kanban.card.next_action_scheduled',
    label: t('KANBAN.SETTINGS.AUTOMATIONS.EVENTS.NEXT_ACTION_SCHEDULED'),
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
  {
    value: 'kanban.card.reopened',
    label: t('KANBAN.SETTINGS.AUTOMATIONS.EVENTS.REOPENED'),
  },
  {
    value: 'kanban.card.archived',
    label: t('KANBAN.SETTINGS.AUTOMATIONS.EVENTS.ARCHIVED'),
  },
  {
    value: 'kanban.card.restored',
    label: t('KANBAN.SETTINGS.AUTOMATIONS.EVENTS.RESTORED'),
  },
  {
    value: 'kanban.card.manual_started',
    label: t('KANBAN.SETTINGS.AUTOMATIONS.EVENTS.MANUAL_STARTED'),
  },
]);

const automationTabs = computed(() => [
  { key: 'flows', label: t('KANBAN.AUTOMATIONS_WORKSPACE.TABS.FLOWS') },
  {
    key: 'reminders',
    label: t('KANBAN.AUTOMATIONS_WORKSPACE.TABS.REMINDERS'),
  },
  {
    key: 'connections',
    label: t('KANBAN.AUTOMATIONS_WORKSPACE.TABS.CONNECTIONS'),
  },
  {
    key: 'executions',
    label: t('KANBAN.AUTOMATIONS_WORKSPACE.TABS.EXECUTIONS'),
  },
]);

const flowTemplate = ({ message, waitForResponse = false }) => {
  const nodes = [
    { id: 'trigger', type: 'trigger', position: { x: 32, y: 180 }, data: {} },
  ];
  const edges = [];
  let previousId = 'trigger';

  if (message) {
    nodes.push({
      id: 'message',
      type: 'send_message',
      position: { x: 300, y: 180 },
      data: {
        channel: 'whatsapp',
        opt_in_attribute_key: 'marketing_messages_opt_in',
        content: message,
        frequency_limit_hours: 168,
        quiet_hours: {
          start: '20:00',
          end: '08:00',
          timezone: 'America/Sao_Paulo',
        },
        whatsapp_template_params: {},
      },
    });
    edges.push({
      id: 'trigger-message',
      source: previousId,
      target: 'message',
    });
    previousId = 'message';
  }

  if (waitForResponse) {
    nodes.push({
      id: 'wait-response',
      type: 'wait_for_response',
      position: { x: 568, y: 180 },
      data: { timeout_hours: 72 },
    });
    edges.push({
      id: `${previousId}-wait-response`,
      source: previousId,
      target: 'wait-response',
    });
    previousId = 'wait-response';
  }

  nodes.push({
    id: 'next-action',
    type: 'action',
    position: { x: message || waitForResponse ? 836 : 300, y: 180 },
    data: {
      action_name: 'set_next_action',
      action_params: { next_action_type: '', next_action_note: '' },
    },
  });
  nodes.push({
    id: 'end',
    type: 'end',
    position: { x: message || waitForResponse ? 1104 : 568, y: 180 },
    data: {},
  });
  edges.push({
    id: `${previousId}-next-action`,
    source: previousId,
    target: 'next-action',
  });
  edges.push({ id: 'next-action-end', source: 'next-action', target: 'end' });

  return { nodes, edges };
};

const automationTemplates = computed(() => [
  {
    id: 'follow-up',
    defaultName: 'Follow-up comercial',
    name: t('KANBAN.AUTOMATIONS_WORKSPACE.TEMPLATES.FOLLOW_UP.TITLE'),
    description: t(
      'KANBAN.AUTOMATIONS_WORKSPACE.TEMPLATES.FOLLOW_UP.DESCRIPTION'
    ),
    eventName: 'kanban.card.stage_changed',
    flowDefinition: flowTemplate({ waitForResponse: true }),
  },
  {
    id: 'nps-google-review',
    defaultName: 'Pedir avaliação no Google',
    name: t('KANBAN.AUTOMATIONS_WORKSPACE.TEMPLATES.NPS_GOOGLE.TITLE'),
    description: t(
      'KANBAN.AUTOMATIONS_WORKSPACE.TEMPLATES.NPS_GOOGLE.DESCRIPTION'
    ),
    eventName: 'kanban.card.won',
    flowDefinition: flowTemplate({
      message: t('KANBAN.AUTOMATIONS_WORKSPACE.TEMPLATES.NPS_GOOGLE.MESSAGE'),
      waitForResponse: true,
    }),
  },
]);

const stages = computed(() => settings.value.stages || []);
const customFields = computed(
  () => settings.value.customFieldDefinitions || []
);
const nextActionTypes = computed(() => settings.value.nextActionTypes || []);
const agentOptions = computed(() =>
  agents.value.map(agent => ({
    value: agent.id,
    label: agent.name || agent.email,
  }))
);
const conditionFields = computed(() => [
  { key: 'subject', label: t('KANBAN.SETTINGS.SALES.SYSTEM_FIELDS.SUBJECT') },
  {
    key: 'amount_cents',
    label: t('KANBAN.SETTINGS.SALES.SYSTEM_FIELDS.AMOUNT'),
  },
  ...customFields.value.map(field => ({
    key: field.key,
    label: field.label || field.key,
    fieldType: field.fieldType,
    conditionOptions: field.options?.map(option => ({
      value: option,
      label: option,
    })),
  })),
]);
const dateFields = computed(() =>
  customFields.value.filter(field =>
    ['date', 'datetime'].includes(field.fieldType)
  )
);
const reminderDateFields = computed(() => [
  {
    key: 'system_starts_at',
    label: t('KANBAN.SETTINGS.AUTOMATIONS.APPOINTMENT.SYSTEM_DATE'),
  },
  ...dateFields.value,
]);
const reminderOffsets = computed(() =>
  reminderForm.offsets
    .split(',')
    .map(value => Number(value.trim()))
    .filter(value => Number.isInteger(value) && value > 0)
    .filter((value, index, values) => values.indexOf(value) === index)
);
const testCardOptions = computed(() =>
  testCards.value.map(card => ({
    value: String(card.id),
    label: `${card.subject || card.contact?.name || `#${card.id}`} · ${
      card.contact?.name || t('KANBAN.AUTOMATIONS_WORKSPACE.TEST.NO_CONTACT')
    }${card.stageName ? ` · ${card.stageName}` : ''}`,
  }))
);

const normalize = value => camelcaseKeys(value || {}, { deep: true });
const resetForm = () => {
  selectedRuleId.value = null;
  form.name = '';
  form.description = '';
  form.eventName = 'kanban.card.stage_changed';
  form.active = true;
  form.stageId = '';
  form.ownerId = '';
  form.fieldKey = '';
  form.fieldOperator = 'equals';
  form.fieldValue = '';
  form.flowDefinition = {};
  form.actions.splice(0, form.actions.length, blankAction());
};

const applyRule = rule => {
  const normalized = normalize(rule);
  const conditions = normalized.conditions || {};
  const field = conditions.fields?.[0] || {};
  selectedRuleId.value = normalized.id;
  form.name = normalized.name || '';
  form.description = normalized.description || '';
  form.eventName = normalized.eventName || 'kanban.card.stage_changed';
  form.active = normalized.active !== false;
  form.stageId = conditions.stageIds?.[0] || '';
  form.ownerId = conditions.ownerIds?.[0] || '';
  form.fieldKey = field.fieldKey || '';
  form.fieldOperator = field.operator || 'equals';
  form.fieldValue = field.value || '';
  form.flowDefinition = normalized.flowDefinition || {};
  form.actions.splice(0, form.actions.length, ...(normalized.actions || []));
};

const openNewFlow = () => {
  resetForm();
  activeTab.value = 'flows';
  showEditor.value = true;
};
const openTemplate = template => {
  resetForm();
  form.name = template.defaultName || template.name;
  form.description = template.description;
  form.eventName = template.eventName;
  form.active = false;
  form.flowDefinition = template.flowDefinition;
  activeTab.value = 'flows';
  showEditor.value = true;
};
const openBirthdayAutomation = () => {
  router.push({
    name: 'kanban_board_settings',
    params: { accountId: route.params.accountId, boardId: boardId.value },
    hash: '#birthday-automation',
  });
};
const openRule = rule => {
  applyRule(rule);
  activeTab.value = 'flows';
  showEditor.value = true;
};
const closeEditor = () => {
  showEditor.value = false;
  resetForm();
};

const saveReminder = async () => {
  if (
    isSavingReminder.value ||
    !reminderForm.triggerStageId ||
    !reminderOffsets.value.length ||
    !reminderForm.channels.length
  )
    return;

  isSavingReminder.value = true;
  try {
    const response = await KanbanBoardsAPI.createAppointmentReminderRule(
      boardId.value,
      {
        appointment_reminder_rule: {
          trigger_type: 'stage_entered',
          trigger_stage_id: Number(reminderForm.triggerStageId),
          field_key: reminderForm.fieldKey,
          offsets: reminderOffsets.value,
          channels: reminderForm.channels,
          opt_in_attribute_key: reminderForm.optInAttributeKey,
          message_templates: Object.fromEntries(
            reminderOffsets.value.map(offset => [
              String(offset),
              reminderForm.messageTemplates[offset]?.trim() ||
                defaultReminderMessage,
            ])
          ),
          active: true,
        },
      }
    );
    appointmentReminders.value.push(normalize(response.data));
    showReminderForm.value = false;
    useAlert(t('KANBAN.SETTINGS.AUTOMATIONS.APPOINTMENT.SAVE_SUCCESS'));
  } catch (saveError) {
    error.value = t('KANBAN.SETTINGS.AUTOMATIONS.APPOINTMENT.SAVE_ERROR');
  } finally {
    isSavingReminder.value = false;
  }
};

const deleteReminder = async reminder => {
  if (!reminder?.id || isSavingReminder.value) return;

  isSavingReminder.value = true;
  try {
    await KanbanBoardsAPI.deleteAppointmentReminderRule(
      boardId.value,
      reminder.id
    );
    appointmentReminders.value = appointmentReminders.value.filter(
      item => item.id !== reminder.id
    );
  } catch (deleteError) {
    error.value = t('KANBAN.SETTINGS.AUTOMATIONS.APPOINTMENT.DISABLE_ERROR');
  } finally {
    isSavingReminder.value = false;
  }
};

const resetConnectionForm = () => {
  connectionForm.name = '';
  connectionForm.webhookUrl = '';
  connectionSecret.value = '';
};

const toggleConnectionForm = () => {
  if (!showConnectionForm.value) resetConnectionForm();
  showConnectionForm.value = !showConnectionForm.value;
};

const saveConnection = async () => {
  if (
    isSavingConnection.value ||
    !connectionForm.name.trim() ||
    !connectionForm.webhookUrl.trim()
  )
    return;

  isSavingConnection.value = true;
  try {
    const response = await KanbanBoardsAPI.createAutomationConnection(
      boardId.value,
      {
        automation_connection: {
          name: connectionForm.name.trim(),
          webhook_url: connectionForm.webhookUrl.trim(),
        },
      }
    );
    const connection = normalize(response.data);
    connections.value.push(connection);
    connectionSecret.value = connection.secret || '';
    showConnectionForm.value = false;
    useAlert(t('KANBAN.AUTOMATIONS_WORKSPACE.CONNECTIONS.SAVE_SUCCESS'));
  } catch (saveError) {
    error.value =
      saveError?.response?.data?.message ||
      t('KANBAN.AUTOMATIONS_WORKSPACE.CONNECTIONS.SAVE_ERROR');
  } finally {
    isSavingConnection.value = false;
  }
};

const deleteConnection = async connection => {
  if (!connection?.id || isSavingConnection.value) return;

  isSavingConnection.value = true;
  try {
    await KanbanBoardsAPI.deleteAutomationConnection(
      boardId.value,
      connection.id
    );
    connections.value = connections.value.filter(
      item => item.id !== connection.id
    );
  } catch (deleteError) {
    error.value = t('KANBAN.AUTOMATIONS_WORKSPACE.CONNECTIONS.DELETE_ERROR');
  } finally {
    isSavingConnection.value = false;
  }
};

const retryExecution = async execution => {
  if (!execution?.ruleId || !execution?.id) return;

  try {
    await KanbanBoardsAPI.retryAutomationExecution(
      boardId.value,
      execution.ruleId,
      execution.id
    );
    useAlert(t('KANBAN.AUTOMATIONS_WORKSPACE.EXECUTIONS.RETRY_SUCCESS'));
  } catch (retryError) {
    error.value = t('KANBAN.AUTOMATIONS_WORKSPACE.EXECUTIONS.RETRY_ERROR');
  }
};

const cancelExecution = async execution => {
  if (!execution?.ruleId || !execution?.id) return;

  try {
    await KanbanBoardsAPI.cancelAutomationExecution(
      boardId.value,
      execution.ruleId,
      execution.id
    );
    execution.status = 'skipped';
    useAlert(t('KANBAN.SETTINGS.AUTOMATIONS.RULES.CANCEL_EXECUTION_SUCCESS'));
  } catch (cancelError) {
    error.value = t('KANBAN.SETTINGS.AUTOMATIONS.RULES.CANCEL_EXECUTION_ERROR');
  }
};

const resetConnectionSecret = async connection => {
  if (!connection?.id) return;

  try {
    const response = await KanbanBoardsAPI.resetAutomationConnectionSecret(
      boardId.value,
      connection.id
    );
    connectionSecret.value = normalize(response.data).secret || '';
    useAlert(
      t('KANBAN.AUTOMATIONS_WORKSPACE.CONNECTIONS.SECRET_RESET_SUCCESS')
    );
  } catch (resetError) {
    error.value = t(
      'KANBAN.AUTOMATIONS_WORKSPACE.CONNECTIONS.SECRET_RESET_ERROR'
    );
  }
};

const toggleConnectionDetails = connectionId => {
  expandedConnectionId.value =
    expandedConnectionId.value === connectionId ? null : connectionId;
};

const copyConnectionUrl = async url => {
  if (!url) return;

  await copyTextToClipboard(url);
  useAlert(t('KANBAN.AUTOMATIONS_WORKSPACE.CONNECTIONS.URL_COPIED'));
};

const toggleRuleTest = async rule => {
  if (testRuleId.value === rule.id) {
    testRuleId.value = null;
    return;
  }

  testRuleId.value = rule.id;
  selectedTestCardId.value = '';
  testResult.value = null;
  testError.value = '';
  if (testCards.value.length) return;

  isLoadingTestCards.value = true;
  try {
    const responses = await Promise.all(
      stages.value.map(stage =>
        KanbanBoardsAPI.getStageCards(boardId.value, stage.id, { limit: 100 })
      )
    );
    testCards.value = responses.flatMap((response, index) =>
      (normalize(response.data).cards || []).map(card => ({
        ...card,
        stageName: stages.value[index]?.name,
      }))
    );
  } catch (loadError) {
    testError.value = t('KANBAN.AUTOMATIONS_WORKSPACE.TEST.LOAD_CARDS_ERROR');
  } finally {
    isLoadingTestCards.value = false;
  }
};

const runRuleTest = async rule => {
  if (!selectedTestCardId.value || isTestingRule.value) return;

  isTestingRule.value = true;
  testError.value = '';
  testResult.value = null;
  try {
    const response = await KanbanBoardsAPI.testAutomationRule(
      boardId.value,
      rule.id,
      Number(selectedTestCardId.value)
    );
    testResult.value = normalize(response.data);
  } catch (runError) {
    testError.value = t('KANBAN.AUTOMATIONS_WORKSPACE.TEST.RUN_ERROR');
  } finally {
    isTestingRule.value = false;
  }
};

const previewStepLabel = step => {
  switch (step.type || step.actionName) {
    case 'delay':
      return t('KANBAN.AUTOMATIONS_WORKSPACE.TEST.STEPS.DELAY');
    case 'wait_until_field':
      return t('KANBAN.AUTOMATIONS_WORKSPACE.TEST.STEPS.WAIT_UNTIL_FIELD');
    case 'wait_for_response':
      return t('KANBAN.AUTOMATIONS_WORKSPACE.TEST.STEPS.WAIT_FOR_RESPONSE');
    case 'condition':
      return t('KANBAN.AUTOMATIONS_WORKSPACE.TEST.STEPS.CONDITION');
    case 'action':
      return t('KANBAN.AUTOMATIONS_WORKSPACE.TEST.STEPS.ACTION');
    case 'send_message':
      return t('KANBAN.AUTOMATIONS_WORKSPACE.TEST.STEPS.SEND_MESSAGE');
    case 'webhook':
      return t('KANBAN.AUTOMATIONS_WORKSPACE.TEST.STEPS.WEBHOOK');
    default:
      return t('KANBAN.AUTOMATIONS_WORKSPACE.TEST.STEPS.UNKNOWN');
  }
};

const actionParams = action => {
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

const payload = () => ({
  kanban_automation_rule: {
    name: form.name.trim(),
    description: form.description.trim() || null,
    event_name: form.eventName,
    active: form.active,
    conditions: {
      stage_ids: form.stageId ? [Number(form.stageId)] : [],
      owner_ids: form.ownerId ? [Number(form.ownerId)] : [],
      fields: form.fieldKey
        ? [
            {
              field_key: form.fieldKey,
              operator: form.fieldOperator,
              value: form.fieldValue,
            },
          ]
        : [],
    },
    actions: form.actions
      .filter(action => action.actionName)
      .map(action => ({
        action_name: action.actionName,
        action_params: actionParams(action),
      })),
    flow_definition: form.flowDefinition,
  },
});

const save = async () => {
  if (!form.name.trim() || isSaving.value) return;

  isSaving.value = true;
  error.value = '';
  try {
    const response = selectedRuleId.value
      ? await KanbanBoardsAPI.updateAutomationRule(
          boardId.value,
          selectedRuleId.value,
          payload()
        )
      : await KanbanBoardsAPI.createAutomationRule(boardId.value, payload());
    const saved = normalize(response.data);
    const index = rules.value.findIndex(rule => rule.id === saved.id);
    if (index < 0) rules.value.push(saved);
    else rules.value.splice(index, 1, saved);
    rules.value.sort((left, right) => left.position - right.position);
    closeEditor();
    activeTab.value = 'flows';
    useAlert(t('KANBAN.SETTINGS.AUTOMATIONS.RULES.SAVE_SUCCESS'));
  } catch (saveError) {
    error.value =
      saveError?.response?.data?.message ||
      t('KANBAN.SETTINGS.AUTOMATIONS.RULES.SAVE_ERROR');
    useAlert(error.value);
  } finally {
    isSaving.value = false;
  }
};

const load = async () => {
  isLoading.value = true;
  error.value = '';
  try {
    const [
      settingsResponse,
      rulesResponse,
      remindersResponse,
      connectionsResponse,
      executionsResponse,
    ] = await Promise.all([
      KanbanBoardsAPI.getSettings(boardId.value),
      KanbanBoardsAPI.getAutomationRules(boardId.value),
      KanbanBoardsAPI.getAppointmentReminderRules(boardId.value),
      KanbanBoardsAPI.getAutomationConnections(boardId.value),
      KanbanBoardsAPI.getAllAutomationExecutions(boardId.value),
    ]);
    settings.value = normalize(settingsResponse.data);
    rules.value = normalize(rulesResponse.data);
    appointmentReminders.value = normalize(remindersResponse.data);
    connections.value = normalize(connectionsResponse.data);
    executions.value = normalize(executionsResponse.data);
  } catch (loadError) {
    error.value = t('KANBAN.SETTINGS.LOAD_ERROR');
  } finally {
    isLoading.value = false;
  }
};

onMounted(load);
</script>

<template>
  <main
    data-testid="kanban-automations-workspace"
    class="flex h-full min-h-0 w-full flex-col bg-n-surface-1 text-n-slate-12"
  >
    <header
      class="flex flex-wrap items-center justify-between gap-3 border-b border-n-weak px-4 py-3 lg:px-6"
    >
      <div class="min-w-0">
        <button
          type="button"
          class="mb-1 inline-flex items-center gap-1 text-xs font-medium text-n-slate-11 hover:text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand"
          @click="
            router.push({
              name: 'kanban_board_show',
              params: { accountId: route.params.accountId, boardId },
            })
          "
        >
          <i class="i-lucide-arrow-left size-3" />
          {{ t('KANBAN.AUTOMATIONS_WORKSPACE.BACK') }}
        </button>
        <h1 class="m-0 text-lg font-semibold text-n-slate-12">
          {{ t('KANBAN.AUTOMATIONS_WORKSPACE.TITLE') }}
        </h1>
      </div>
      <Button
        v-if="!showEditor"
        type="button"
        data-testid="kanban-automations-new-flow"
        icon="i-lucide-plus"
        :label="t('KANBAN.AUTOMATIONS_WORKSPACE.NEW_FLOW')"
        color="blue"
        size="sm"
        @click="openNewFlow"
      />
      <div v-else class="flex items-center gap-2">
        <Button
          type="button"
          :label="t('KANBAN.ACTIONS.CANCEL')"
          color="slate"
          size="sm"
          @click="closeEditor"
        />
        <Button
          type="button"
          data-testid="kanban-automations-save-flow"
          icon="i-lucide-save"
          :label="t('KANBAN.ACTIONS.SAVE')"
          color="blue"
          size="sm"
          :is-loading="isSaving"
          @click="save"
        />
      </div>
    </header>

    <div
      v-if="showEditor"
      data-testid="kanban-automation-editor"
      class="flex min-h-0 flex-1 flex-col"
    >
      <section
        class="grid gap-3 border-b border-n-weak bg-n-surface-2 px-4 py-3 lg:grid-cols-[minmax(0,1fr)_13rem_11rem_auto] lg:px-6"
      >
        <label class="grid gap-1 text-xs font-medium text-n-slate-11">
          {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.NAME') }}
          <input
            v-model="form.name"
            data-testid="kanban-automations-flow-name"
            type="text"
            class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
          />
        </label>
        <label class="grid gap-1 text-xs font-medium text-n-slate-11">
          {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.EVENT') }}
          <select
            v-model="form.eventName"
            class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
          >
            <option
              v-for="event in eventOptions"
              :key="event.value"
              :value="event.value"
            >
              {{ event.label }}
            </option>
          </select>
        </label>
        <label class="grid gap-1 text-xs font-medium text-n-slate-11">
          {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.STAGE') }}
          <select
            v-model="form.stageId"
            class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
          >
            <option value="">
              {{ t('KANBAN.AUTOMATIONS_WORKSPACE.ANY_STAGE') }}
            </option>
            <option v-for="stage in stages" :key="stage.id" :value="stage.id">
              {{ stage.name }}
            </option>
          </select>
        </label>
        <label
          class="flex items-end gap-2 pb-2 text-xs font-medium text-n-slate-11"
        >
          <input
            v-model="form.active"
            type="checkbox"
            class="size-4 rounded border-n-weak text-n-brand focus:ring-n-brand"
          />
          {{ t('KANBAN.AUTOMATIONS_WORKSPACE.ACTIVE') }}
        </label>
      </section>
      <KanbanWorkflowBuilder
        v-model="form.flowDefinition"
        class="min-h-0 flex-1 rounded-none border-x-0 border-b-0"
        :stages="stages"
        :agents="agentOptions"
        :custom-fields="customFields"
        :next-action-types="nextActionTypes"
        :condition-fields="conditionFields"
        :date-fields="dateFields"
        :connections="connections"
      />
      <p
        v-if="error"
        class="m-0 border-t border-n-weak px-4 py-2 text-sm text-n-ruby-11"
        role="alert"
      >
        {{ error }}
      </p>
    </div>

    <section v-else class="min-h-0 flex-1 overflow-y-auto px-4 py-4 lg:px-6">
      <div
        class="mb-4 flex w-fit items-center gap-1 rounded-md bg-n-surface-2 p-1"
        role="tablist"
      >
        <button
          v-for="tab in automationTabs"
          :key="tab.key"
          type="button"
          :data-testid="`kanban-automations-tab-${tab.key}`"
          class="h-8 rounded px-3 text-sm font-medium focus:outline-none focus:ring-2 focus:ring-n-brand"
          :class="
            activeTab === tab.key
              ? 'bg-n-surface-1 text-n-slate-12 shadow-sm'
              : 'text-n-slate-11 hover:text-n-slate-12'
          "
          :aria-selected="activeTab === tab.key"
          role="tab"
          @click="activeTab = tab.key"
        >
          {{ tab.label }}
        </button>
      </div>

      <div v-if="isLoading" class="grid gap-2" aria-busy="true">
        <div
          v-for="item in 4"
          :key="item"
          class="h-16 animate-pulse rounded-md bg-n-surface-2"
        />
      </div>
      <template v-else-if="activeTab === 'flows'">
        <div class="mb-2 max-w-5xl">
          <h2 class="m-0 text-sm font-semibold text-n-slate-12">
            {{ t('KANBAN.AUTOMATIONS_WORKSPACE.TEMPLATES.TITLE') }}
          </h2>
        </div>
        <section
          class="mb-4 grid max-w-5xl gap-2 md:grid-cols-3"
          :aria-label="t('KANBAN.AUTOMATIONS_WORKSPACE.TEMPLATES.TITLE')"
        >
          <button
            v-for="template in automationTemplates"
            :key="template.id"
            type="button"
            class="grid min-h-20 gap-1 rounded-md border border-n-weak bg-n-surface-1 p-3 text-left transition-colors hover:border-n-brand focus:outline-none focus:ring-2 focus:ring-n-brand"
            :data-testid="`kanban-automations-template-${template.id === 'follow-up' ? 'follow-up' : 'nps-google'}`"
            @click="openTemplate(template)"
          >
            <span class="text-sm font-medium text-n-slate-12">{{
              template.name
            }}</span>
            <span class="text-xs text-n-slate-11">{{
              template.description
            }}</span>
          </button>
          <button
            type="button"
            data-testid="kanban-automations-template-birthday"
            class="grid min-h-20 gap-1 rounded-md border border-n-weak bg-n-surface-1 p-3 text-left transition-colors hover:border-n-brand focus:outline-none focus:ring-2 focus:ring-n-brand"
            @click="openBirthdayAutomation"
          >
            <span class="text-sm font-medium text-n-slate-12">
              {{ t('KANBAN.AUTOMATIONS_WORKSPACE.TEMPLATES.BIRTHDAY.TITLE') }}
            </span>
            <span class="text-xs text-n-slate-11">
              {{
                t('KANBAN.AUTOMATIONS_WORKSPACE.TEMPLATES.BIRTHDAY.DESCRIPTION')
              }}
            </span>
          </button>
        </section>
        <div v-if="rules.length" class="grid max-w-5xl gap-2">
          <article
            v-for="rule in rules"
            :key="rule.id"
            class="rounded-md border border-n-weak bg-n-surface-1"
          >
            <div class="flex items-center justify-between gap-3 px-4 py-3">
              <button
                type="button"
                class="min-w-0 text-left focus:outline-none focus:ring-2 focus:ring-n-brand"
                @click="openRule(rule)"
              >
                <p class="m-0 truncate text-sm font-medium text-n-slate-12">
                  {{ rule.name }}
                </p>
                <p class="m-0 mt-1 text-xs text-n-slate-11">
                  {{
                    eventOptions.find(item => item.value === rule.eventName)
                      ?.label
                  }}
                </p>
              </button>
              <div class="flex shrink-0 items-center gap-2">
                <span
                  class="rounded-full px-2 py-1 text-xs font-medium"
                  :class="
                    rule.active
                      ? 'bg-n-green-3 text-n-green-11'
                      : 'bg-n-slate-3 text-n-slate-11'
                  "
                >
                  {{
                    rule.active
                      ? t('KANBAN.AUTOMATIONS_WORKSPACE.ACTIVE')
                      : t('KANBAN.AUTOMATIONS_WORKSPACE.DRAFT')
                  }}
                </span>
                <Button
                  type="button"
                  icon="i-lucide-flask-conical"
                  color="slate"
                  size="xs"
                  :data-testid="`kanban-automation-test-rule-${rule.id}`"
                  :aria-expanded="testRuleId === rule.id"
                  :label="t('KANBAN.AUTOMATIONS_WORKSPACE.TEST.OPEN')"
                  @click="toggleRuleTest(rule)"
                />
              </div>
            </div>
            <section
              v-if="testRuleId === rule.id"
              class="grid gap-3 border-t border-n-weak bg-n-surface-2 px-4 py-3"
              :data-testid="`kanban-automation-test-panel-${rule.id}`"
            >
              <div class="flex flex-wrap items-end gap-2">
                <label
                  class="grid min-w-60 flex-1 gap-1 text-xs font-medium text-n-slate-11"
                >
                  {{ t('KANBAN.AUTOMATIONS_WORKSPACE.TEST.CARD') }}
                  <select
                    v-model="selectedTestCardId"
                    :data-testid="`kanban-automation-test-card-${rule.id}`"
                    class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                    :disabled="isLoadingTestCards || !testCardOptions.length"
                  >
                    <option value="">
                      {{ t('KANBAN.AUTOMATIONS_WORKSPACE.TEST.SELECT_CARD') }}
                    </option>
                    <option
                      v-for="card in testCardOptions"
                      :key="card.value"
                      :value="card.value"
                    >
                      {{ card.label }}
                    </option>
                  </select>
                </label>
                <Button
                  type="button"
                  icon="i-lucide-play"
                  color="blue"
                  size="sm"
                  :data-testid="`kanban-automation-run-test-${rule.id}`"
                  :label="t('KANBAN.AUTOMATIONS_WORKSPACE.TEST.RUN')"
                  :is-loading="isTestingRule"
                  :disabled="!selectedTestCardId || isLoadingTestCards"
                  @click="runRuleTest(rule)"
                />
              </div>
              <p v-if="isLoadingTestCards" class="m-0 text-xs text-n-slate-11">
                {{ t('KANBAN.AUTOMATIONS_WORKSPACE.TEST.LOADING_CARDS') }}
              </p>
              <p
                v-else-if="!testCardOptions.length"
                class="m-0 text-xs text-n-slate-11"
              >
                {{ t('KANBAN.AUTOMATIONS_WORKSPACE.TEST.NO_CARDS') }}
              </p>
              <p
                v-if="testError"
                class="m-0 text-xs text-n-ruby-11"
                role="alert"
              >
                {{ testError }}
              </p>
              <div
                v-if="testResult"
                class="grid gap-2 rounded-md border border-n-weak bg-n-surface-1 p-3"
                role="status"
              >
                <p class="m-0 text-sm font-medium text-n-slate-12">
                  {{
                    testResult.matches
                      ? t('KANBAN.AUTOMATIONS_WORKSPACE.TEST.RESULT_MATCHES')
                      : t('KANBAN.AUTOMATIONS_WORKSPACE.TEST.RESULT_NO_MATCH')
                  }}
                </p>
                <ol
                  v-if="testResult.steps?.length"
                  class="m-0 grid gap-1 pl-4 text-xs text-n-slate-11"
                >
                  <li v-for="step in testResult.steps" :key="step.nodeId">
                    {{ previewStepLabel(step) }}
                  </li>
                </ol>
                <p v-else class="m-0 text-xs text-n-slate-11">
                  {{ t('KANBAN.AUTOMATIONS_WORKSPACE.TEST.NO_STEPS') }}
                </p>
              </div>
            </section>
          </article>
        </div>
        <div v-else class="grid max-w-xl justify-items-start gap-2 py-10">
          <i class="i-lucide-git-branch size-8 text-n-slate-10" />
          <h2 class="m-0 text-base font-semibold text-n-slate-12">
            {{ t('KANBAN.AUTOMATIONS_WORKSPACE.EMPTY_TITLE') }}
          </h2>
          <p class="m-0 text-sm text-n-slate-11">
            {{ t('KANBAN.AUTOMATIONS_WORKSPACE.EMPTY_DESCRIPTION') }}
          </p>
          <Button
            type="button"
            icon="i-lucide-plus"
            :label="t('KANBAN.AUTOMATIONS_WORKSPACE.NEW_FLOW')"
            color="blue"
            size="sm"
            @click="openNewFlow"
          />
        </div>
      </template>
      <template v-else-if="activeTab === 'reminders'">
        <div class="grid max-w-3xl gap-3">
          <div class="flex justify-end">
            <Button
              type="button"
              icon="i-lucide-plus"
              :label="t('KANBAN.AUTOMATIONS_WORKSPACE.NEW_REMINDER')"
              color="blue"
              size="sm"
              @click="showReminderForm = !showReminderForm"
            />
          </div>
          <section
            v-if="showReminderForm"
            class="grid gap-3 rounded-md border border-n-weak bg-n-surface-2 p-4"
          >
            <div class="grid gap-3 md:grid-cols-2">
              <label class="grid gap-1 text-xs font-medium text-n-slate-11">
                {{ t('KANBAN.SETTINGS.AUTOMATIONS.APPOINTMENT.TRIGGER_STAGE') }}
                <select
                  v-model="reminderForm.triggerStageId"
                  class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                >
                  <option value="">
                    {{
                      t('KANBAN.SETTINGS.AUTOMATIONS.APPOINTMENT.SELECT_STAGE')
                    }}
                  </option>
                  <option
                    v-for="stage in stages"
                    :key="stage.id"
                    :value="stage.id"
                  >
                    {{ stage.name }}
                  </option>
                </select>
              </label>
              <label class="grid gap-1 text-xs font-medium text-n-slate-11">
                {{ t('KANBAN.SETTINGS.AUTOMATIONS.APPOINTMENT.DATE_FIELD') }}
                <select
                  v-model="reminderForm.fieldKey"
                  class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                >
                  <option
                    v-for="field in reminderDateFields"
                    :key="field.key"
                    :value="field.key"
                  >
                    {{ field.label }}
                  </option>
                </select>
              </label>
            </div>
            <label class="grid gap-1 text-xs font-medium text-n-slate-11">
              {{ t('KANBAN.SETTINGS.AUTOMATIONS.APPOINTMENT.ADVANCE_HOURS') }}
              <input
                v-model="reminderForm.offsets"
                type="text"
                :placeholder="
                  t('KANBAN.SETTINGS.AUTOMATIONS.APPOINTMENT.PLACEHOLDER_HOURS')
                "
                class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
              />
            </label>
            <div class="flex flex-wrap gap-3 text-sm text-n-slate-12">
              <label class="flex items-center gap-2">
                <input
                  v-model="reminderForm.channels"
                  value="whatsapp"
                  type="checkbox"
                  class="size-4 rounded border-n-weak text-n-brand focus:ring-n-brand"
                />
                {{ t('KANBAN.SETTINGS.AUTOMATIONS.BIRTHDAY.WHATSAPP') }}
              </label>
              <label class="flex items-center gap-2">
                <input
                  v-model="reminderForm.channels"
                  value="email"
                  type="checkbox"
                  class="size-4 rounded border-n-weak text-n-brand focus:ring-n-brand"
                />
                {{ t('KANBAN.SETTINGS.AUTOMATIONS.BIRTHDAY.EMAIL') }}
              </label>
            </div>
            <label class="grid gap-1 text-xs font-medium text-n-slate-11">
              {{ t('KANBAN.SETTINGS.AUTOMATIONS.APPOINTMENT.OPT_IN') }}
              <input
                v-model="reminderForm.optInAttributeKey"
                type="text"
                class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
              />
            </label>
            <div
              v-if="reminderOffsets.length"
              class="grid gap-2 rounded-md border border-n-weak bg-n-surface-1 p-3"
            >
              <p class="m-0 text-xs font-medium text-n-slate-11">
                {{
                  t('KANBAN.SETTINGS.AUTOMATIONS.APPOINTMENT.MESSAGES_TITLE')
                }}
              </p>
              <label
                v-for="offset in reminderOffsets"
                :key="offset"
                class="grid gap-1 text-xs font-medium text-n-slate-11"
                >{{
                  t('KANBAN.SETTINGS.AUTOMATIONS.APPOINTMENT.MESSAGE_FOR', {
                    hours: offset,
                  })
                }}<textarea
                  :value="
                    reminderForm.messageTemplates[offset] ||
                    defaultReminderMessage
                  "
                  rows="2"
                  class="resize-y rounded-md border border-n-weak bg-n-surface-2 px-3 py-2 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                  @input="
                    reminderForm.messageTemplates[offset] = $event.target.value
                  "
                />
              </label>
            </div>
            <div class="flex justify-end">
              <Button
                type="button"
                data-testid="kanban-automations-save-reminder"
                icon="i-lucide-calendar-clock"
                :label="t('KANBAN.SETTINGS.AUTOMATIONS.APPOINTMENT.ACTIVATE')"
                color="blue"
                size="sm"
                :is-loading="isSavingReminder"
                @click="saveReminder"
              />
            </div>
          </section>
          <article
            v-for="item in appointmentReminders"
            :key="item.id"
            class="flex items-center justify-between gap-3 rounded-md border border-n-weak bg-n-surface-1 px-4 py-3"
          >
            <p class="m-0 text-sm text-n-slate-12">
              {{ item.offsets.join(', ')
              }}{{ t('KANBAN.SETTINGS.AUTOMATIONS.APPOINTMENT.HOURS_BEFORE') }}
              {{ item.channels.join(', ') }}
            </p>
            <Button
              type="button"
              icon="i-lucide-trash-2"
              color="ruby"
              size="xs"
              :aria-label="t('KANBAN.SETTINGS.AUTOMATIONS.APPOINTMENT.DISABLE')"
              @click="deleteReminder(item)"
            />
          </article>
          <p
            v-if="!appointmentReminders.length"
            class="m-0 text-sm text-n-slate-11"
          >
            {{ t('KANBAN.AUTOMATIONS_WORKSPACE.NO_ITEMS') }}
          </p>
        </div>
      </template>
      <template v-else-if="activeTab === 'connections'">
        <div class="grid max-w-3xl gap-3">
          <div class="flex justify-end">
            <Button
              type="button"
              icon="i-lucide-plus"
              :label="t('KANBAN.AUTOMATIONS_WORKSPACE.CONNECTIONS.NEW')"
              color="blue"
              size="sm"
              @click="toggleConnectionForm"
            />
          </div>
          <section
            v-if="showConnectionForm"
            class="grid gap-3 rounded-md border border-n-weak bg-n-surface-2 p-4 md:grid-cols-[minmax(0,1fr)_minmax(0,1fr)_auto]"
          >
            <label class="grid gap-1 text-xs font-medium text-n-slate-11">
              {{ t('KANBAN.AUTOMATIONS_WORKSPACE.CONNECTIONS.NAME') }}
              <input
                v-model="connectionForm.name"
                data-testid="kanban-automation-connection-name"
                type="text"
                class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
              />
            </label>
            <label class="grid gap-1 text-xs font-medium text-n-slate-11">
              {{ t('KANBAN.AUTOMATIONS_WORKSPACE.CONNECTIONS.URL') }}
              <input
                v-model="connectionForm.webhookUrl"
                type="url"
                inputmode="url"
                :placeholder="
                  t('KANBAN.AUTOMATIONS_WORKSPACE.CONNECTIONS.URL_PLACEHOLDER')
                "
                class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
              />
            </label>
            <div class="flex items-end">
              <Button
                type="button"
                icon="i-lucide-save"
                :label="t('KANBAN.ACTIONS.SAVE')"
                color="blue"
                size="sm"
                :is-loading="isSavingConnection"
                @click="saveConnection"
              />
            </div>
          </section>
          <section
            v-if="connectionSecret"
            class="grid gap-1 rounded-md border border-n-weak bg-n-surface-2 p-3"
            role="status"
          >
            <p class="m-0 text-xs font-medium text-n-slate-12">
              {{ t('KANBAN.AUTOMATIONS_WORKSPACE.CONNECTIONS.SECRET_TITLE') }}
            </p>
            <code class="break-all text-xs text-n-slate-11">{{
              connectionSecret
            }}</code>
          </section>
          <article
            v-for="connection in connections"
            :key="connection.id"
            class="rounded-md border border-n-weak bg-n-surface-1"
          >
            <div class="flex items-center justify-between gap-3 px-4 py-3">
              <div class="min-w-0">
                <p class="m-0 truncate text-sm font-medium text-n-slate-12">
                  {{ connection.name }}
                </p>
                <p class="m-0 mt-1 truncate text-xs text-n-slate-11">
                  {{
                    t('KANBAN.AUTOMATIONS_WORKSPACE.CONNECTIONS.OUTBOUND_URL', {
                      url: connection.webhookUrl,
                    })
                  }}
                </p>
              </div>
              <div class="flex shrink-0 items-center gap-1">
                <Button
                  type="button"
                  icon="i-lucide-chevron-down"
                  color="slate"
                  size="xs"
                  :aria-expanded="expandedConnectionId === connection.id"
                  :aria-label="
                    expandedConnectionId === connection.id
                      ? t(
                          'KANBAN.AUTOMATIONS_WORKSPACE.CONNECTIONS.HIDE_DETAILS'
                        )
                      : t(
                          'KANBAN.AUTOMATIONS_WORKSPACE.CONNECTIONS.SHOW_DETAILS'
                        )
                  "
                  :data-testid="`kanban-automation-connection-details-${connection.id}`"
                  @click="toggleConnectionDetails(connection.id)"
                />
                <Button
                  type="button"
                  icon="i-lucide-key-round"
                  color="slate"
                  size="xs"
                  :aria-label="
                    t('KANBAN.AUTOMATIONS_WORKSPACE.CONNECTIONS.RESET_SECRET')
                  "
                  @click="resetConnectionSecret(connection)"
                />
                <Button
                  type="button"
                  icon="i-lucide-trash-2"
                  color="ruby"
                  size="xs"
                  :aria-label="t('KANBAN.ACTIONS.DELETE')"
                  @click="deleteConnection(connection)"
                />
              </div>
            </div>
            <section
              v-if="expandedConnectionId === connection.id"
              :data-testid="`kanban-automation-connection-panel-${connection.id}`"
              class="grid gap-3 border-t border-n-weak bg-n-surface-2 px-4 py-3 text-xs text-n-slate-11"
            >
              <div class="grid gap-1">
                <p class="m-0 font-medium text-n-slate-12">
                  {{
                    t('KANBAN.AUTOMATIONS_WORKSPACE.CONNECTIONS.OUTBOUND_TITLE')
                  }}
                </p>
                <div class="flex items-center gap-2">
                  <code
                    class="min-w-0 flex-1 break-all rounded bg-n-surface-1 px-2 py-1 text-xs text-n-slate-12"
                  >
                    {{ connection.webhookUrl }}
                  </code>
                  <Button
                    type="button"
                    icon="i-lucide-copy"
                    color="slate"
                    size="xs"
                    :aria-label="
                      t('KANBAN.AUTOMATIONS_WORKSPACE.CONNECTIONS.COPY_URL')
                    "
                    @click="copyConnectionUrl(connection.webhookUrl)"
                  />
                </div>
              </div>
              <div v-if="connection.inboundWebhookUrl" class="grid gap-1">
                <p class="m-0 font-medium text-n-slate-12">
                  {{
                    t('KANBAN.AUTOMATIONS_WORKSPACE.CONNECTIONS.INBOUND_TITLE')
                  }}
                </p>
                <p class="m-0">
                  {{
                    t(
                      'KANBAN.AUTOMATIONS_WORKSPACE.CONNECTIONS.INBOUND_DESCRIPTION'
                    )
                  }}
                </p>
                <div class="flex items-center gap-2">
                  <code
                    class="min-w-0 flex-1 break-all rounded bg-n-surface-1 px-2 py-1 text-xs text-n-slate-12"
                  >
                    {{ connection.inboundWebhookUrl }}
                  </code>
                  <Button
                    type="button"
                    icon="i-lucide-copy"
                    color="slate"
                    size="xs"
                    :aria-label="
                      t('KANBAN.AUTOMATIONS_WORKSPACE.CONNECTIONS.COPY_URL')
                    "
                    @click="copyConnectionUrl(connection.inboundWebhookUrl)"
                  />
                </div>
                <p class="m-0">
                  {{
                    t(
                      'KANBAN.AUTOMATIONS_WORKSPACE.CONNECTIONS.INBOUND_HEADERS'
                    )
                  }}
                </p>
              </div>
            </section>
          </article>
          <p v-if="!connections.length" class="m-0 text-sm text-n-slate-11">
            {{ t('KANBAN.AUTOMATIONS_WORKSPACE.CONNECTIONS.EMPTY') }}
          </p>
        </div>
      </template>
      <template v-else>
        <div class="grid max-w-5xl gap-2">
          <article
            v-for="execution in executions"
            :key="execution.id"
            class="flex items-center justify-between gap-3 rounded-md border border-n-weak bg-n-surface-1 px-4 py-3"
          >
            <div class="min-w-0">
              <p class="m-0 truncate text-sm font-medium text-n-slate-12">
                {{ execution.ruleName }}
              </p>
              <p class="m-0 mt-1 text-xs text-n-slate-11">
                {{
                  t('KANBAN.AUTOMATIONS_WORKSPACE.EXECUTIONS.DETAILS', {
                    event: execution.eventName,
                    id: execution.cardId || '-',
                  })
                }}
              </p>
              <p
                v-if="execution.errorMessage"
                class="m-0 mt-1 text-xs text-n-ruby-11"
              >
                {{ execution.errorMessage }}
              </p>
            </div>
            <div class="flex shrink-0 items-center gap-2">
              <span
                class="rounded-full bg-n-surface-2 px-2 py-1 text-xs font-medium text-n-slate-11"
              >
                {{ execution.status }}
              </span>
              <Button
                v-if="execution.status === 'waiting'"
                type="button"
                icon="i-lucide-ban"
                color="slate"
                size="xs"
                :aria-label="
                  t('KANBAN.SETTINGS.AUTOMATIONS.RULES.CANCEL_EXECUTION')
                "
                @click="cancelExecution(execution)"
              />
              <Button
                v-if="['failed', 'skipped'].includes(execution.status)"
                type="button"
                icon="i-lucide-rotate-cw"
                color="slate"
                size="xs"
                :aria-label="t('KANBAN.AUTOMATIONS_WORKSPACE.EXECUTIONS.RETRY')"
                @click="retryExecution(execution)"
              />
            </div>
          </article>
          <p v-if="!executions.length" class="m-0 text-sm text-n-slate-11">
            {{ t('KANBAN.AUTOMATIONS_WORKSPACE.EXECUTIONS.EMPTY') }}
          </p>
        </div>
      </template>
    </section>
  </main>
</template>
