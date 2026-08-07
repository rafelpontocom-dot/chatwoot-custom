<script setup>
import {
  computed,
  defineAsyncComponent,
  nextTick,
  onMounted,
  reactive,
  ref,
  watch,
} from 'vue';
import { useI18n } from 'vue-i18n';
import { DirectUpload } from 'activestorage';
import { vOnClickOutside } from '@vueuse/components';
import { useRoute, useRouter } from 'vue-router';
import camelcaseKeys from 'camelcase-keys';

import { useAlert } from 'dashboard/composables';
import { useMapGetter } from 'dashboard/composables/store';
import KanbanBoardsAPI from 'dashboard/api/kanbanBoards';
import Button from 'dashboard/components-next/button/Button.vue';
import ConfirmButton from 'dashboard/components-next/button/ConfirmButton.vue';
import Popover from 'dashboard/components-next/popover/Popover.vue';
import { copyTextToClipboard } from 'shared/helpers/clipboard';
import KanbanWorkflowBuilder from './components/KanbanWorkflowBuilder.vue';
import {
  getKanbanWorkflowNodeDefinition,
  getKanbanWorkflowNodeLabel,
} from './components/kanbanWorkflowNodeDefinitions';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const agents = useMapGetter('agents/getAgents');
const teams = useMapGetter('teams/getTeams');

const boardId = computed(() => Number(route.params.boardId));
const activeTab = ref('flows');
const isLoading = ref(false);
const isSaving = ref(false);
const error = ref('');
const rules = ref([]);
const appointmentReminders = ref([]);
const connections = ref([]);
const connectionAudits = ref([]);
const executions = ref([]);
const historicalNodeMetrics = ref([]);
const settings = ref({});
const lostReasonOptions = computed(
  () =>
    settings.value.lostReasonOptions || settings.value.lost_reason_options || []
);
const selectedRuleId = ref(null);
const selectedExecutionId = ref('');
const showEditor = ref(false);
const showEditorTest = ref(false);
const showBirthdayEditor = ref(false);
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
const versionRuleId = ref(null);
const ruleVersions = ref([]);
const isLoadingVersions = ref(false);
const restoringVersionId = ref(null);
const invalidNodeIds = ref([]);
const isLoadingBirthday = ref(false);
const isSavingBirthday = ref(false);
const birthdayError = ref('');
const birthdayMessageInput = ref(null);
const showBirthdayEmojiPicker = ref(false);
const showBirthdayVariableMenu = ref(false);
const birthdayVariableQuery = ref('');
const isUploadingBirthdayAttachment = ref(false);
const EmojiIconPicker = defineAsyncComponent(
  () =>
    import('dashboard/components-next/emoji-icon-picker/EmojiIconPicker.vue')
);
const birthdayAutomation = reactive({
  active: false,
  daysBefore: 0,
  deliveryChannels: ['whatsapp'],
  optInAttributeKey: 'birthday_messages_opt_in',
  messageLocale: 'pt_BR',
  timezone: 'America/Sao_Paulo',
  timezoneName: 'America/Sao_Paulo',
  sendTime: '09:00',
  messageTemplate: '',
  messageAttachment: {},
});

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
const blankVisualFlow = () => ({
  nodes: [
    { id: 'trigger', type: 'trigger', position: { x: 32, y: 180 }, data: {} },
    { id: 'end', type: 'end', position: { x: 300, y: 180 }, data: {} },
  ],
  edges: [{ id: 'trigger-end', source: 'trigger', target: 'end' }],
});
const ruleFlowPreview = rule =>
  (rule.flowDefinition || rule.flow_definition || {}).nodes
    ?.filter(node => !['trigger', 'end'].includes(node.type))
    .slice(0, 3)
    .map(node => ({
      id: node.id,
      icon: getKanbanWorkflowNodeDefinition(node.type)?.icon,
      label: getKanbanWorkflowNodeLabel(node.type, t),
    })) || [];
const hiddenRuleFlowStepCount = rule =>
  Math.max(
    0,
    ((rule.flowDefinition || rule.flow_definition || {}).nodes || []).filter(
      node => !['trigger', 'end'].includes(node.type)
    ).length - 3
  );

const form = reactive({
  name: '',
  description: '',
  eventName: 'kanban.card.stage_changed',
  triggerEventNames: ['kanban.card.stage_changed'],
  active: false,
  lockVersion: 0,
  reentryEnabled: false,
  cancelWaitingExecutions: false,
  stageId: '',
  ownerId: '',
  changedFieldKey: '',
  changedFieldValue: '',
  connectionId: '',
  customerMessageMode: 'any',
  customerMessageContains: '',
  triggerNextActionType: '',
  triggerAmountOperator: 'greater_than',
  triggerAmountValue: '',
  triggerAmountMode: 'any',
  triggerLostReason: '',
  fieldKey: '',
  fieldOperator: 'equals',
  fieldValue: '',
  actions: [blankAction()],
  flowDefinition: {},
});

const ruleDraftStorageKey = ruleId =>
  `chatwoot:kanban-automation-rule:${boardId.value}:${ruleId}`;

const copyDraftForm = source => JSON.parse(JSON.stringify(source));

const restoreRuleDraft = rule => {
  if (!rule?.id || typeof window === 'undefined') return false;

  try {
    const draft = JSON.parse(
      window.localStorage.getItem(ruleDraftStorageKey(rule.id)) || 'null'
    );
    if (draft?.lockVersion !== form.lockVersion) return false;

    const { actions, ...draftForm } = draft;
    Object.assign(form, draftForm);
    form.actions.splice(0, form.actions.length, ...(actions || []));
    return true;
  } catch {
    window.localStorage.removeItem(ruleDraftStorageKey(rule.id));
    return false;
  }
};

const clearRuleDraft = ruleId => {
  if (!ruleId || typeof window === 'undefined') return;

  window.localStorage.removeItem(ruleDraftStorageKey(ruleId));
};

const reminderForm = reactive({
  triggerStageId: '',
  fieldKey: 'system_starts_at',
  offsets: '48,24,2',
  channels: ['whatsapp'],
  optInAttributeKey: 'appointment_reminders_opt_in',
  messageTemplates: {},
});
const connectionForm = reactive({ name: '', webhookUrl: '' });
const connectionAuditLabels = computed(() => ({
  created: t('KANBAN.AUTOMATIONS_WORKSPACE.CONNECTIONS.AUDIT_ACTIONS.created'),
  updated: t('KANBAN.AUTOMATIONS_WORKSPACE.CONNECTIONS.AUDIT_ACTIONS.updated'),
  deleted: t('KANBAN.AUTOMATIONS_WORKSPACE.CONNECTIONS.AUDIT_ACTIONS.deleted'),
  secret_reset: t(
    'KANBAN.AUTOMATIONS_WORKSPACE.CONNECTIONS.AUDIT_ACTIONS.secret_reset'
  ),
}));
const connectionAuditLabel = action =>
  connectionAuditLabels.value[action] || action;
const connectionAuditDescription = audit =>
  audit.metadata?.connectionName
    ? `${connectionAuditLabel(audit.action)}: ${audit.metadata.connectionName}`
    : connectionAuditLabel(audit.action);
const connectionAuditTime = timestamp =>
  new Intl.DateTimeFormat(undefined, {
    dateStyle: 'short',
    timeStyle: 'short',
  }).format(new Date(timestamp));
const defaultReminderMessage =
  'Olá, {{contact_name}}! Lembramos que sua consulta será em {{appointment_date}}.';
const defaultGoogleReviewMessage =
  'Olá, {{contact_name}}! Sua opinião é muito importante para nós. Você poderia avaliar sua experiência no Google?';
const birthdayVariables = computed(() => [
  {
    label: t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.VARIABLES.CONTACT_NAME'),
    token: '{{contact_name}}',
  },
  {
    label: t('KANBAN.SETTINGS.AUTOMATIONS.BIRTHDAY.BIRTHDAY_DATE'),
    token: '{{birthday_date}}',
  },
]);
const filteredBirthdayVariables = computed(() => {
  const query = birthdayVariableQuery.value.trim().toLocaleLowerCase();
  if (!query) return birthdayVariables.value;

  return birthdayVariables.value.filter(variable =>
    `${variable.label} ${variable.token}`.toLocaleLowerCase().includes(query)
  );
});
const birthdayAttachmentUrl = computed(() => {
  const attachment = birthdayAutomation.messageAttachment || {};
  if (!attachment.signedId || !attachment.filename) return '';

  return `/rails/active_storage/blobs/redirect/${encodeURIComponent(attachment.signedId)}/${encodeURIComponent(attachment.filename)}`;
});
const birthdayPreview = computed(() =>
  birthdayAutomation.messageTemplate
    .replaceAll(
      '{{contact_name}}',
      t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.PREVIEW_CONTACT')
    )
    .replaceAll(
      '{{birthday_date}}',
      t('KANBAN.SETTINGS.AUTOMATIONS.BIRTHDAY.PREVIEW_DATE')
    )
);

const eventOptions = computed(() => [
  {
    value: 'kanban.card.created',
    label: t('KANBAN.SETTINGS.AUTOMATIONS.EVENTS.CREATED'),
  },
  {
    value: 'kanban.appointment.created',
    label: t('KANBAN.SETTINGS.AUTOMATIONS.EVENTS.APPOINTMENT_CREATED'),
  },
  {
    value: 'kanban.appointment.rescheduled',
    label: t('KANBAN.SETTINGS.AUTOMATIONS.EVENTS.APPOINTMENT_RESCHEDULED'),
  },
  {
    value: 'kanban.appointment.canceled',
    label: t('KANBAN.SETTINGS.AUTOMATIONS.EVENTS.APPOINTMENT_CANCELED'),
  },
  {
    value: 'kanban.appointment.confirmed',
    label: t('KANBAN.SETTINGS.AUTOMATIONS.EVENTS.APPOINTMENT_CONFIRMED'),
  },
  {
    value: 'kanban.appointment.completed',
    label: t('KANBAN.SETTINGS.AUTOMATIONS.EVENTS.APPOINTMENT_COMPLETED'),
  },
  {
    value: 'kanban.appointment.no_show',
    label: t('KANBAN.SETTINGS.AUTOMATIONS.EVENTS.APPOINTMENT_NO_SHOW'),
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
    value: 'kanban.card.fields_changed',
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
    value: 'kanban.card.next_action_overdue',
    label: t('KANBAN.SETTINGS.AUTOMATIONS.EVENTS.NEXT_ACTION_OVERDUE'),
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
const triggerContext = computed(() => {
  const contexts = {
    'kanban.card.created': 'stage',
    'kanban.card.stage_changed': 'stage',
    'kanban.card.customer_message_received': 'customer_message',
    'kanban.card.owner_changed': 'owner',
    'kanban.card.fields_changed': 'changed_field',
    'kanban.card.webhook_received': 'webhook',
    'kanban.card.next_action_scheduled': 'next_action',
    'kanban.card.next_action_completed': 'next_action',
    'kanban.card.next_action_overdue': 'next_action',
    'kanban.card.amount_changed': 'amount',
    'kanban.card.lost': 'lost_reason',
  };

  return contexts[form.eventName] || null;
});

const stageTriggerEvents = ['kanban.card.created', 'kanban.card.stage_changed'];

const onTriggerEventChanged = () => {
  if (stageTriggerEvents.includes(form.eventName)) {
    form.triggerEventNames = [form.eventName];
    return;
  }

  form.triggerEventNames = [form.eventName];
  form.stageId = '';
};

const setFlowTriggerEvent = eventName => {
  form.eventName = eventName;
  onTriggerEventChanged();
};

const updateFlowTriggerConfig = changes => {
  Object.assign(form, changes);
};

const ensureStageTriggerEvent = event => {
  if (form.triggerEventNames.length) return;

  form.triggerEventNames = [form.eventName];
  event.target.checked = true;
};

const automationTabs = computed(() => [
  { key: 'flows', label: t('KANBAN.AUTOMATIONS_WORKSPACE.TABS.FLOWS') },
  {
    key: 'connections',
    label: t('KANBAN.AUTOMATIONS_WORKSPACE.TABS.CONNECTIONS'),
  },
  {
    key: 'executions',
    label: t('KANBAN.AUTOMATIONS_WORKSPACE.TABS.EXECUTIONS'),
  },
]);
const executionStatusOptions = computed(() => [
  {
    value: 'waiting',
    label: t('KANBAN.AUTOMATIONS_WORKSPACE.EXECUTIONS.STATUS.WAITING'),
  },
  {
    value: 'failed',
    label: t('KANBAN.AUTOMATIONS_WORKSPACE.EXECUTIONS.STATUS.FAILED'),
  },
  {
    value: 'queued',
    label: t('KANBAN.AUTOMATIONS_WORKSPACE.EXECUTIONS.STATUS.QUEUED'),
  },
  {
    value: 'running',
    label: t('KANBAN.AUTOMATIONS_WORKSPACE.EXECUTIONS.STATUS.RUNNING'),
  },
  {
    value: 'succeeded',
    label: t('KANBAN.AUTOMATIONS_WORKSPACE.EXECUTIONS.STATUS.SUCCEEDED'),
  },
  {
    value: 'skipped',
    label: t('KANBAN.AUTOMATIONS_WORKSPACE.EXECUTIONS.STATUS.SKIPPED'),
  },
]);
const executionSummary = computed(() =>
  executionStatusOptions.value.map(status => ({
    ...status,
    count: executions.value.filter(
      execution => execution.status === status.value
    ).length,
  }))
);
const automationHealth = computed(() => {
  const now = Date.now();
  const abandonedBefore = now - 15 * 60 * 1000;
  const failedCount = executions.value.filter(
    execution => execution.status === 'failed'
  ).length;
  const overdueCount = executions.value.filter(execution => {
    if (execution.status !== 'waiting' || !execution.scheduledAt) return false;

    const scheduledAt = new Date(execution.scheduledAt).getTime();
    return Number.isFinite(scheduledAt) && scheduledAt < now;
  }).length;
  const abandonedCount = executions.value.filter(execution => {
    if (
      !['queued', 'running'].includes(execution.status) ||
      !execution.createdAt
    ) {
      return false;
    }

    const createdAt = new Date(execution.createdAt).getTime();
    return Number.isFinite(createdAt) && createdAt < abandonedBefore;
  }).length;

  return {
    failedCount,
    overdueCount,
    abandonedCount,
    needsAttention: failedCount > 0 || overdueCount > 0 || abandonedCount > 0,
  };
});
const nodeFailureSummary = computed(() => {
  const failures = executions.value.flatMap(execution =>
    (execution.actionResults || []).filter(result => result.status === 'failed')
  );
  const counts = failures.reduce((summary, result) => {
    const key = result.actionName || result.nodeId || 'unknown';
    summary[key] = (summary[key] || 0) + 1;
    return summary;
  }, {});

  return Object.entries(counts)
    .map(([key, count]) => ({ key, count }))
    .sort((left, right) => right.count - left.count)
    .slice(0, 3);
});
const nodeErrorRates = computed(() => {
  const metrics = executions.value
    .flatMap(execution => execution.actionResults || [])
    .reduce((summary, result) => {
      const key = result.actionName || result.nodeId || 'unknown';
      const metric = summary[key] || { total: 0, failed: 0 };
      metric.total += 1;
      metric.failed += result.status === 'failed' ? 1 : 0;
      summary[key] = metric;
      return summary;
    }, {});

  return Object.entries(metrics)
    .filter(([, metric]) => metric.failed > 0)
    .map(([key, metric]) => ({
      key,
      percentage: Math.round((metric.failed / metric.total) * 100),
    }))
    .sort((left, right) => right.percentage - left.percentage)
    .slice(0, 3);
});
const nodeUsageSummary = computed(() => {
  if (historicalNodeMetrics.value.length) {
    return historicalNodeMetrics.value.map(metric => ({
      key: metric.nodeType,
      total: metric.total,
      failed: metric.failed,
    }));
  }

  const metrics = executions.value
    .flatMap(execution => execution.actionResults || [])
    .reduce((summary, result) => {
      const key =
        result.actionName || result.type || result.nodeId || 'unknown';
      const metric = summary[key] || { total: 0, failed: 0 };
      metric.total += 1;
      metric.failed += result.status === 'failed' ? 1 : 0;
      summary[key] = metric;
      return summary;
    }, {});

  return Object.entries(metrics)
    .map(([key, metric]) => ({ key, ...metric }))
    .sort((left, right) => right.total - left.total)
    .slice(0, 3);
});
const blockedMessageCount = computed(
  () =>
    executions.value
      .flatMap(execution => execution.actionResults || [])
      .filter(
        result =>
          result.actionName === 'send_message' &&
          result.status === 'skipped' &&
          [
            'opt_in_required',
            'outside_whatsapp_window',
            'no_compatible_conversation',
          ].includes(result.reason)
      ).length
);
const selectedRuleExecutionHistory = computed(() =>
  executions.value
    .filter(
      execution =>
        execution.ruleId === selectedRuleId.value &&
        (!selectedExecutionId.value ||
          String(execution.id) === selectedExecutionId.value)
    )
    .flatMap(execution =>
      (execution.actionResults || []).map(result => ({
        ...result,
        executionId: execution.id,
      }))
    )
);

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

const commercialFollowUpTemplate = () => {
  const messages = [
    'Olá, {{contact_name}}. Ficou alguma dúvida sobre o orçamento que enviamos?',
    'Posso ajudar com alguma dúvida para avançarmos com a proposta?',
    'Ainda faz sentido conversarmos sobre o seu orçamento?',
    'Vou encerrar este acompanhamento por agora. Quando quiser retomar, estou à disposição.',
  ];
  const intervals = [48, 48, 72, 168];
  const nodes = [
    { id: 'trigger', type: 'trigger', position: { x: 32, y: 180 }, data: {} },
  ];
  const edges = [];
  let previousId = 'trigger';

  messages.forEach((content, index) => {
    const step = index + 1;
    const ids = {
      inactivity: `inactivity-${step}`,
      stage: `stage-${step}`,
      businessHours: `business-hours-${step}`,
      spread: `spread-${step}`,
      message: `message-${step}`,
      increment: `increment-${step}`,
    };
    const y = 180 + index * 192;
    nodes.push(
      {
        id: ids.inactivity,
        type: 'wait_for_inactivity',
        position: { x: 300, y },
        data: { timeout_hours: intervals[index], interruption_mode: 'stop' },
      },
      {
        id: ids.stage,
        type: 'stage_guard',
        position: { x: 568, y },
        data: {},
      },
      {
        id: ids.businessHours,
        type: 'wait_for_business_hours',
        position: { x: 836, y },
        data: {
          weekdays: [1, 2, 3, 4, 5],
          start_time: '09:00',
          end_time: '18:00',
          timezone: 'America/Sao_Paulo',
          failure_mode: 'stop',
        },
      },
      {
        id: ids.spread,
        type: 'random_delay',
        position: { x: 1104, y },
        data: { min_minutes: 10, max_minutes: 30 },
      },
      {
        id: ids.message,
        type: 'send_message',
        position: { x: 1372, y },
        data: {
          channel: 'whatsapp',
          opt_in_attribute_key: 'marketing_messages_opt_in',
          content,
          frequency_limit_hours: '',
          quiet_hours: { start: '', end: '', timezone: 'America/Sao_Paulo' },
          whatsapp_template_params: {},
          failure_mode: 'stop',
        },
      },
      {
        id: ids.increment,
        type: 'action',
        position: { x: 1640, y },
        data: {
          action_name: 'increment_field',
          action_params: { field_key: '', amount: 1 },
        },
      }
    );
    [
      ids.inactivity,
      ids.stage,
      ids.businessHours,
      ids.spread,
      ids.message,
      ids.increment,
    ].forEach(target => {
      const sourceHandle = /^(inactivity|business-hours|message)-/.test(
        previousId
      )
        ? 'next'
        : undefined;
      edges.push({
        id: `${previousId}-${target}`,
        source: previousId,
        target,
        ...(sourceHandle ? { sourceHandle } : {}),
      });
      previousId = target;
    });
  });

  nodes.push({
    id: 'end',
    type: 'end',
    position: { x: 1908, y: 756 },
    data: {},
  });
  edges.push({ id: `${previousId}-end`, source: previousId, target: 'end' });

  return { nodes, edges };
};

const automationTemplates = computed(() => [
  {
    id: 'whatsapp-sales',
    icon: 'i-lucide-message-circle',
    defaultName: t(
      'KANBAN.AUTOMATIONS_WORKSPACE.TEMPLATES.WHATSAPP_SALES.TITLE'
    ),
    name: t('KANBAN.AUTOMATIONS_WORKSPACE.TEMPLATES.WHATSAPP_SALES.TITLE'),
    description: t(
      'KANBAN.AUTOMATIONS_WORKSPACE.TEMPLATES.WHATSAPP_SALES.DESCRIPTION'
    ),
    eventName: 'kanban.card.created',
    flowDefinition: flowTemplate({ waitForResponse: true }),
  },
  {
    id: 'clinic-appointment',
    icon: 'i-lucide-calendar-clock',
    defaultName: t(
      'KANBAN.AUTOMATIONS_WORKSPACE.TEMPLATES.CLINIC_APPOINTMENT.TITLE'
    ),
    name: t('KANBAN.AUTOMATIONS_WORKSPACE.TEMPLATES.CLINIC_APPOINTMENT.TITLE'),
    description: t(
      'KANBAN.AUTOMATIONS_WORKSPACE.TEMPLATES.CLINIC_APPOINTMENT.DESCRIPTION'
    ),
    eventName: 'kanban.card.stage_changed',
    flowDefinition: flowTemplate({}),
  },
  {
    id: 'b2b-sales',
    icon: 'i-lucide-briefcase-business',
    defaultName: t('KANBAN.AUTOMATIONS_WORKSPACE.TEMPLATES.B2B_SALES.TITLE'),
    name: t('KANBAN.AUTOMATIONS_WORKSPACE.TEMPLATES.B2B_SALES.TITLE'),
    description: t(
      'KANBAN.AUTOMATIONS_WORKSPACE.TEMPLATES.B2B_SALES.DESCRIPTION'
    ),
    eventName: 'kanban.card.stage_changed',
    flowDefinition: flowTemplate({ waitForResponse: true }),
  },
  {
    id: 'blank',
    icon: 'i-lucide-file-plus-2',
    defaultName: t('KANBAN.AUTOMATIONS_WORKSPACE.TEMPLATES.BLANK.TITLE'),
    name: t('KANBAN.AUTOMATIONS_WORKSPACE.TEMPLATES.BLANK.TITLE'),
    description: t('KANBAN.AUTOMATIONS_WORKSPACE.TEMPLATES.BLANK.DESCRIPTION'),
    eventName: 'kanban.card.created',
    flowDefinition: blankVisualFlow(),
  },
  {
    id: 'follow-up',
    icon: 'i-lucide-repeat-2',
    defaultName: 'Follow-up comercial',
    name: t('KANBAN.AUTOMATIONS_WORKSPACE.TEMPLATES.FOLLOW_UP.TITLE'),
    description: t(
      'KANBAN.AUTOMATIONS_WORKSPACE.TEMPLATES.FOLLOW_UP.DESCRIPTION'
    ),
    eventName: 'kanban.card.stage_changed',
    flowDefinition: commercialFollowUpTemplate(),
  },
  {
    id: 'nps-google-review',
    icon: 'i-lucide-star',
    defaultName: 'Pedir avaliação no Google',
    name: t('KANBAN.AUTOMATIONS_WORKSPACE.TEMPLATES.NPS_GOOGLE.TITLE'),
    description: t(
      'KANBAN.AUTOMATIONS_WORKSPACE.TEMPLATES.NPS_GOOGLE.DESCRIPTION'
    ),
    eventName: 'kanban.card.won',
    flowDefinition: flowTemplate({
      message: defaultGoogleReviewMessage,
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
const waitingExecutionsForSelectedRule = computed(() =>
  executions.value.filter(
    execution =>
      execution.ruleId === selectedRuleId.value &&
      execution.status === 'waiting'
  )
);
const selectedRuleExecutions = computed(() =>
  executions.value.filter(
    execution => execution.ruleId === selectedRuleId.value
  )
);
const saveFlowLabel = computed(() =>
  form.active
    ? t('KANBAN.AUTOMATIONS_WORKSPACE.PUBLISH')
    : t('KANBAN.AUTOMATIONS_WORKSPACE.SAVE_DRAFT')
);
const selectedRuleVersions = computed(() =>
  versionRuleId.value ? ruleVersions.value : []
);
const opportunityStatusOptions = computed(() => [
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
]);
const conditionFields = computed(() => [
  {
    key: 'system_subject',
    label: t('KANBAN.SETTINGS.SALES.SYSTEM_FIELDS.SUBJECT'),
  },
  {
    key: 'system_amount',
    label: t('KANBAN.SETTINGS.SALES.SYSTEM_FIELDS.AMOUNT'),
  },
  {
    key: 'system_stage_id',
    label: t('KANBAN.SETTINGS.SALES.SYSTEM_FIELDS.STAGE'),
    conditionOptions: stages.value.map(stage => ({
      value: String(stage.id),
      label: stage.name,
    })),
  },
  {
    key: 'system_status',
    label: t('KANBAN.SETTINGS.SALES.SYSTEM_FIELDS.STATUS'),
    conditionOptions: opportunityStatusOptions.value,
  },
  {
    key: 'system_owner_id',
    label: t('KANBAN.SETTINGS.SALES.SYSTEM_FIELDS.OWNER'),
    conditionOptions: agentOptions.value.map(agent => ({
      value: String(agent.value),
      label: agent.label,
    })),
  },
  {
    key: 'system_inbox_id',
    label: t('KANBAN.SETTINGS.SALES.SYSTEM_FIELDS.INBOX'),
  },
  {
    key: 'system_description',
    label: t('KANBAN.SETTINGS.SALES.SYSTEM_FIELDS.DESCRIPTION'),
  },
  {
    key: 'system_starts_at',
    label: t('KANBAN.SETTINGS.SALES.SYSTEM_FIELDS.STARTS_AT'),
  },
  {
    key: 'system_due_at',
    label: t('KANBAN.SETTINGS.SALES.SYSTEM_FIELDS.DUE_AT'),
  },
  {
    key: 'system_next_action_type',
    label: t('KANBAN.SETTINGS.SALES.SYSTEM_FIELDS.NEXT_ACTION_TYPE'),
    conditionOptions: nextActionTypes.value.map(value => ({
      value,
      label: value,
    })),
  },
  {
    key: 'system_next_action_at',
    label: t('KANBAN.SETTINGS.SALES.SYSTEM_FIELDS.NEXT_ACTION_AT'),
  },
  {
    key: 'system_appointment_starts_at',
    label: t('CALENDAR.OPPORTUNITY.STARTS_AT'),
  },
  {
    key: 'system_next_action_note',
    label: t('KANBAN.SETTINGS.SALES.SYSTEM_FIELDS.NEXT_ACTION_NOTE'),
  },
  {
    key: 'system_next_action_completed',
    label: t('KANBAN.SETTINGS.SALES.SYSTEM_FIELDS.NEXT_ACTION_COMPLETED'),
  },
  {
    key: 'system_lost_reason',
    label: t('KANBAN.SETTINGS.SALES.SYSTEM_FIELDS.LOST_REASON'),
    conditionOptions: lostReasonOptions.value.map(value => ({
      value,
      label: value,
    })),
  },
  {
    key: 'system_contact_id',
    label: t('KANBAN.SETTINGS.SALES.SYSTEM_FIELDS.CONTACT'),
  },
  {
    key: 'system_conversation_id',
    label: t('KANBAN.SETTINGS.SALES.SYSTEM_FIELDS.CONVERSATION'),
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
const triggerSummary = computed(() => {
  const eventLabel = eventOptions.value.find(
    event => event.value === form.eventName
  )?.label;
  if (triggerContext.value === 'stage' && form.stageId) {
    const stage = stages.value.find(
      item => String(item.id) === String(form.stageId)
    );
    return `${eventLabel}: ${stage?.name || t('KANBAN.SETTINGS.AUTOMATIONS.RULES.ANY_STAGE')}`;
  }
  if (triggerContext.value === 'owner' && form.ownerId) {
    const owner = agentOptions.value.find(
      item => String(item.value) === String(form.ownerId)
    );
    return `${eventLabel}: ${owner?.label || t('KANBAN.SETTINGS.AUTOMATIONS.RULES.ANY_OWNER')}`;
  }
  if (triggerContext.value === 'changed_field' && form.changedFieldKey) {
    const field = conditionFields.value.find(
      item => item.key === form.changedFieldKey
    );
    const selectedValue = field?.conditionOptions?.find(
      item => String(item.value) === String(form.changedFieldValue)
    );
    const summary = field?.label || form.changedFieldKey;
    return selectedValue
      ? `${eventLabel}: ${summary} = ${selectedValue.label}`
      : `${eventLabel}: ${summary}`;
  }
  if (triggerContext.value === 'webhook' && form.connectionId) {
    const connection = connections.value.find(
      item => String(item.id) === String(form.connectionId)
    );
    return `${eventLabel}: ${connection?.name || t('KANBAN.SETTINGS.AUTOMATIONS.RULES.ANY_CONNECTION')}`;
  }
  return eventLabel || t('KANBAN.SETTINGS.AUTOMATIONS.RULES.EVENT');
});
const dateFields = computed(() => [
  {
    key: 'system_starts_at',
    label: t('KANBAN.SETTINGS.SALES.SYSTEM_FIELDS.STARTS_AT'),
  },
  {
    key: 'system_due_at',
    label: t('KANBAN.SETTINGS.SALES.SYSTEM_FIELDS.DUE_AT'),
  },
  {
    key: 'system_next_action_at',
    label: t('KANBAN.SETTINGS.SALES.SYSTEM_FIELDS.NEXT_ACTION_AT'),
  },
  ...customFields.value.filter(field =>
    ['date', 'datetime'].includes(field.fieldType)
  ),
]);
const reminderDateFields = computed(() => [...dateFields.value]);
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
const selectedRule = computed(() =>
  rules.value.find(rule => rule.id === selectedRuleId.value)
);

const normalize = value => camelcaseKeys(value || {}, { deep: true });
const resetForm = () => {
  selectedRuleId.value = null;
  selectedExecutionId.value = '';
  showEditorTest.value = false;
  form.name = '';
  form.description = '';
  form.eventName = 'kanban.card.stage_changed';
  form.triggerEventNames = ['kanban.card.stage_changed'];
  form.active = false;
  form.lockVersion = 0;
  form.reentryEnabled = false;
  form.cancelWaitingExecutions = false;
  form.stageId = '';
  form.ownerId = '';
  form.changedFieldKey = '';
  form.changedFieldValue = '';
  form.connectionId = '';
  form.customerMessageContains = '';
  form.customerMessageMode = 'any';
  form.triggerNextActionType = '';
  form.triggerAmountOperator = 'greater_than';
  form.triggerAmountValue = '';
  form.triggerAmountMode = 'any';
  form.triggerLostReason = '';
  form.fieldKey = '';
  form.fieldOperator = 'equals';
  form.fieldValue = '';
  form.flowDefinition = {};
  form.actions.splice(0, form.actions.length, blankAction());
};

const applyRule = rule => {
  const normalized = normalize(rule);
  const conditions = normalized.conditions || {};
  const changedFieldKey = conditions.changedFieldKeys?.[0] || '';
  const changedFieldCondition = conditions.fields?.find(
    item => item.fieldKey === changedFieldKey
  );
  const field =
    conditions.fields?.find(
      item =>
        ![
          'system_next_action_type',
          'system_amount',
          'system_lost_reason',
        ].includes(item.fieldKey) && item.fieldKey !== changedFieldKey
    ) || {};
  selectedRuleId.value = normalized.id;
  selectedExecutionId.value = '';
  form.name = normalized.name || '';
  form.description = normalized.description || '';
  form.eventName = normalized.eventName || 'kanban.card.stage_changed';
  form.triggerEventNames = conditions.triggerEventNames?.length
    ? conditions.triggerEventNames
    : [form.eventName];
  form.active = normalized.active !== false;
  form.lockVersion = normalized.lockVersion || 0;
  form.reentryEnabled = normalized.reentryEnabled === true;
  form.cancelWaitingExecutions = false;
  form.stageId = conditions.stageIds?.[0] || '';
  form.ownerId = conditions.ownerIds?.[0] || '';
  form.changedFieldKey = changedFieldKey;
  form.changedFieldValue = changedFieldCondition?.value || '';
  form.connectionId = conditions.connectionIds?.[0] || '';
  form.customerMessageContains = conditions.customerMessageContains || '';
  form.customerMessageMode = conditions.customerMessageContains
    ? 'contains'
    : 'any';
  const nextActionCondition = conditions.fields?.find(
    item => item.fieldKey === 'system_next_action_type'
  );
  const amountCondition = conditions.fields?.find(
    item => item.fieldKey === 'system_amount'
  );
  form.triggerNextActionType = nextActionCondition?.value || '';
  form.triggerAmountOperator = amountCondition?.operator || 'greater_than';
  form.triggerAmountValue = amountCondition?.value || '';
  form.triggerAmountMode = amountCondition ? 'new_value' : 'any';
  const lostReasonCondition = conditions.fields?.find(
    item => item.fieldKey === 'system_lost_reason'
  );
  form.triggerLostReason = lostReasonCondition?.value || '';
  form.fieldKey = field.fieldKey || '';
  form.fieldOperator = field.operator || 'equals';
  form.fieldValue = field.value || '';
  form.flowDefinition = normalized.flowDefinition || {};
  form.actions.splice(0, form.actions.length, ...(normalized.actions || []));
};

const openNewFlow = () => {
  resetForm();
  form.flowDefinition = blankVisualFlow();
  activeTab.value = 'flows';
  showEditor.value = true;
};
const openTemplate = template => {
  resetForm();
  form.name = template.defaultName || template.name;
  form.description = template.description;
  form.eventName = template.eventName;
  form.triggerEventNames = [template.eventName];
  form.active = false;
  form.flowDefinition = template.flowDefinition;
  activeTab.value = 'flows';
  showEditor.value = true;
};
const openRule = rule => {
  applyRule(rule);
  showEditorTest.value = false;
  const restoredDraft = restoreRuleDraft(rule);
  activeTab.value = 'flows';
  showEditor.value = true;
  if (restoredDraft) {
    useAlert(t('KANBAN.SETTINGS.AUTOMATIONS.RULES.DRAFT_RESTORED'));
  }
};
const openExecutionInCanvas = execution => {
  const rule = rules.value.find(ruleItem => ruleItem.id === execution.ruleId);
  if (!rule) return;

  openRule(rule);
  selectedExecutionId.value = String(execution.id);
};

const loadRuleVersions = async ruleId => {
  isLoadingVersions.value = true;
  try {
    const response = await KanbanBoardsAPI.getAutomationRuleVersions(
      boardId.value,
      ruleId
    );
    ruleVersions.value = response.data.map(normalize);
  } catch (versionsError) {
    error.value = t('KANBAN.AUTOMATIONS_WORKSPACE.VERSIONS.LOAD_ERROR');
  } finally {
    isLoadingVersions.value = false;
  }
};

const toggleRuleVersions = async rule => {
  if (versionRuleId.value === rule.id) {
    versionRuleId.value = null;
    ruleVersions.value = [];
    return;
  }

  versionRuleId.value = rule.id;
  await loadRuleVersions(rule.id);
};

const restoreRuleVersion = async version => {
  if (!versionRuleId.value || restoringVersionId.value) return;

  restoringVersionId.value = version.id;
  try {
    const response = await KanbanBoardsAPI.restoreAutomationRuleVersion(
      boardId.value,
      versionRuleId.value,
      version.id
    );
    const restoredRule = normalize(response.data);
    rules.value = rules.value.map(rule =>
      rule.id === restoredRule.id ? restoredRule : rule
    );
    await loadRuleVersions(restoredRule.id);
    useAlert(t('KANBAN.AUTOMATIONS_WORKSPACE.VERSIONS.RESTORE_SUCCESS'));
  } catch (restoreError) {
    error.value = t('KANBAN.AUTOMATIONS_WORKSPACE.VERSIONS.RESTORE_ERROR');
  } finally {
    restoringVersionId.value = null;
  }
};
const closeEditor = () => {
  showEditor.value = false;
  showBirthdayEditor.value = false;
  resetForm();
};

watch(
  form,
  () => {
    if (
      !showEditor.value ||
      !selectedRuleId.value ||
      typeof window === 'undefined'
    ) {
      return;
    }

    try {
      window.localStorage.setItem(
        ruleDraftStorageKey(selectedRuleId.value),
        JSON.stringify(copyDraftForm(form))
      );
    } catch {
      // The editor remains usable when browser storage is unavailable.
    }
  },
  { deep: true }
);

const applyBirthdayAutomation = source => {
  const automation = normalize(source);
  birthdayAutomation.active = Boolean(automation.active);
  birthdayAutomation.daysBefore = Number(automation.daysBefore) || 0;
  birthdayAutomation.deliveryChannels = automation.deliveryChannels || [];
  birthdayAutomation.optInAttributeKey =
    automation.optInAttributeKey || 'birthday_messages_opt_in';
  birthdayAutomation.messageLocale = automation.messageLocale || 'pt_BR';
  birthdayAutomation.timezone = automation.timezone || '';
  birthdayAutomation.timezoneName = automation.timezoneName || '';
  birthdayAutomation.sendTime = automation.sendTime || '09:00';
  birthdayAutomation.messageTemplate = automation.messageTemplate || '';
  birthdayAutomation.messageAttachment = automation.messageAttachment || {};
};

const insertBirthdayMessageText = value => {
  const input = birthdayMessageInput.value;
  const content = birthdayAutomation.messageTemplate || '';
  const start = input?.selectionStart ?? content.length;
  const end = input?.selectionEnd ?? content.length;
  birthdayAutomation.messageTemplate = `${content.slice(0, start)}${value}${content.slice(end)}`;
  showBirthdayEmojiPicker.value = false;
  showBirthdayVariableMenu.value = false;
  birthdayVariableQuery.value = '';

  nextTick(() => {
    input?.focus();
    input?.setSelectionRange(start + value.length, start + value.length);
  });
};

const uploadBirthdayAttachment = event => {
  const file = event.target.files?.[0];
  if (!file) return;

  if (!file.type.startsWith('image/') || file.size > 10 * 1024 * 1024) {
    birthdayError.value = t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.IMAGE_ERROR');
    event.target.value = '';
    return;
  }

  isUploadingBirthdayAttachment.value = true;
  const upload = new DirectUpload(file, '/rails/active_storage/direct_uploads');
  upload.create((uploadError, blob) => {
    isUploadingBirthdayAttachment.value = false;
    event.target.value = '';
    if (uploadError) {
      birthdayError.value = t(
        'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.IMAGE_UPLOAD_ERROR'
      );
      return;
    }

    birthdayAutomation.messageAttachment = {
      signedId: blob.signed_id,
      filename: blob.filename,
      contentType: blob.content_type,
    };
  });
};

const removeBirthdayAttachment = () => {
  birthdayAutomation.messageAttachment = {};
};

async function loadBirthdayAutomation() {
  isLoadingBirthday.value = true;
  birthdayError.value = '';
  try {
    const response = await KanbanBoardsAPI.getBirthdayAutomation();
    applyBirthdayAutomation(response.data);
  } catch (loadError) {
    birthdayError.value = t('KANBAN.SETTINGS.AUTOMATIONS.BIRTHDAY.LOAD_ERROR');
  } finally {
    isLoadingBirthday.value = false;
  }
}

function openBirthdayAutomation() {
  showBirthdayEditor.value = true;
  loadBirthdayAutomation();
}

const saveBirthdayAutomation = async () => {
  if (isSavingBirthday.value) return;

  isSavingBirthday.value = true;
  birthdayError.value = '';
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
        message_attachment: {
          signed_id: birthdayAutomation.messageAttachment.signedId,
          filename: birthdayAutomation.messageAttachment.filename,
          content_type: birthdayAutomation.messageAttachment.contentType,
        },
      },
    });
    applyBirthdayAutomation(response.data);
    useAlert(t('KANBAN.SETTINGS.AUTOMATIONS.BIRTHDAY.SAVE_SUCCESS'));
  } catch (saveError) {
    birthdayError.value =
      saveError?.response?.data?.message ||
      t('KANBAN.SETTINGS.AUTOMATIONS.BIRTHDAY.SAVE_ERROR');
  } finally {
    isSavingBirthday.value = false;
  }
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

const loadConnectionAudits = async () => {
  const response = await KanbanBoardsAPI.getAutomationConnectionAudits(
    boardId.value
  );
  connectionAudits.value = normalize(response.data);
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
    await loadConnectionAudits();
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
    await loadConnectionAudits();
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
    await loadConnectionAudits();
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

const prepareRuleTest = async rule => {
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

const toggleRuleTest = async rule => {
  if (testRuleId.value === rule.id) {
    testRuleId.value = null;
    return;
  }

  await prepareRuleTest(rule);
};

const toggleEditorTest = async () => {
  if (!selectedRule.value) return;

  if (showEditorTest.value) {
    showEditorTest.value = false;
    return;
  }

  showEditorTest.value = true;
  await prepareRuleTest(selectedRule.value);
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
    case 'wait_for_inactivity':
      return t('KANBAN.AUTOMATIONS_WORKSPACE.TEST.STEPS.WAIT_FOR_INACTIVITY');
    case 'random_delay':
      return t('KANBAN.AUTOMATIONS_WORKSPACE.TEST.STEPS.RANDOM_DELAY');
    case 'wait_for_business_hours':
      return t(
        'KANBAN.AUTOMATIONS_WORKSPACE.TEST.STEPS.WAIT_FOR_BUSINESS_HOURS'
      );
    case 'stage_guard':
      return t('KANBAN.AUTOMATIONS_WORKSPACE.TEST.STEPS.STAGE_GUARD');
    case 'condition':
      return t('KANBAN.AUTOMATIONS_WORKSPACE.TEST.STEPS.CONDITION');
    case 'filter':
      return t('KANBAN.AUTOMATIONS_WORKSPACE.TEST.STEPS.FILTER');
    case 'message_eligibility':
      return t('KANBAN.AUTOMATIONS_WORKSPACE.TEST.STEPS.MESSAGE_ELIGIBILITY');
    case 'round_robin':
      return t('KANBAN.AUTOMATIONS_WORKSPACE.TEST.STEPS.ROUND_ROBIN');
    case 'human_handoff':
      return t('KANBAN.AUTOMATIONS_WORKSPACE.TEST.STEPS.HUMAN_HANDOFF');
    case 'update_contact':
      return t('KANBAN.AUTOMATIONS_WORKSPACE.TEST.STEPS.UPDATE_CONTACT');
    case 'complete_next_action':
      return t('KANBAN.AUTOMATIONS_WORKSPACE.TEST.STEPS.COMPLETE_NEXT_ACTION');
    case 'mark_won':
      return t('KANBAN.AUTOMATIONS_WORKSPACE.TEST.STEPS.MARK_WON');
    case 'mark_lost':
      return t('KANBAN.AUTOMATIONS_WORKSPACE.TEST.STEPS.MARK_LOST');
    case 'audit_log':
      return t('KANBAN.AUTOMATIONS_WORKSPACE.TEST.STEPS.AUDIT_LOG');
    case 'action':
      return t('KANBAN.AUTOMATIONS_WORKSPACE.TEST.STEPS.ACTION');
    case 'send_message':
      return t('KANBAN.AUTOMATIONS_WORKSPACE.TEST.STEPS.SEND_MESSAGE');
    case 'webhook':
      return t('KANBAN.AUTOMATIONS_WORKSPACE.TEST.STEPS.WEBHOOK');
    case 'move_stage':
      return t('KANBAN.SETTINGS.AUTOMATIONS.ACTIONS.MOVE_STAGE');
    case 'assign_owner':
      return t('KANBAN.SETTINGS.AUTOMATIONS.ACTIONS.ASSIGN_OWNER');
    case 'assign_round_robin':
      return t('KANBAN.SETTINGS.AUTOMATIONS.ACTIONS.ASSIGN_ROUND_ROBIN');
    case 'set_next_action':
      return t('KANBAN.SETTINGS.AUTOMATIONS.ACTIONS.SET_NEXT_ACTION');
    case 'set_field':
      return t('KANBAN.SETTINGS.AUTOMATIONS.ACTIONS.SET_FIELD');
    case 'increment_field':
      return t('KANBAN.SETTINGS.AUTOMATIONS.ACTIONS.INCREMENT_FIELD');
    case 'clear_field':
      return t('KANBAN.SETTINGS.AUTOMATIONS.ACTIONS.CLEAR_FIELD');
    case 'archive_card':
      return t('KANBAN.SETTINGS.AUTOMATIONS.ACTIONS.ARCHIVE_CARD');
    case 'enroll_cadence':
      return t('KANBAN.SETTINGS.AUTOMATIONS.ACTIONS.ENROLL_CADENCE');
    case 'add_label':
      return t('KANBAN.SETTINGS.AUTOMATIONS.ACTIONS.ADD_LABEL');
    case 'remove_label':
      return t('KANBAN.SETTINGS.AUTOMATIONS.ACTIONS.REMOVE_LABEL');
    case 'add_note':
      return t('KANBAN.SETTINGS.AUTOMATIONS.ACTIONS.ADD_NOTE');
    default:
      return t('KANBAN.AUTOMATIONS_WORKSPACE.TEST.STEPS.UNKNOWN');
  }
};

const previewStepContent = step => {
  if (step.renderedContent || step.connectionName) {
    return step.renderedContent || step.connectionName;
  }

  if (
    step.type === 'wait_until_field' &&
    step.reason === 'scheduled_time_in_past'
  ) {
    return t('KANBAN.AUTOMATIONS_WORKSPACE.TEST.DATE_WAIT_PAST');
  }

  if (step.type === 'wait_until_field' && step.scheduledAt) {
    const scheduledAt = new Date(step.scheduledAt);
    if (!Number.isNaN(scheduledAt.getTime())) {
      return t('KANBAN.AUTOMATIONS_WORKSPACE.TEST.DATE_WAIT_SCHEDULED', {
        date: scheduledAt.toLocaleString(),
      });
    }
  }

  return '';
};

const executionStatusLabel = status =>
  executionStatusOptions.value.find(item => item.value === status)?.label ||
  status;

const executionStepStatusLabel = status => {
  switch (status) {
    case 'queued':
      return t('KANBAN.AUTOMATIONS_WORKSPACE.EXECUTIONS.STEP_STATUS.QUEUED');
    case 'running':
      return t('KANBAN.AUTOMATIONS_WORKSPACE.EXECUTIONS.STEP_STATUS.RUNNING');
    case 'waiting':
      return t('KANBAN.AUTOMATIONS_WORKSPACE.EXECUTIONS.STEP_STATUS.WAITING');
    case 'eligible':
      return t('KANBAN.AUTOMATIONS_WORKSPACE.EXECUTIONS.STEP_STATUS.ELIGIBLE');
    case 'succeeded':
      return t('KANBAN.AUTOMATIONS_WORKSPACE.EXECUTIONS.STEP_STATUS.SUCCEEDED');
    case 'failed':
      return t('KANBAN.AUTOMATIONS_WORKSPACE.EXECUTIONS.STEP_STATUS.FAILED');
    default:
      return t('KANBAN.AUTOMATIONS_WORKSPACE.EXECUTIONS.STEP_STATUS.SKIPPED');
  }
};

const executionStepReasonLabel = reason => {
  switch (reason) {
    case 'no_available_owner':
      return t(
        'KANBAN.AUTOMATIONS_WORKSPACE.EXECUTIONS.STEP_REASON.NO_AVAILABLE_OWNER'
      );
    case 'webhook_delivery_failed':
      return t(
        'KANBAN.AUTOMATIONS_WORKSPACE.EXECUTIONS.STEP_REASON.WEBHOOK_DELIVERY_FAILED'
      );
    case 'no_compatible_conversation':
      return t(
        'KANBAN.AUTOMATIONS_WORKSPACE.EXECUTIONS.STEP_REASON.NO_COMPATIBLE_CONVERSATION'
      );
    case 'quiet_hours':
      return t(
        'KANBAN.AUTOMATIONS_WORKSPACE.EXECUTIONS.STEP_REASON.QUIET_HOURS'
      );
    case 'cancelled_by_administrator':
      return t(
        'KANBAN.AUTOMATIONS_WORKSPACE.EXECUTIONS.STEP_REASON.CANCELLED_BY_ADMINISTRATOR'
      );
    case 'cancelled_after_rule_update':
      return t(
        'KANBAN.AUTOMATIONS_WORKSPACE.EXECUTIONS.STEP_REASON.CANCELLED_AFTER_RULE_UPDATE'
      );
    default:
      return '';
  }
};

const executionStepTimestamp = timestamp => {
  const parsed = new Date(timestamp).getTime();
  return Number.isFinite(parsed) ? new Date(parsed).toLocaleString() : '';
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

const positiveNumber = value =>
  Number.isFinite(Number(value)) && Number(value) > 0;
const validMessagePolicy = data => {
  const frequencyLimit = data.frequency_limit_hours;
  const validFrequency =
    frequencyLimit === '' ||
    frequencyLimit === undefined ||
    (positiveNumber(frequencyLimit) && Number(frequencyLimit) <= 24 * 30);
  const quietHours = data.quiet_hours || {};
  const hasQuietHours = quietHours.start || quietHours.end;
  const validQuietHours =
    !hasQuietHours ||
    (quietHours.start &&
      quietHours.end &&
      quietHours.start !== quietHours.end &&
      quietHours.timezone);

  return validFrequency && validQuietHours;
};
const validConditionPaths = nodeId => {
  const handles = (form.flowDefinition?.edges || [])
    .filter(edge => edge.source === nodeId)
    .map(edge => edge.sourceHandle);

  return (
    handles.filter(handle => handle === 'yes').length === 1 &&
    handles.filter(handle => handle === 'no').length === 1
  );
};

const visualFlowValidationError = () => {
  const nodes = form.flowDefinition?.nodes || [];
  if (!nodes.length) return null;

  const invalidNode = nodes.find(node => {
    const data = node.data || {};

    if (node.type === 'send_message') {
      return (
        !['whatsapp', 'email'].includes(data.channel) ||
        !data.content?.trim() ||
        !data.opt_in_attribute_key?.trim() ||
        !validMessagePolicy(data)
      );
    }
    if (node.type === 'delay') return !positiveNumber(data.delay_hours);
    if (node.type === 'random_delay') {
      return (
        !positiveNumber(data.min_minutes) ||
        !positiveNumber(data.max_minutes) ||
        Number(data.max_minutes) < Number(data.min_minutes)
      );
    }
    if (node.type === 'wait_until_field') return !data.field_key;
    if (node.type === 'wait_for_response') {
      return !positiveNumber(data.timeout_hours);
    }
    if (node.type === 'wait_for_inactivity') {
      return !positiveNumber(data.timeout_hours);
    }
    if (node.type === 'wait_for_business_hours') {
      return (
        !Array.isArray(data.weekdays) ||
        !data.weekdays.length ||
        !data.start_time ||
        !data.end_time ||
        data.start_time >= data.end_time ||
        !data.timezone
      );
    }
    if (node.type === 'condition') {
      return !data.field_key || !validConditionPaths(node.id);
    }
    if (node.type === 'stage_guard') return !form.stageId;
    if (node.type === 'webhook') return !data.connection_id;
    if (node.type !== 'action') return false;

    const params = data.action_params || {};
    if (data.action_name === 'move_stage') return !params.stage_id;
    if (
      ['set_field', 'increment_field', 'clear_field'].includes(data.action_name)
    ) {
      return !params.field_key;
    }
    return false;
  });

  if (!invalidNode) return null;

  const validationKey = {
    send_message: validMessagePolicy(invalidNode.data || {})
      ? 'MESSAGE'
      : 'MESSAGE_POLICY',
    delay: 'DELAY',
    random_delay: 'RANDOM_DELAY',
    wait_until_field: 'DATE_WAIT',
    wait_for_response: 'RESPONSE_WAIT',
    wait_for_inactivity: 'RESPONSE_WAIT',
    wait_for_business_hours: 'BUSINESS_HOURS',
    stage_guard: 'STAGE_GUARD',
    condition: validConditionPaths(invalidNode.id)
      ? 'CONDITION'
      : 'CONDITION_PATH',
    webhook: 'WEBHOOK',
    action: 'ACTION',
  }[invalidNode.type];

  return {
    nodeId: invalidNode.id,
    message: {
      MESSAGE: t('KANBAN.AUTOMATIONS_WORKSPACE.VALIDATION.MESSAGE'),
      MESSAGE_POLICY: t(
        'KANBAN.AUTOMATIONS_WORKSPACE.VALIDATION.MESSAGE_POLICY'
      ),
      DELAY: t('KANBAN.AUTOMATIONS_WORKSPACE.VALIDATION.DELAY'),
      RANDOM_DELAY: t('KANBAN.AUTOMATIONS_WORKSPACE.VALIDATION.RANDOM_DELAY'),
      DATE_WAIT: t('KANBAN.AUTOMATIONS_WORKSPACE.VALIDATION.DATE_WAIT'),
      RESPONSE_WAIT: t('KANBAN.AUTOMATIONS_WORKSPACE.VALIDATION.RESPONSE_WAIT'),
      STAGE_GUARD: t('KANBAN.AUTOMATIONS_WORKSPACE.VALIDATION.STAGE_GUARD'),
      BUSINESS_HOURS: t(
        'KANBAN.AUTOMATIONS_WORKSPACE.VALIDATION.BUSINESS_HOURS'
      ),
      CONDITION: t('KANBAN.AUTOMATIONS_WORKSPACE.VALIDATION.CONDITION'),
      CONDITION_PATH: t(
        'KANBAN.AUTOMATIONS_WORKSPACE.VALIDATION.CONDITION_PATH'
      ),
      WEBHOOK: t('KANBAN.AUTOMATIONS_WORKSPACE.VALIDATION.WEBHOOK'),
      ACTION: t('KANBAN.AUTOMATIONS_WORKSPACE.VALIDATION.ACTION'),
    }[validationKey],
  };
};

const payload = () => ({
  kanban_automation_rule: {
    name: form.name.trim(),
    description: form.description.trim() || null,
    event_name:
      triggerContext.value === 'stage'
        ? form.triggerEventNames[0] || form.eventName
        : form.eventName,
    active: form.active,
    ...(selectedRuleId.value ? { lock_version: form.lockVersion } : {}),
    reentry_enabled: form.reentryEnabled,
    cancel_waiting_executions: form.cancelWaitingExecutions,
    conditions: {
      stage_ids:
        triggerContext.value === 'stage' && form.stageId
          ? [Number(form.stageId)]
          : [],
      trigger_event_names:
        triggerContext.value === 'stage'
          ? form.triggerEventNames
          : [form.eventName],
      owner_ids:
        triggerContext.value === 'owner' && form.ownerId
          ? [Number(form.ownerId)]
          : [],
      connection_ids:
        triggerContext.value === 'webhook' && form.connectionId
          ? [Number(form.connectionId)]
          : [],
      changed_field_keys:
        triggerContext.value === 'changed_field' && form.changedFieldKey
          ? [form.changedFieldKey]
          : [],
      customer_message_contains:
        triggerContext.value === 'customer_message' &&
        form.customerMessageMode === 'contains'
          ? form.customerMessageContains.trim()
          : '',
      fields: [
        ...(form.fieldKey
          ? [
              {
                field_key: form.fieldKey,
                operator: form.fieldOperator,
                value: form.fieldValue,
              },
            ]
          : []),
        ...(triggerContext.value === 'changed_field' &&
        form.changedFieldKey &&
        form.changedFieldValue !== ''
          ? [
              {
                field_key: form.changedFieldKey,
                operator: 'equals',
                value: form.changedFieldValue,
              },
            ]
          : []),
        ...(triggerContext.value === 'next_action' && form.triggerNextActionType
          ? [
              {
                field_key: 'system_next_action_type',
                operator: 'equals',
                value: form.triggerNextActionType,
              },
            ]
          : []),
        ...(triggerContext.value === 'amount' &&
        form.triggerAmountMode === 'new_value' &&
        form.triggerAmountValue !== ''
          ? [
              {
                field_key: 'system_amount',
                operator: form.triggerAmountOperator,
                value: form.triggerAmountValue,
              },
            ]
          : []),
        ...(triggerContext.value === 'lost_reason' && form.triggerLostReason
          ? [
              {
                field_key: 'system_lost_reason',
                operator: 'equals',
                value: form.triggerLostReason,
              },
            ]
          : []),
      ],
    },
    actions: form.flowDefinition?.nodes?.length
      ? []
      : form.actions
          .filter(action => action.actionName)
          .map(action => ({
            action_name: action.actionName,
            action_params: actionParams(action),
          })),
    flow_definition: form.flowDefinition,
  },
});

const invalidNodeIdFromApiError = message => {
  const nodeId = message?.match(/\bnode\s+([^\s]+)/i)?.[1];
  return form.flowDefinition?.nodes?.some(node => node.id === nodeId)
    ? nodeId
    : null;
};

const validateVisualFlow = () => {
  const validationError = visualFlowValidationError();
  if (validationError) {
    invalidNodeIds.value = [validationError.nodeId];
    error.value = validationError.message;
    useAlert(validationError.message);
    return;
  }

  invalidNodeIds.value = [];
  error.value = '';
  useAlert(t('KANBAN.AUTOMATIONS_WORKSPACE.VALIDATION.SUCCESS'));
};

const save = async () => {
  if (!form.name.trim() || isSaving.value) return;

  const validationError = visualFlowValidationError();
  if (validationError) {
    invalidNodeIds.value = [validationError.nodeId];
    error.value = validationError.message;
    useAlert(validationError.message);
    return;
  }

  isSaving.value = true;
  invalidNodeIds.value = [];
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
    clearRuleDraft(saved.id);
    closeEditor();
    activeTab.value = 'flows';
    useAlert(t('KANBAN.SETTINGS.AUTOMATIONS.RULES.SAVE_SUCCESS'));
  } catch (saveError) {
    const message =
      saveError?.response?.status === 409
        ? t('KANBAN.SETTINGS.AUTOMATIONS.RULES.SAVE_CONFLICT')
        : saveError?.response?.data?.message ||
          t('KANBAN.SETTINGS.AUTOMATIONS.RULES.SAVE_ERROR');
    const invalidNodeId = invalidNodeIdFromApiError(message);
    if (invalidNodeId) invalidNodeIds.value = [invalidNodeId];
    error.value = message;
    useAlert(error.value);
  } finally {
    isSaving.value = false;
  }
};

const clearFlowValidation = () => {
  invalidNodeIds.value = [];
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
      connectionAuditsResponse,
      executionsResponse,
      metricsResponse,
    ] = await Promise.all([
      KanbanBoardsAPI.getSettings(boardId.value),
      KanbanBoardsAPI.getAutomationRules(boardId.value),
      KanbanBoardsAPI.getAppointmentReminderRules(boardId.value),
      KanbanBoardsAPI.getAutomationConnections(boardId.value),
      KanbanBoardsAPI.getAutomationConnectionAudits(boardId.value),
      KanbanBoardsAPI.getAllAutomationExecutions(boardId.value),
      KanbanBoardsAPI.getAutomationMetrics(boardId.value),
    ]);
    settings.value = normalize(settingsResponse.data);
    rules.value = normalize(rulesResponse.data);
    appointmentReminders.value = normalize(remindersResponse.data);
    connections.value = normalize(connectionsResponse.data);
    connectionAudits.value = normalize(connectionAuditsResponse.data);
    executions.value = normalize(executionsResponse.data);
    historicalNodeMetrics.value = normalize(metricsResponse.data);
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
      v-if="!showEditor"
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
        type="button"
        data-testid="kanban-automations-new-flow"
        icon="i-lucide-plus"
        :label="t('KANBAN.AUTOMATIONS_WORKSPACE.NEW_FLOW')"
        color="blue"
        size="sm"
        @click="openNewFlow"
      />
    </header>

    <div
      v-if="showBirthdayEditor"
      data-testid="kanban-birthday-editor"
      class="mx-auto grid w-full max-w-3xl gap-4 px-4 py-6 lg:px-6"
    >
      <div>
        <h2 class="m-0 text-base font-semibold text-n-slate-12">
          {{ t('KANBAN.AUTOMATIONS_WORKSPACE.TEMPLATES.BIRTHDAY.TITLE') }}
        </h2>
        <p class="m-0 mt-1 text-sm text-n-slate-11">
          {{ t('KANBAN.AUTOMATIONS_WORKSPACE.TEMPLATES.BIRTHDAY.DESCRIPTION') }}
        </p>
      </div>
      <p v-if="isLoadingBirthday" class="m-0 text-sm text-n-slate-11">
        {{ t('KANBAN.SETTINGS.AUTOMATIONS.BIRTHDAY.LOADING') }}
      </p>
      <template v-else>
        <label
          class="flex items-center gap-2 text-sm font-medium text-n-slate-12"
        >
          <input
            v-model="birthdayAutomation.active"
            type="checkbox"
            class="size-4 rounded border-n-weak text-n-brand focus:ring-n-brand"
          />
          {{ t('KANBAN.SETTINGS.AUTOMATIONS.BIRTHDAY.ACTIVE') }}
        </label>
        <div class="grid gap-3 sm:grid-cols-2">
          <label class="grid gap-1 text-xs font-medium text-n-slate-11">
            {{ t('KANBAN.SETTINGS.AUTOMATIONS.BIRTHDAY.DAYS_BEFORE') }}
            <input
              v-model.number="birthdayAutomation.daysBefore"
              type="number"
              min="0"
              max="30"
              class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
            />
          </label>
          <label class="grid gap-1 text-xs font-medium text-n-slate-11">
            {{ t('KANBAN.SETTINGS.AUTOMATIONS.BIRTHDAY.MESSAGE_LOCALE') }}
            <select
              v-model="birthdayAutomation.messageLocale"
              class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
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
              type="time"
              class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
            />
          </label>
          <label class="grid gap-1 text-xs font-medium text-n-slate-11">
            {{ t('KANBAN.SETTINGS.AUTOMATIONS.BIRTHDAY.TIMEZONE') }}
            <input
              v-model="birthdayAutomation.timezone"
              type="text"
              :placeholder="birthdayAutomation.timezoneName"
              class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
            />
          </label>
        </div>
        <fieldset class="flex flex-wrap gap-4 border-0 p-0">
          <legend class="mb-1 text-xs font-medium text-n-slate-11">
            {{ t('KANBAN.SETTINGS.AUTOMATIONS.BIRTHDAY.CHANNELS') }}
          </legend>
          <label class="flex items-center gap-2 text-sm text-n-slate-12">
            <input
              v-model="birthdayAutomation.deliveryChannels"
              value="whatsapp"
              type="checkbox"
              class="size-4 rounded border-n-weak text-n-brand focus:ring-n-brand"
            />
            <span>{{
              t('KANBAN.SETTINGS.AUTOMATIONS.BIRTHDAY.WHATSAPP')
            }}</span>
          </label>
          <label class="flex items-center gap-2 text-sm text-n-slate-12">
            <input
              v-model="birthdayAutomation.deliveryChannels"
              value="email"
              type="checkbox"
              class="size-4 rounded border-n-weak text-n-brand focus:ring-n-brand"
            />
            <span>{{ t('KANBAN.SETTINGS.AUTOMATIONS.BIRTHDAY.EMAIL') }}</span>
          </label>
        </fieldset>
        <label class="grid gap-1 text-xs font-medium text-n-slate-11">
          {{ t('KANBAN.SETTINGS.AUTOMATIONS.BIRTHDAY.OPT_IN_KEY') }}
          <input
            v-model="birthdayAutomation.optInAttributeKey"
            type="text"
            class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
          />
        </label>
        <label class="grid gap-1 text-xs font-medium text-n-slate-11">
          {{ t('KANBAN.SETTINGS.AUTOMATIONS.BIRTHDAY.MESSAGE') }}
          <div class="rounded-md border border-n-weak bg-n-surface-1">
            <textarea
              ref="birthdayMessageInput"
              v-model="birthdayAutomation.messageTemplate"
              rows="4"
              class="block w-full resize-y border-0 bg-transparent px-3 py-2 text-sm text-n-slate-12 outline-none focus:ring-0"
            />
            <div
              class="flex items-center gap-1 border-t border-n-weak px-2 py-1.5"
            >
              <div
                v-on-click-outside="() => (showBirthdayEmojiPicker = false)"
                class="relative"
              >
                <button
                  type="button"
                  class="flex size-8 items-center justify-center rounded-md text-n-slate-10 hover:bg-n-surface-2 hover:text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand"
                  :aria-label="
                    t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.INSERT_EMOJI')
                  "
                  @click="showBirthdayEmojiPicker = !showBirthdayEmojiPicker"
                >
                  <i class="i-lucide-smile size-4" />
                </button>
                <EmojiIconPicker
                  v-if="showBirthdayEmojiPicker"
                  mode="emoji"
                  class="!bottom-full !left-0 !top-auto mb-2"
                  @select="insertBirthdayMessageText($event.value)"
                />
              </div>
              <div
                v-on-click-outside="() => (showBirthdayVariableMenu = false)"
                class="relative"
              >
                <button
                  type="button"
                  class="flex size-8 items-center justify-center rounded-md text-n-slate-10 hover:bg-n-surface-2 hover:text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand"
                  :aria-label="
                    t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.INSERT_VARIABLE')
                  "
                  @click="showBirthdayVariableMenu = !showBirthdayVariableMenu"
                >
                  <i class="i-lucide-braces size-4" />
                </button>
                <div
                  v-if="showBirthdayVariableMenu"
                  class="absolute bottom-full left-0 z-20 grid max-h-64 w-64 gap-1 overflow-y-auto rounded-md border border-n-weak bg-n-surface-1 p-1 shadow-xl"
                >
                  <input
                    v-model="birthdayVariableQuery"
                    type="search"
                    class="h-8 rounded border border-n-weak bg-n-surface-2 px-2 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                    :placeholder="
                      t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.SEARCH_VARIABLE')
                    "
                  />
                  <button
                    v-for="variable in filteredBirthdayVariables"
                    :key="variable.token"
                    type="button"
                    class="grid gap-0.5 rounded px-2 py-1.5 text-left hover:bg-n-surface-2 focus:outline-none focus:ring-2 focus:ring-n-brand"
                    @click="insertBirthdayMessageText(variable.token)"
                  >
                    <span class="text-sm font-medium text-n-slate-12">{{
                      variable.label
                    }}</span>
                    <span class="font-mono text-xs text-n-slate-10">{{
                      variable.token
                    }}</span>
                  </button>
                </div>
              </div>
              <label
                class="flex size-8 cursor-pointer items-center justify-center rounded-md text-n-slate-10 hover:bg-n-surface-2 hover:text-n-slate-12 focus-within:ring-2 focus-within:ring-n-brand"
                :aria-label="
                  t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.UPLOAD_IMAGE')
                "
              >
                <i class="i-lucide-image-plus size-4" />
                <input
                  class="sr-only"
                  type="file"
                  accept="image/png,image/jpeg,image/webp,image/gif"
                  :disabled="isUploadingBirthdayAttachment"
                  @change="uploadBirthdayAttachment"
                />
              </label>
            </div>
          </div>
        </label>
        <div
          class="grid gap-2 rounded-md border border-n-weak bg-n-surface-2 p-3"
        >
          <p class="m-0 text-xs font-medium text-n-slate-11">
            {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.PREVIEW') }}
          </p>
          <img
            v-if="birthdayAttachmentUrl"
            :src="birthdayAttachmentUrl"
            :alt="t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.ATTACHMENT_PREVIEW')"
            class="max-h-56 w-auto rounded-md object-cover"
          />
          <div
            class="max-w-[85%] rounded-lg rounded-tl-sm bg-n-brand px-3 py-2 text-sm text-white"
          >
            {{
              birthdayPreview ||
              t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.PREVIEW_EMPTY')
            }}
          </div>
          <div v-if="birthdayAttachmentUrl" class="flex justify-end">
            <button
              type="button"
              class="text-xs font-medium text-n-ruby-11 hover:underline focus:outline-none focus:ring-2 focus:ring-n-brand"
              @click="removeBirthdayAttachment"
            >
              {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.REMOVE_IMAGE') }}
            </button>
          </div>
        </div>
        <p v-if="birthdayError" class="m-0 text-sm text-n-ruby-11" role="alert">
          {{ birthdayError }}
        </p>
        <div class="flex justify-end">
          <Button
            type="button"
            icon="i-lucide-save"
            :label="t('KANBAN.SETTINGS.AUTOMATIONS.BIRTHDAY.SAVE')"
            color="blue"
            size="sm"
            :is-loading="isSavingBirthday"
            @click="saveBirthdayAutomation"
          />
        </div>
      </template>
    </div>
    <div
      v-else-if="showEditor"
      data-testid="kanban-automation-editor"
      class="flex min-h-0 flex-1 flex-col"
    >
      <section
        data-testid="kanban-automation-editor-header"
        class="relative z-10 flex min-h-[54px] flex-wrap items-center gap-2 border-b border-n-weak bg-n-surface-1 px-4 py-2 shadow-sm lg:flex-nowrap lg:px-6"
      >
        <div
          data-testid="kanban-automation-editor-identity"
          class="hidden shrink-0 items-center gap-2 lg:flex"
        >
          <span
            class="flex size-7 shrink-0 items-center justify-center rounded-md bg-n-brand/10 text-n-brand"
          >
            <i class="i-lucide-workflow size-3.5" aria-hidden="true" />
          </span>
        </div>
        <label class="min-w-[12rem] flex-1 text-xs font-medium text-n-slate-11">
          <span class="sr-only">
            {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.NAME') }}
          </span>
          <input
            v-model="form.name"
            data-testid="kanban-automations-flow-name"
            type="text"
            class="h-8 w-full rounded-md border border-transparent bg-transparent px-2 text-sm font-semibold text-n-slate-12 outline-none hover:border-n-weak hover:bg-n-surface-2 focus:border-n-brand focus:bg-n-surface-1 focus:ring-2 focus:ring-n-brand/20"
          />
        </label>
        <Popover align="start" :show-content-border="false">
          <button
            type="button"
            data-testid="kanban-automations-trigger-popover"
            class="flex h-8 min-w-0 max-w-56 items-center gap-2 rounded-md border border-n-weak bg-n-surface-1 px-2.5 text-left text-xs text-n-slate-12 outline-none hover:bg-n-surface-2 focus:ring-2 focus:ring-n-brand"
          >
            <i
              class="i-lucide-zap size-4 shrink-0 text-n-brand"
              aria-hidden="true"
            />
            <span class="min-w-0 flex-1 truncate">{{ triggerSummary }}</span>
            <i
              class="i-lucide-chevron-down size-4 text-n-slate-10"
              aria-hidden="true"
            />
          </button>
          <template #content>
            <div
              class="grid w-[min(28rem,calc(100vw-2rem))] gap-3 bg-n-surface-1 p-4"
            >
              <p class="m-0 text-sm font-semibold text-n-slate-12">
                {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.EVENT') }}
              </p>
              <label
                class="grid w-full gap-1 text-xs font-medium text-n-slate-11"
              >
                {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.EVENT') }}
                <select
                  v-model="form.eventName"
                  data-testid="kanban-automations-trigger-event"
                  class="h-10 rounded-lg border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand focus:ring-2 focus:ring-n-brand/20"
                  @change="onTriggerEventChanged"
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
              <label
                v-if="triggerContext === 'stage'"
                class="grid w-full gap-2 text-xs font-medium text-n-slate-11"
              >
                {{
                  t('KANBAN.SETTINGS.AUTOMATIONS.RULES.STAGE_TRIGGER_EVENTS')
                }}
                <span class="flex flex-wrap gap-x-3 gap-y-1.5">
                  <label
                    class="flex items-center gap-1.5 text-xs font-normal text-n-slate-12"
                  >
                    <input
                      v-model="form.triggerEventNames"
                      data-testid="kanban-automations-trigger-created"
                      type="checkbox"
                      value="kanban.card.created"
                      class="size-4 rounded border-n-weak text-n-brand focus:ring-n-brand"
                      @change="ensureStageTriggerEvent"
                    />
                    {{
                      t('KANBAN.SETTINGS.AUTOMATIONS.RULES.CREATED_IN_STAGE')
                    }}
                  </label>
                  <label
                    class="flex items-center gap-1.5 text-xs font-normal text-n-slate-12"
                  >
                    <input
                      v-model="form.triggerEventNames"
                      data-testid="kanban-automations-trigger-stage-changed"
                      type="checkbox"
                      value="kanban.card.stage_changed"
                      class="size-4 rounded border-n-weak text-n-brand focus:ring-n-brand"
                      @change="ensureStageTriggerEvent"
                    />
                    {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.MOVED_TO_STAGE') }}
                  </label>
                </span>
                <select
                  v-model="form.stageId"
                  data-testid="kanban-automations-trigger-stage"
                  class="h-10 rounded-lg border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand focus:ring-2 focus:ring-n-brand/20"
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
              </label>
              <label
                v-else-if="triggerContext === 'customer_message'"
                class="grid w-full gap-1 text-xs font-medium text-n-slate-11"
              >
                {{
                  t('KANBAN.SETTINGS.AUTOMATIONS.RULES.CUSTOMER_MESSAGE_PHRASE')
                }}
                <select
                  v-model="form.customerMessageMode"
                  data-testid="kanban-automations-customer-message-mode"
                  class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                >
                  <option value="any">
                    {{
                      t(
                        'KANBAN.SETTINGS.AUTOMATIONS.RULES.CUSTOMER_MESSAGE_ANY'
                      )
                    }}
                  </option>
                  <option value="contains">
                    {{
                      t(
                        'KANBAN.SETTINGS.AUTOMATIONS.RULES.CUSTOMER_MESSAGE_CONTAINS'
                      )
                    }}
                  </option>
                </select>
                <input
                  v-if="form.customerMessageMode === 'contains'"
                  v-model="form.customerMessageContains"
                  data-testid="kanban-automations-customer-message-contains"
                  type="text"
                  :placeholder="
                    t('KANBAN.SETTINGS.AUTOMATIONS.RULES.CUSTOMER_MESSAGE_ANY')
                  "
                  class="h-10 rounded-lg border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand focus:ring-2 focus:ring-n-brand/20"
                />
              </label>
              <label
                v-else-if="triggerContext === 'owner'"
                class="grid w-full gap-1 text-xs font-medium text-n-slate-11"
              >
                {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.SELECT_OWNER') }}
                <select
                  v-model="form.ownerId"
                  data-testid="kanban-automations-trigger-owner"
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
              </label>
              <label
                v-else-if="triggerContext === 'changed_field'"
                class="grid w-full gap-1 text-xs font-medium text-n-slate-11"
              >
                {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.SELECT_FIELD') }}
                <select
                  v-model="form.changedFieldKey"
                  data-testid="kanban-automations-changed-field"
                  class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                >
                  <option value="">
                    {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.ANY_FIELD') }}
                  </option>
                  <option
                    v-for="field in conditionFields"
                    :key="field.key"
                    :value="field.key"
                  >
                    {{ field.label }}
                  </option>
                </select>
              </label>
              <label
                v-else-if="triggerContext === 'next_action'"
                class="grid w-full gap-1 text-xs font-medium text-n-slate-11"
              >
                {{ t('KANBAN.SETTINGS.SALES.SYSTEM_FIELDS.NEXT_ACTION_TYPE') }}
                <select
                  v-model="form.triggerNextActionType"
                  data-testid="kanban-automations-trigger-next-action"
                  class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                >
                  <option value="">
                    {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.ANY_FIELD') }}
                  </option>
                  <option
                    v-for="actionType in nextActionTypes"
                    :key="actionType"
                    :value="actionType"
                  >
                    {{ actionType }}
                  </option>
                </select>
              </label>
              <div
                v-else-if="triggerContext === 'amount'"
                class="grid w-full gap-2"
              >
                <select
                  v-model="form.triggerAmountMode"
                  data-testid="kanban-automations-trigger-amount-mode"
                  class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                >
                  <option value="any">
                    {{
                      t('KANBAN.SETTINGS.AUTOMATIONS.RULES.ANY_AMOUNT_CHANGE')
                    }}
                  </option>
                  <option value="new_value">
                    {{
                      t('KANBAN.SETTINGS.AUTOMATIONS.RULES.AMOUNT_NEW_VALUE')
                    }}
                  </option>
                </select>
                <div
                  v-if="form.triggerAmountMode === 'new_value'"
                  class="grid grid-cols-[9rem_minmax(0,1fr)] gap-2"
                >
                  <select
                    v-model="form.triggerAmountOperator"
                    class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                  >
                    <option value="equals">
                      {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.EQUALS') }}
                    </option>
                    <option value="greater_than">
                      {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.GREATER_THAN') }}
                    </option>
                    <option value="less_than">
                      {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.LESS_THAN') }}
                    </option>
                  </select>
                  <input
                    v-model="form.triggerAmountValue"
                    data-testid="kanban-automations-trigger-amount"
                    type="number"
                    min="0"
                    inputmode="decimal"
                    :placeholder="t('KANBAN.SETTINGS.AUTOMATIONS.RULES.VALUE')"
                    class="h-9 min-w-0 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                  />
                </div>
              </div>
              <label
                v-else-if="triggerContext === 'webhook'"
                class="grid w-full gap-1 text-xs font-medium text-n-slate-11"
              >
                {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.SELECT_CONNECTION') }}
                <select
                  v-model="form.connectionId"
                  data-testid="kanban-automations-trigger-connection"
                  class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                >
                  <option value="">
                    {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.ANY_CONNECTION') }}
                  </option>
                  <option
                    v-for="connection in connections"
                    :key="connection.id"
                    :value="connection.id"
                  >
                    {{ connection.name }}
                  </option>
                </select>
              </label>
              <label
                v-else-if="triggerContext === 'lost_reason'"
                class="grid w-full gap-1 text-xs font-medium text-n-slate-11 sm:w-64"
              >
                {{ t('KANBAN.SETTINGS.SALES.SYSTEM_FIELDS.LOST_REASON') }}
                <select
                  v-model="form.triggerLostReason"
                  data-testid="kanban-automations-trigger-lost-reason"
                  class="h-10 rounded-lg border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand focus:ring-2 focus:ring-n-brand/20"
                >
                  <option value="">
                    {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.ANY_FIELD') }}
                  </option>
                  <option
                    v-for="reason in lostReasonOptions"
                    :key="reason"
                    :value="reason"
                  >
                    {{ reason }}
                  </option>
                </select>
              </label>
            </div>
          </template>
        </Popover>
        <Popover align="end" :show-content-border="false">
          <button
            type="button"
            data-testid="kanban-automations-advanced-popover"
            class="flex size-8 shrink-0 items-center justify-center rounded-md border border-n-weak bg-n-surface-1 text-n-slate-11 outline-none hover:bg-n-surface-2 focus:ring-2 focus:ring-n-brand"
            :aria-label="t('KANBAN.SETTINGS.AUTOMATIONS.RULES.ADVANCED')"
            :title="t('KANBAN.SETTINGS.AUTOMATIONS.RULES.ADVANCED')"
          >
            <i class="i-lucide-sliders-horizontal size-4" aria-hidden="true" />
          </button>
          <template #content>
            <div
              class="grid w-[min(32rem,calc(100vw-2rem))] gap-3 bg-n-surface-1 p-4"
            >
              <label
                class="grid max-w-52 gap-1 self-center text-xs font-medium text-n-slate-11"
                :title="t('KANBAN.SETTINGS.AUTOMATIONS.RULES.REENTRY_HINT')"
              >
                <span class="flex items-center gap-2">
                  <input
                    v-model="form.reentryEnabled"
                    type="checkbox"
                    class="size-4 rounded border-n-weak text-n-brand focus:ring-n-brand"
                  />
                  {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.REENTRY') }}
                </span>
              </label>
              <label
                v-if="waitingExecutionsForSelectedRule.length"
                class="grid max-w-60 gap-1 self-center text-xs font-medium text-n-ruby-11"
              >
                <span class="flex items-center gap-2">
                  <input
                    v-model="form.cancelWaitingExecutions"
                    type="checkbox"
                    data-testid="kanban-automations-cancel-pending"
                    class="size-4 rounded border-n-weak text-n-ruby-11 focus:ring-n-ruby-11"
                  />
                  {{
                    t('KANBAN.SETTINGS.AUTOMATIONS.RULES.CANCEL_PENDING', {
                      count: waitingExecutionsForSelectedRule.length,
                    })
                  }}
                </span>
                <span class="font-normal text-n-slate-11">
                  {{
                    t('KANBAN.SETTINGS.AUTOMATIONS.RULES.CANCEL_PENDING_HINT')
                  }}
                </span>
              </label>
              <details class="w-full">
                <summary
                  class="cursor-pointer text-xs font-medium text-n-slate-11 focus:outline-none focus:ring-2 focus:ring-n-brand"
                >
                  {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.CONDITIONS') }}
                </summary>
                <div
                  class="mt-2 grid gap-2 rounded-md border border-n-weak bg-n-surface-1 p-3 lg:grid-cols-[minmax(0,1fr)_10rem_minmax(0,1fr)]"
                >
                  <select
                    v-model="form.fieldKey"
                    data-testid="kanban-automations-condition-field"
                    class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                  >
                    <option value="">
                      {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.SELECT_FIELD') }}
                    </option>
                    <option
                      v-for="field in conditionFields"
                      :key="field.key"
                      :value="field.key"
                    >
                      {{ field.label }}
                    </option>
                  </select>
                  <select
                    v-model="form.fieldOperator"
                    class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
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
                    v-model="form.fieldValue"
                    type="text"
                    :disabled="form.fieldOperator === 'exists'"
                    :placeholder="t('KANBAN.SETTINGS.AUTOMATIONS.RULES.VALUE')"
                    class="h-9 min-w-0 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand disabled:cursor-not-allowed disabled:opacity-60"
                  />
                </div>
              </details>
            </div>
          </template>
        </Popover>
        <div class="ml-auto flex shrink-0 items-center gap-2">
          <label
            class="flex h-8 items-center gap-1.5 rounded-md border border-n-weak bg-n-surface-1 px-2 text-xs font-medium text-n-slate-11 focus-within:ring-2 focus-within:ring-n-brand"
          >
            <input
              v-model="form.active"
              data-testid="kanban-automations-publish-flow"
              type="checkbox"
              class="size-3.5 rounded border-n-weak text-n-brand focus:ring-n-brand"
            />
            {{ t('KANBAN.AUTOMATIONS_WORKSPACE.ACTIVE') }}
          </label>
          <Button
            type="button"
            data-testid="kanban-automations-validate-flow"
            icon="i-lucide-check"
            :label="t('KANBAN.AUTOMATIONS_WORKSPACE.VALIDATION.OPEN')"
            color="slate"
            size="sm"
            @click="validateVisualFlow"
          />
          <Button
            v-if="selectedRule"
            type="button"
            data-testid="kanban-automations-test-flow"
            icon="i-lucide-flask-conical"
            :label="t('KANBAN.AUTOMATIONS_WORKSPACE.TEST.OPEN')"
            color="slate"
            size="sm"
            :aria-pressed="showEditorTest"
            @click="toggleEditorTest"
          />
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
            :label="saveFlowLabel"
            color="blue"
            size="sm"
            :is-loading="isSaving"
            @click="save"
          />
        </div>
      </section>
      <section
        v-if="showEditorTest && selectedRule"
        data-testid="kanban-automation-editor-test-panel"
        class="grid gap-3 border-b border-n-weak bg-n-surface-1 px-4 py-3 lg:px-6"
      >
        <div class="flex flex-wrap items-end gap-2">
          <label
            class="grid min-w-60 flex-1 gap-1 text-xs font-medium text-n-slate-11"
          >
            {{ t('KANBAN.AUTOMATIONS_WORKSPACE.TEST.CARD') }}
            <select
              v-model="selectedTestCardId"
              data-testid="kanban-automation-editor-test-card"
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
            data-testid="kanban-automation-editor-run-test"
            icon="i-lucide-play"
            color="blue"
            size="sm"
            :label="t('KANBAN.AUTOMATIONS_WORKSPACE.TEST.RUN')"
            :is-loading="isTestingRule"
            :disabled="!selectedTestCardId || isLoadingTestCards"
            @click="runRuleTest(selectedRule)"
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
        <p v-if="testError" class="m-0 text-xs text-n-ruby-11" role="alert">
          {{ testError }}
        </p>
        <div
          v-if="testResult"
          class="grid gap-2 rounded-md border border-n-weak bg-n-surface-2 p-3"
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
              <p
                v-if="previewStepContent(step)"
                class="m-0 mt-0.5 break-words text-n-slate-10"
              >
                {{ previewStepContent(step) }}
              </p>
            </li>
          </ol>
          <p v-else class="m-0 text-xs text-n-slate-11">
            {{ t('KANBAN.AUTOMATIONS_WORKSPACE.TEST.NO_STEPS') }}
          </p>
        </div>
      </section>
      <div
        v-if="selectedRuleExecutions.length"
        class="flex items-center justify-end border-b border-n-weak bg-n-surface-1 px-4 py-2 lg:px-6"
      >
        <label
          class="flex items-center gap-2 text-xs font-medium text-n-slate-11"
        >
          {{ t('KANBAN.AUTOMATIONS_WORKSPACE.EXECUTIONS.INSPECT') }}
          <select
            v-model="selectedExecutionId"
            data-testid="kanban-automations-execution-history-filter"
            class="h-8 max-w-56 rounded-md border border-n-weak bg-n-surface-1 px-2 text-xs text-n-slate-12 outline-none focus:border-n-brand"
          >
            <option value="">
              {{ t('KANBAN.AUTOMATIONS_WORKSPACE.EXECUTIONS.ALL') }}
            </option>
            <option
              v-for="execution in selectedRuleExecutions"
              :key="execution.id"
              :value="String(execution.id)"
            >
              {{
                t('KANBAN.AUTOMATIONS_WORKSPACE.EXECUTIONS.DETAILS', {
                  event: execution.eventName,
                  id: execution.cardId || '-',
                })
              }}
            </option>
          </select>
        </label>
      </div>
      <KanbanWorkflowBuilder
        v-model="form.flowDefinition"
        class="min-h-0 flex-1 rounded-none border-x-0 border-b-0"
        :stages="stages"
        :agents="agentOptions"
        :teams="teams"
        :custom-fields="customFields"
        :next-action-types="nextActionTypes"
        :lost-reason-options="lostReasonOptions"
        :condition-fields="conditionFields"
        :date-fields="dateFields"
        :connections="connections"
        :trigger-options="eventOptions"
        :trigger-value="form.eventName"
        :trigger-context="triggerContext"
        :trigger-config="form"
        :invalid-node-ids="invalidNodeIds"
        :execution-history="selectedRuleExecutionHistory"
        @update:trigger-value="setFlowTriggerEvent"
        @update:trigger-config="updateFlowTriggerConfig"
        @clear-validation="clearFlowValidation"
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
          data-testid="kanban-automation-templates"
          class="mb-5 grid max-w-6xl grid-flow-col auto-cols-[minmax(15rem,82%)] gap-2 overflow-x-auto pb-1 sm:grid-flow-row sm:auto-cols-auto sm:grid-cols-2 sm:overflow-visible xl:grid-cols-3"
          :aria-label="t('KANBAN.AUTOMATIONS_WORKSPACE.TEMPLATES.TITLE')"
        >
          <button
            v-for="template in automationTemplates"
            :key="template.id"
            type="button"
            class="group grid min-h-[5.5rem] grid-cols-[2rem_minmax(0,1fr)_1rem] items-start gap-2 rounded-md border border-n-weak bg-n-surface-1 p-3 text-left transition-colors hover:border-n-brand hover:bg-n-surface-2 focus:outline-none focus:ring-2 focus:ring-n-brand"
            :data-testid="`kanban-automations-template-${template.id === 'nps-google-review' ? 'nps-google' : template.id}`"
            @click="openTemplate(template)"
          >
            <i
              :class="template.icon"
              data-testid="kanban-automations-template-icon"
              class="mt-0.5 flex size-8 items-center justify-center rounded-md bg-n-brand/10 p-2 text-n-brand"
              aria-hidden="true"
            />
            <span class="grid min-w-0 gap-1">
              <span class="truncate text-sm font-medium text-n-slate-12">{{
                template.name
              }}</span>
              <span class="line-clamp-2 text-xs leading-5 text-n-slate-11">{{
                template.description
              }}</span>
            </span>
            <i
              class="i-lucide-arrow-up-right mt-1 size-4 text-n-slate-10 opacity-0 transition-opacity group-hover:opacity-100 group-focus-visible:opacity-100"
              aria-hidden="true"
            />
          </button>
          <button
            type="button"
            data-testid="kanban-automations-template-birthday"
            class="group grid min-h-[5.5rem] grid-cols-[2rem_minmax(0,1fr)_1rem] items-start gap-2 rounded-md border border-n-weak bg-n-surface-1 p-3 text-left transition-colors hover:border-n-brand hover:bg-n-surface-2 focus:outline-none focus:ring-2 focus:ring-n-brand"
            @click="openBirthdayAutomation"
          >
            <i
              class="i-lucide-cake flex size-8 items-center justify-center rounded-md bg-n-brand/10 p-2 text-n-brand"
              data-testid="kanban-automations-template-icon"
              aria-hidden="true"
            />
            <span class="grid min-w-0 gap-1">
              <span class="truncate text-sm font-medium text-n-slate-12">
                {{ t('KANBAN.AUTOMATIONS_WORKSPACE.TEMPLATES.BIRTHDAY.TITLE') }}
              </span>
              <span class="line-clamp-2 text-xs leading-5 text-n-slate-11">
                {{
                  t(
                    'KANBAN.AUTOMATIONS_WORKSPACE.TEMPLATES.BIRTHDAY.DESCRIPTION'
                  )
                }}
              </span>
            </span>
            <i
              class="i-lucide-arrow-up-right mt-1 size-4 text-n-slate-10 opacity-0 transition-opacity group-hover:opacity-100 group-focus-visible:opacity-100"
              aria-hidden="true"
            />
          </button>
        </section>
        <div v-if="rules.length" class="grid max-w-6xl gap-2">
          <article
            v-for="rule in rules"
            :key="rule.id"
            class="group overflow-hidden rounded-md border border-n-weak bg-n-surface-1 transition-colors hover:border-n-brand"
          >
            <div class="flex items-center gap-3 px-3 py-3 sm:px-4">
              <span
                class="flex size-8 shrink-0 items-center justify-center rounded-md bg-n-surface-2 text-n-slate-10"
                aria-hidden="true"
              >
                <i class="i-lucide-git-branch size-4" />
              </span>
              <button
                type="button"
                :data-testid="`kanban-automation-rule-open-${rule.id}`"
                class="min-w-0 flex-1 rounded-md text-left outline-none focus:ring-2 focus:ring-inset focus:ring-n-brand/40"
                :aria-label="rule.name"
                @click="openRule(rule)"
              >
                <p class="m-0 truncate text-sm font-medium text-n-slate-12">
                  {{ rule.name }}
                </p>
                <p class="m-0 mt-1 text-xs text-n-slate-11">
                  {{
                    rule.version
                      ? t('KANBAN.AUTOMATIONS_WORKSPACE.EVENT_VERSION', {
                          event: eventOptions.find(
                            item => item.value === rule.eventName
                          )?.label,
                          version: t('KANBAN.AUTOMATIONS_WORKSPACE.VERSION', {
                            version: rule.version,
                          }),
                        })
                      : eventOptions.find(item => item.value === rule.eventName)
                          ?.label
                  }}
                </p>
                <p
                  v-if="rule.description"
                  class="m-0 mt-1 truncate text-xs text-n-slate-10"
                  :title="rule.description"
                >
                  {{ rule.description }}
                </p>
                <div
                  v-if="ruleFlowPreview(rule).length"
                  :data-testid="`kanban-automation-rule-preview-${rule.id}`"
                  class="mt-1.5 flex min-w-0 flex-wrap items-center gap-1"
                >
                  <span
                    v-for="step in ruleFlowPreview(rule)"
                    :key="step.id"
                    data-testid="kanban-automation-rule-step"
                    class="inline-flex max-w-40 items-center gap-1 rounded bg-n-surface-2 px-1.5 py-0.5 text-[11px] text-n-slate-10"
                    :title="step.label"
                  >
                    <i v-if="step.icon" class="size-3" :class="[step.icon]" />
                    <span class="truncate">{{ step.label }}</span>
                  </span>
                  <span
                    v-if="hiddenRuleFlowStepCount(rule)"
                    data-testid="kanban-automation-rule-more-steps"
                    class="text-[11px] text-n-slate-10"
                    :aria-label="
                      t('KANBAN.AUTOMATIONS_WORKSPACE.FLOW_PREVIEW_MORE', {
                        count: hiddenRuleFlowStepCount(rule),
                      })
                    "
                  >
                    +{{ hiddenRuleFlowStepCount(rule) }}
                  </span>
                </div>
              </button>
              <div class="flex shrink-0 items-center gap-2">
                <span
                  class="inline-flex rounded-full px-2 py-1 text-xs font-medium"
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
                <button
                  type="button"
                  :data-testid="`kanban-automation-rule-${rule.id}`"
                  class="flex size-7 items-center justify-center rounded-md text-n-slate-10 hover:bg-n-surface-2 hover:text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand"
                  :aria-label="t('KANBAN.SETTINGS.AUTOMATIONS.RULES.EDIT')"
                  @click="openRule(rule)"
                >
                  <i class="i-lucide-pencil size-3.5" aria-hidden="true" />
                </button>
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
                <Button
                  type="button"
                  icon="i-lucide-history"
                  color="slate"
                  size="xs"
                  :data-testid="`kanban-automation-versions-rule-${rule.id}`"
                  :aria-expanded="versionRuleId === rule.id"
                  :label="t('KANBAN.AUTOMATIONS_WORKSPACE.VERSIONS.OPEN')"
                  @click="toggleRuleVersions(rule)"
                />
              </div>
            </div>
            <section
              v-if="versionRuleId === rule.id"
              class="grid gap-2 border-t border-n-weak bg-n-surface-2 px-4 py-3"
              :data-testid="`kanban-automation-versions-panel-${rule.id}`"
            >
              <p class="m-0 text-xs text-n-slate-11">
                {{ t('KANBAN.AUTOMATIONS_WORKSPACE.VERSIONS.DESCRIPTION') }}
              </p>
              <p v-if="isLoadingVersions" class="m-0 text-sm text-n-slate-11">
                {{ t('KANBAN.AUTOMATIONS_WORKSPACE.VERSIONS.LOADING') }}
              </p>
              <div
                v-for="version in selectedRuleVersions"
                :key="version.id"
                class="flex flex-wrap items-center justify-between gap-2 rounded-md border border-n-weak bg-n-surface-1 px-3 py-2"
              >
                <div>
                  <p class="m-0 text-sm font-medium text-n-slate-12">
                    {{
                      t('KANBAN.AUTOMATIONS_WORKSPACE.VERSION', {
                        version: version.version,
                      })
                    }}
                  </p>
                  <p class="m-0 mt-0.5 text-xs text-n-slate-11">
                    {{ new Date(version.createdAt).toLocaleString() }}
                  </p>
                </div>
                <ConfirmButton
                  type="button"
                  icon="i-lucide-rotate-ccw"
                  color="slate"
                  confirm-color="ruby"
                  size="xs"
                  :label="t('KANBAN.AUTOMATIONS_WORKSPACE.VERSIONS.RESTORE')"
                  :confirm-label="
                    t('KANBAN.AUTOMATIONS_WORKSPACE.VERSIONS.CONFIRM_RESTORE')
                  "
                  :confirm-hint="
                    t('KANBAN.AUTOMATIONS_WORKSPACE.VERSIONS.CONFIRM_HINT')
                  "
                  :is-loading="restoringVersionId === version.id"
                  @click="restoreRuleVersion(version)"
                />
              </div>
              <p
                v-if="!isLoadingVersions && !selectedRuleVersions.length"
                class="m-0 text-sm text-n-slate-11"
              >
                {{ t('KANBAN.AUTOMATIONS_WORKSPACE.VERSIONS.EMPTY') }}
              </p>
            </section>
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
                    <p
                      v-if="previewStepContent(step)"
                      class="m-0 mt-0.5 break-words text-n-slate-10"
                    >
                      {{ previewStepContent(step) }}
                    </p>
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
                :label="t('KANBAN.AUTOMATIONS_WORKSPACE.CONNECTIONS.SAVE')"
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
          <section class="grid gap-2 border-t border-n-weak pt-4">
            <h3 class="m-0 text-sm font-medium text-n-slate-12">
              {{ t('KANBAN.AUTOMATIONS_WORKSPACE.CONNECTIONS.AUDIT_TITLE') }}
            </h3>
            <ul
              v-if="connectionAudits.length"
              class="m-0 grid list-none gap-1 p-0"
            >
              <li
                v-for="audit in connectionAudits"
                :key="audit.id"
                class="flex flex-wrap items-center justify-between gap-x-3 gap-y-1 text-xs text-n-slate-11"
              >
                <span>{{ connectionAuditDescription(audit) }}</span>
                <time :datetime="audit.createdAt">{{
                  connectionAuditTime(audit.createdAt)
                }}</time>
              </li>
            </ul>
            <p v-else class="m-0 text-xs text-n-slate-11">
              {{ t('KANBAN.AUTOMATIONS_WORKSPACE.CONNECTIONS.AUDIT_EMPTY') }}
            </p>
          </section>
        </div>
      </template>
      <template v-else>
        <div class="grid max-w-5xl gap-3">
          <dl
            class="flex flex-wrap gap-x-5 gap-y-2 border-b border-n-weak pb-3"
          >
            <div
              v-for="item in executionSummary"
              :key="item.value"
              class="flex items-baseline gap-1 text-xs"
            >
              <dt class="text-n-slate-11">{{ item.label }}</dt>
              <dd class="m-0 font-semibold text-n-slate-12">
                {{ item.count }}
              </dd>
            </div>
          </dl>
          <section
            data-testid="kanban-automations-health"
            class="flex flex-wrap items-center gap-x-4 gap-y-2 border-b border-n-weak pb-3 text-xs"
          >
            <p class="m-0 font-medium text-n-slate-12">
              {{ t('KANBAN.AUTOMATIONS_WORKSPACE.EXECUTIONS.HEALTH.TITLE') }}
            </p>
            <span
              class="rounded-full px-2 py-1 font-medium"
              :class="
                automationHealth.needsAttention
                  ? 'bg-n-ruby-3 text-n-ruby-11'
                  : 'bg-n-green-3 text-n-green-11'
              "
            >
              {{
                automationHealth.needsAttention
                  ? t(
                      'KANBAN.AUTOMATIONS_WORKSPACE.EXECUTIONS.HEALTH.ATTENTION'
                    )
                  : t('KANBAN.AUTOMATIONS_WORKSPACE.EXECUTIONS.HEALTH.HEALTHY')
              }}
            </span>
            <p v-if="automationHealth.failedCount" class="m-0 text-n-ruby-11">
              {{
                t('KANBAN.AUTOMATIONS_WORKSPACE.EXECUTIONS.HEALTH.FAILED', {
                  count: automationHealth.failedCount,
                })
              }}
            </p>
            <p v-if="automationHealth.overdueCount" class="m-0 text-n-ruby-11">
              {{
                t('KANBAN.AUTOMATIONS_WORKSPACE.EXECUTIONS.HEALTH.OVERDUE', {
                  count: automationHealth.overdueCount,
                })
              }}
            </p>
            <p
              v-if="automationHealth.abandonedCount"
              class="m-0 text-n-ruby-11"
            >
              {{
                t('KANBAN.AUTOMATIONS_WORKSPACE.EXECUTIONS.HEALTH.ABANDONED', {
                  count: automationHealth.abandonedCount,
                })
              }}
            </p>
            <p v-if="blockedMessageCount" class="m-0 text-n-amber-11">
              {{
                t(
                  'KANBAN.AUTOMATIONS_WORKSPACE.EXECUTIONS.HEALTH.BLOCKED_MESSAGES',
                  { count: blockedMessageCount }
                )
              }}
            </p>
            <p
              v-for="item in nodeFailureSummary"
              :key="item.key"
              class="m-0 text-n-ruby-11"
            >
              {{
                t(
                  'KANBAN.AUTOMATIONS_WORKSPACE.EXECUTIONS.HEALTH.NODE_FAILED',
                  {
                    node: previewStepLabel({ actionName: item.key }),
                    count: item.count,
                  }
                )
              }}
            </p>
            <p
              v-for="item in nodeErrorRates"
              :key="`rate-${item.key}`"
              class="m-0 text-n-slate-11"
            >
              {{
                t(
                  'KANBAN.AUTOMATIONS_WORKSPACE.EXECUTIONS.HEALTH.NODE_ERROR_RATE',
                  {
                    node: previewStepLabel({ actionName: item.key }),
                    percentage: item.percentage,
                  }
                )
              }}
            </p>
            <p
              v-for="item in nodeUsageSummary"
              :key="`usage-${item.key}`"
              class="m-0 text-n-slate-11"
            >
              {{
                t('KANBAN.AUTOMATIONS_WORKSPACE.EXECUTIONS.HEALTH.NODE_USAGE', {
                  node: previewStepLabel({ actionName: item.key }),
                  count: item.total,
                  failed: item.failed,
                })
              }}
            </p>
          </section>
          <article
            v-for="execution in executions"
            :key="execution.id"
            class="rounded-md border border-n-weak bg-n-surface-1 px-4 py-3"
          >
            <div class="flex items-start justify-between gap-3">
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
                  {{ executionStatusLabel(execution.status) }}
                </span>
                <Button
                  type="button"
                  icon="i-lucide-workflow"
                  color="slate"
                  size="xs"
                  :data-testid="`kanban-automation-open-execution-${execution.id}`"
                  :aria-label="
                    t('KANBAN.AUTOMATIONS_WORKSPACE.EXECUTIONS.INSPECT')
                  "
                  @click="openExecutionInCanvas(execution)"
                />
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
                  :aria-label="
                    t('KANBAN.AUTOMATIONS_WORKSPACE.EXECUTIONS.RETRY')
                  "
                  @click="retryExecution(execution)"
                />
              </div>
            </div>
            <details
              v-if="execution.actionResults?.length"
              :data-testid="`kanban-automation-execution-steps-${execution.id}`"
              class="mt-3 border-t border-n-weak pt-2"
            >
              <summary
                class="cursor-pointer text-xs font-medium text-n-brand focus:outline-none focus:ring-2 focus:ring-n-brand"
              >
                {{
                  t('KANBAN.AUTOMATIONS_WORKSPACE.EXECUTIONS.STEPS', {
                    count: execution.actionResults.length,
                  })
                }}
              </summary>
              <ol
                class="m-0 mt-2 grid list-none gap-1 border-l border-n-weak pl-3"
              >
                <li
                  v-for="(step, index) in execution.actionResults"
                  :key="`${execution.id}-${step.nodeId || index}`"
                  class="flex flex-wrap items-center justify-between gap-x-3 gap-y-1 text-xs"
                >
                  <span class="text-n-slate-12">
                    {{ previewStepLabel(step) }}
                  </span>
                  <span class="text-n-slate-11">
                    {{ executionStepStatusLabel(step.status) }}
                  </span>
                  <time
                    v-if="executionStepTimestamp(step.executedAt)"
                    :datetime="step.executedAt"
                    class="basis-full text-n-slate-11"
                  >
                    {{
                      t('KANBAN.AUTOMATIONS_WORKSPACE.EXECUTIONS.STEP_AT', {
                        time: executionStepTimestamp(step.executedAt),
                      })
                    }}
                  </time>
                  <span
                    v-if="executionStepReasonLabel(step.reason)"
                    class="basis-full text-n-slate-11"
                  >
                    {{ executionStepReasonLabel(step.reason) }}
                  </span>
                </li>
              </ol>
            </details>
          </article>
          <p v-if="!executions.length" class="m-0 text-sm text-n-slate-11">
            {{ t('KANBAN.AUTOMATIONS_WORKSPACE.EXECUTIONS.EMPTY') }}
          </p>
        </div>
      </template>
    </section>
  </main>
</template>
