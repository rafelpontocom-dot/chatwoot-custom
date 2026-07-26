<script setup>
import {
  computed,
  defineAsyncComponent,
  markRaw,
  nextTick,
  ref,
  watch,
} from 'vue';
import { Background } from '@vue-flow/background';
import { Controls } from '@vue-flow/controls';
import { useVueFlow, VueFlow } from '@vue-flow/core';
import { MiniMap } from '@vue-flow/minimap';
import { vOnClickOutside } from '@vueuse/components';
import { DirectUpload } from 'activestorage';
import '@vue-flow/controls/dist/style.css';
import '@vue-flow/core/dist/style.css';
import '@vue-flow/minimap/dist/style.css';
import { useI18n } from 'vue-i18n';

import KanbanWorkflowNode from './KanbanWorkflowNode.vue';
import KanbanWorkflowPalette from './KanbanWorkflowPalette.vue';
import KanbanWorkflowEdge from './KanbanWorkflowEdge.vue';
import { layoutKanbanWorkflow } from './layoutKanbanWorkflow';
import {
  getKanbanWorkflowNodeDefinition,
  getKanbanWorkflowNodeLabel,
  getKanbanWorkflowPaletteGroups,
} from './kanbanWorkflowNodeDefinitions';
import { useKanbanWorkflowCanvas } from './useKanbanWorkflowCanvas';
import { useKanbanWorkflowHistory } from './useKanbanWorkflowHistory';

const props = defineProps({
  modelValue: {
    type: Object,
    default: () => ({}),
  },
  stages: {
    type: Array,
    default: () => [],
  },
  agents: {
    type: Array,
    default: () => [],
  },
  teams: {
    type: Array,
    default: () => [],
  },
  customFields: {
    type: Array,
    default: () => [],
  },
  nextActionTypes: {
    type: Array,
    default: () => [],
  },
  lostReasonOptions: {
    type: Array,
    default: () => [],
  },
  conditionFields: {
    type: Array,
    default: () => [],
  },
  dateFields: {
    type: Array,
    default: () => [],
  },
  connections: {
    type: Array,
    default: () => [],
  },
  triggerOptions: {
    type: Array,
    default: () => [],
  },
  triggerValue: {
    type: String,
    default: '',
  },
  invalidNodeIds: {
    type: Array,
    default: () => [],
  },
  executionHistory: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits([
  'update:modelValue',
  'update:triggerValue',
  'clearValidation',
]);
const { t } = useI18n();
const nodes = ref([]);
const edges = ref([]);
const {
  connectNodes,
  insertNodeAfter: insertNodeInCanvas,
  removeEdge,
  removeNode,
} = useKanbanWorkflowCanvas({ nodes, edges });
const {
  canUndo,
  canRedo,
  record: recordCanvasSnapshot,
  undo,
  redo,
} = useKanbanWorkflowHistory();
const selectedNodeId = ref(null);
const selectedEdgeId = ref(null);
const inspectorTab = ref('configure');
const inspectorTabs = ['configure', 'test', 'history'];
const showNodeMenu = ref(false);
const showMobilePalette = ref(false);
const showConnectionForm = ref(false);
const connectionTargetId = ref('');
const connectionSourceHandle = ref('');
const connectionError = ref('');
const draggedConditionBranchIndex = ref(null);
const draggedPaletteNodeType = ref(null);
const insertAfterNodeId = ref(null);
const insertAfterHandle = ref(null);
const inspector = ref(null);
const builder = ref(null);
const mobilePaletteTrigger = ref(null);
const messageContentInput = ref(null);
const showEmojiPicker = ref(false);
const showMessageVariableMenu = ref(false);
const messageVariableQuery = ref('');
const isUploadingMessageAttachment = ref(false);
const EmojiIconPicker = defineAsyncComponent(
  () =>
    import('dashboard/components-next/emoji-icon-picker/EmojiIconPicker.vue')
);
const nodeTypes = {
  trigger: markRaw(KanbanWorkflowNode),
  delay: markRaw(KanbanWorkflowNode),
  wait_until_field: markRaw(KanbanWorkflowNode),
  wait_for_response: markRaw(KanbanWorkflowNode),
  wait_for_inactivity: markRaw(KanbanWorkflowNode),
  wait_for_business_hours: markRaw(KanbanWorkflowNode),
  send_message: markRaw(KanbanWorkflowNode),
  action: markRaw(KanbanWorkflowNode),
  set_field: markRaw(KanbanWorkflowNode),
  complete_next_action: markRaw(KanbanWorkflowNode),
  mark_won: markRaw(KanbanWorkflowNode),
  mark_lost: markRaw(KanbanWorkflowNode),
  condition: markRaw(KanbanWorkflowNode),
  filter: markRaw(KanbanWorkflowNode),
  message_eligibility: markRaw(KanbanWorkflowNode),
  round_robin: markRaw(KanbanWorkflowNode),
  human_handoff: markRaw(KanbanWorkflowNode),
  update_contact: markRaw(KanbanWorkflowNode),
  audit_log: markRaw(KanbanWorkflowNode),
  webhook: markRaw(KanbanWorkflowNode),
  end: markRaw(KanbanWorkflowNode),
};
const edgeTypes = { kanbanWorkflow: markRaw(KanbanWorkflowEdge) };
const { screenToFlowCoordinate } = useVueFlow();

const nodeLabels = computed(() =>
  Object.fromEntries(
    Object.keys(nodeTypes).map(type => [
      type,
      getKanbanWorkflowNodeLabel(type, t),
    ])
  )
);

const paletteGroups = computed(() => getKanbanWorkflowPaletteGroups(t));
const nodeCategoryLabels = computed(() => ({
  TRIGGER: t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODES.TRIGGER'),
  DECISION: t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.PALETTE.DECISION'),
  TIME: t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.PALETTE.TIME'),
  CUSTOMER: t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.PALETTE.CUSTOMER'),
  OPPORTUNITY: t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.PALETTE.OPPORTUNITY'),
  OPERATION: t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.PALETTE.OPERATION'),
  INTEGRATION: t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.PALETTE.INTEGRATION'),
  CONTROL: t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODES.END'),
}));
const addableNodeTypes = computed(() =>
  paletteGroups.value.flatMap(group => group.nodes.map(node => node.type))
);
const conditionOperatorOptions = computed(() => [
  { value: 'equals', label: t('KANBAN.SETTINGS.AUTOMATIONS.RULES.EQUALS') },
  {
    value: 'not_equals',
    label: t('KANBAN.SETTINGS.AUTOMATIONS.RULES.NOT_EQUALS'),
  },
  { value: 'contains', label: t('KANBAN.SETTINGS.AUTOMATIONS.RULES.CONTAINS') },
  { value: 'exists', label: t('KANBAN.SETTINGS.AUTOMATIONS.RULES.EXISTS') },
  {
    value: 'greater_than',
    label: t('KANBAN.SETTINGS.AUTOMATIONS.RULES.GREATER_THAN'),
  },
  {
    value: 'less_than',
    label: t('KANBAN.SETTINGS.AUTOMATIONS.RULES.LESS_THAN'),
  },
]);

const quietHoursTimezoneOptions = computed(() => [
  {
    value: 'America/Sao_Paulo',
    label: t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.TIMEZONES.SAO_PAULO'),
  },
  {
    value: 'Europe/Lisbon',
    label: t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.TIMEZONES.LISBON'),
  },
]);

const actionOptions = computed(() => [
  {
    value: 'move_stage',
    label: t('KANBAN.SETTINGS.AUTOMATIONS.ACTIONS.MOVE_STAGE'),
  },
  {
    value: 'assign_owner',
    label: t('KANBAN.SETTINGS.AUTOMATIONS.ACTIONS.ASSIGN_OWNER'),
  },
  {
    value: 'assign_round_robin',
    label: t('KANBAN.SETTINGS.AUTOMATIONS.ACTIONS.ASSIGN_ROUND_ROBIN'),
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
    value: 'increment_field',
    label: t('KANBAN.SETTINGS.AUTOMATIONS.ACTIONS.INCREMENT_FIELD'),
  },
  {
    value: 'clear_field',
    label: t('KANBAN.SETTINGS.AUTOMATIONS.ACTIONS.CLEAR_FIELD'),
  },
  {
    value: 'archive_card',
    label: t('KANBAN.SETTINGS.AUTOMATIONS.ACTIONS.ARCHIVE_CARD'),
  },
  {
    value: 'add_label',
    label: t('KANBAN.SETTINGS.AUTOMATIONS.ACTIONS.ADD_LABEL'),
  },
  {
    value: 'remove_label',
    label: t('KANBAN.SETTINGS.AUTOMATIONS.ACTIONS.REMOVE_LABEL'),
  },
  {
    value: 'add_note',
    label: t('KANBAN.SETTINGS.AUTOMATIONS.ACTIONS.ADD_NOTE'),
  },
]);

const roundRobinAvailabilityOptions = computed(() => [
  {
    value: 'any',
    label: t(
      'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.ROUND_ROBIN_AVAILABILITY.ANY'
    ),
  },
  {
    value: 'online_only',
    label: t(
      'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.ROUND_ROBIN_AVAILABILITY.ONLINE_ONLY'
    ),
  },
  {
    value: 'online_or_busy',
    label: t(
      'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.ROUND_ROBIN_AVAILABILITY.ONLINE_OR_BUSY'
    ),
  },
]);

const selectedNode = computed(() =>
  nodes.value.find(node => node.id === selectedNodeId.value)
);
const contactConsentAttributeKeys = [
  'marketing_messages_opt_in',
  'birthday_messages_opt_in',
  'appointment_reminders_opt_in',
];
const showMiniMap = computed(() => nodes.value.length > 4);
const selectedEdge = computed(() =>
  edges.value.find(edge => edge.id === selectedEdgeId.value)
);
const selectedEdgeSummary = computed(() => {
  if (!selectedEdge.value) return '';

  const source = nodes.value.find(
    node => node.id === selectedEdge.value.source
  );
  const target = nodes.value.find(
    node => node.id === selectedEdge.value.target
  );

  return `${source?.data?.label || selectedEdge.value.source} → ${
    target?.data?.label || selectedEdge.value.target
  }`;
});
const contactAttributeOptions = computed(() => [
  {
    value: 'date_of_birth',
    label: t(
      'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.CONTACT_ATTRIBUTES.BIRTHDAY'
    ),
  },
  {
    value: 'marketing_messages_opt_in',
    label: t(
      'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.CONTACT_ATTRIBUTES.MARKETING_OPT_IN'
    ),
  },
  {
    value: 'birthday_messages_opt_in',
    label: t(
      'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.CONTACT_ATTRIBUTES.BIRTHDAY_OPT_IN'
    ),
  },
  {
    value: 'appointment_reminders_opt_in',
    label: t(
      'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.CONTACT_ATTRIBUTES.APPOINTMENT_OPT_IN'
    ),
  },
]);
const selectedContactAttributeOption = computed(() => {
  const attributeKey = selectedNode.value?.data?.action_params?.attribute_key;
  return contactAttributeOptions.value.some(
    option => option.value === attributeKey
  )
    ? attributeKey
    : '__custom__';
});
const selectedContactAttributeIsBoolean = computed(() =>
  contactConsentAttributeKeys.includes(selectedContactAttributeOption.value)
);
const selectedContactAttributeIsDate = computed(
  () => selectedContactAttributeOption.value === 'date_of_birth'
);
const selectedContactBooleanValue = computed(() => {
  const value = selectedNode.value?.data?.action_params?.value;
  return value === true || value === 'true' || value === 1 || value === '1';
});
const selectedNodeOutputOptions = computed(() => {
  const node = selectedNode.value;
  if (!node) return [];
  const data = node.data || {};

  if (node.type === 'condition') {
    return [
      ...(data.branches || []).map(branch => ({
        value: branch.id,
        label: branch.label,
      })),
      { value: data.fallback_id, label: data.fallbackLabel },
    ].filter(option => option.value);
  }

  if (node.type === 'round_robin') {
    return (data.options || []).map(option => ({
      value: option.id,
      label: option.label,
    }));
  }

  if (
    [
      'message_eligibility',
      'send_message',
      'wait_until_field',
      'wait_for_response',
      'wait_for_inactivity',
      'wait_for_business_hours',
      'webhook',
    ].includes(node.type)
  ) {
    return (data.outputs || []).map(output => ({
      value: output.id,
      label: output.label,
    }));
  }

  return [];
});
const availableConnectionTargets = computed(() =>
  nodes.value.filter(node => node.id !== selectedNode.value?.id)
);
const selectedNodeHistory = computed(() =>
  props.executionHistory.filter(
    result => result.nodeId === selectedNode.value?.id
  )
);
const selectedActionField = computed(() =>
  props.customFields.find(
    field => field.key === selectedNode.value?.data?.action_params?.field_key
  )
);
const selectedActionFieldOptions = computed(
  () => selectedActionField.value?.options || []
);
const selectedActionName = computed(() =>
  selectedNode.value?.type === 'set_field'
    ? 'set_field'
    : selectedNode.value?.data?.action_name
);
const selectedWaitTimeoutLabel = computed(() => {
  if (selectedNode.value?.type === 'wait_for_inactivity') {
    return t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.INACTIVITY_TIMEOUT_HOURS');
  }

  return t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.RESPONSE_TIMEOUT_HOURS');
});
const conditionFieldsForWorkflow = computed(() => {
  const stageField = {
    key: 'system_stage_id',
    label: t('KANBAN.SETTINGS.SALES.SYSTEM_FIELDS.STAGE'),
    conditionOptions: props.stages.map(stage => ({
      value: String(stage.id),
      label: stage.name,
    })),
  };
  const fields = [...props.conditionFields];
  const stageFieldIndex = fields.findIndex(
    field => field.key === stageField.key
  );

  if (stageFieldIndex === -1) {
    fields.splice(0, 0, stageField);
  } else {
    fields.splice(stageFieldIndex, 1, {
      ...fields[stageFieldIndex],
      conditionOptions: stageField.conditionOptions,
    });
  }

  return fields;
});
const conditionOptionsFor = condition =>
  conditionFieldsForWorkflow.value.find(
    field => field.key === condition.field_key
  )?.conditionOptions || [];
const numericCustomFields = computed(() =>
  props.customFields.filter(field =>
    ['integer', 'decimal', 'currency', 'formula'].includes(field.fieldType)
  )
);
const messageVariables = computed(() => [
  {
    label: t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.VARIABLES.CONTACT_NAME'),
    token: '{{contact_name}}',
  },
  {
    label: t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.VARIABLES.OPPORTUNITY'),
    token: '{{opportunity_subject}}',
  },
  {
    label: t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.VARIABLES.AMOUNT'),
    token: '{{opportunity_amount}}',
  },
  ...props.customFields.map(field => ({
    label: field.label || field.key,
    token: `{{field.${field.key}}}`,
  })),
]);
const filteredMessageVariables = computed(() => {
  const query = messageVariableQuery.value.trim().toLocaleLowerCase();
  if (!query) return messageVariables.value;

  return messageVariables.value.filter(variable =>
    `${variable.label} ${variable.token}`.toLocaleLowerCase().includes(query)
  );
});
const messageAttachmentUrl = computed(() => {
  const attachment = selectedNode.value?.data?.message_attachment || {};
  if (!attachment.signed_id || !attachment.filename) return '';

  return `/rails/active_storage/blobs/redirect/${encodeURIComponent(attachment.signed_id)}/${encodeURIComponent(attachment.filename)}`;
});
const messagePreview = computed(() => {
  const content = selectedNode.value?.data?.content || '';
  return content
    .replaceAll(
      '{{contact_name}}',
      t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.PREVIEW_CONTACT')
    )
    .replaceAll(
      '{{opportunity_subject}}',
      t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.PREVIEW_OPPORTUNITY')
    )
    .replaceAll(
      '{{opportunity_amount}}',
      t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.PREVIEW_AMOUNT')
    );
});
const businessDays = computed(() => [
  { value: 1, label: t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.WEEKDAYS.MON') },
  { value: 2, label: t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.WEEKDAYS.TUE') },
  { value: 3, label: t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.WEEKDAYS.WED') },
  { value: 4, label: t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.WEEKDAYS.THU') },
  { value: 5, label: t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.WEEKDAYS.FRI') },
  { value: 6, label: t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.WEEKDAYS.SAT') },
  { value: 7, label: t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.WEEKDAYS.SUN') },
]);

const defaultData = type => {
  if (type === 'delay') return { delay_hours: 24 };
  if (type === 'wait_until_field') {
    return {
      field_key: '',
      offset_hours: -24,
      timezone: 'America/Sao_Paulo',
      failure_mode: 'stop',
    };
  }
  if (type === 'wait_for_response') {
    return { timeout_hours: 24, timeout_mode: 'continue' };
  }
  if (type === 'wait_for_inactivity') {
    return { timeout_hours: 24, interruption_mode: 'stop' };
  }
  if (type === 'wait_for_business_hours') {
    return {
      weekdays: [1, 2, 3, 4, 5],
      start_time: '09:00',
      end_time: '18:00',
      timezone: 'America/Sao_Paulo',
      failure_mode: 'stop',
    };
  }
  if (type === 'send_message') {
    return {
      channel: 'whatsapp',
      opt_in_attribute_key: 'marketing_messages_opt_in',
      content: '',
      frequency_limit_hours: '',
      quiet_hours: { start: '', end: '', timezone: 'America/Sao_Paulo' },
      message_attachment: {},
      whatsapp_template_params: {},
      failure_mode: 'stop',
    };
  }
  if (type === 'action') {
    return {
      action_name: 'set_next_action',
      action_params: {
        next_action_type: '',
        next_action_note: '',
        availability_policy: 'any',
      },
    };
  }
  if (type === 'set_field') {
    return { action_params: { field_key: '', value: '' } };
  }
  if (type === 'complete_next_action') {
    return { action_params: { completion_note: '' } };
  }
  if (type === 'condition') {
    return {
      branches: [
        {
          id: 'branch-1',
          label: t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.BRANCH'),
          match_mode: 'all',
          conditions: [{ field_key: '', operator: 'equals', value: '' }],
        },
      ],
      fallback_id: 'otherwise',
    };
  }
  if (type === 'filter') {
    return {
      match_mode: 'all',
      conditions: [{ field_key: '', operator: 'equals', value: '' }],
    };
  }
  if (type === 'message_eligibility') {
    return {
      channel: 'whatsapp',
      opt_in_attribute_key: 'marketing_messages_opt_in',
    };
  }
  if (type === 'round_robin') {
    return {
      options: [
        {
          id: 'option-1',
          label: t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.ROUND_ROBIN_PATH', {
            number: 1,
          }),
        },
        {
          id: 'option-2',
          label: t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.ROUND_ROBIN_PATH', {
            number: 2,
          }),
        },
      ],
    };
  }
  if (type === 'human_handoff') return { owner_id: '', team_id: '', note: '' };
  if (type === 'update_contact') {
    return { action_params: { attribute_key: '', value: '' } };
  }
  if (type === 'audit_log') return { content: '' };
  if (type === 'mark_lost') return { action_params: { lost_reason: '' } };
  if (type === 'webhook') return { connection_id: '', failure_mode: 'stop' };
  if (type === 'end') return { outcome: 'completed' };
  return {};
};

const endOutcomeOptions = computed(() => [
  {
    value: 'completed',
    label: t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.END_OUTCOMES.COMPLETED'),
  },
  {
    value: 'handed_off',
    label: t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.END_OUTCOMES.HANDED_OFF'),
  },
  {
    value: 'stopped',
    label: t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.END_OUTCOMES.STOPPED'),
  },
  {
    value: 'failed',
    label: t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.END_OUTCOMES.FAILED'),
  },
]);

const nodeSummary = node => {
  const data = node.data || {};
  if (node.type === 'trigger') {
    return props.triggerOptions.find(
      option => option.value === props.triggerValue
    )?.label;
  }
  if (node.type === 'delay')
    return t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.HOURS', {
      hours: data.delay_hours || 0,
    });
  if (node.type === 'wait_until_field') {
    const field = props.dateFields.find(item => item.key === data.field_key);
    if (!field) return '';

    const offsetHours = Number(data.offset_hours) || 0;
    if (offsetHours < 0) {
      return t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.DATE_OFFSET_BEFORE', {
        field: field.label,
        hours: Math.abs(offsetHours),
      });
    }
    if (offsetHours > 0) {
      return t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.DATE_OFFSET_AFTER', {
        field: field.label,
        hours: offsetHours,
      });
    }

    return t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.DATE_OFFSET_AT', {
      field: field.label,
    });
  }
  if (node.type === 'wait_for_response') {
    return t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.RESPONSE_TIMEOUT', {
      hours: data.timeout_hours || 0,
    });
  }
  if (node.type === 'wait_for_inactivity') {
    return t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.INACTIVITY_TIMEOUT', {
      hours: data.timeout_hours || 0,
    });
  }
  if (node.type === 'wait_for_business_hours') {
    return t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.BUSINESS_HOURS_SUMMARY', {
      start: data.start_time || '--:--',
      end: data.end_time || '--:--',
    });
  }
  if (node.type === 'send_message')
    return data.channel === 'email'
      ? t('KANBAN.SETTINGS.AUTOMATIONS.BIRTHDAY.EMAIL')
      : t('KANBAN.SETTINGS.AUTOMATIONS.BIRTHDAY.WHATSAPP');
  if (node.type === 'action') {
    return (
      actionOptions.value.find(option => option.value === data.action_name)
        ?.label || ''
    );
  }
  if (node.type === 'set_field') {
    const field = props.customFields.find(
      item => item.key === data.action_params?.field_key
    );
    return field?.label || '';
  }
  if (node.type === 'complete_next_action') {
    return t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.COMPLETE_NEXT_ACTION_HINT');
  }
  if (node.type === 'mark_lost') return data.action_params?.lost_reason;
  if (node.type === 'condition') return '';
  if (node.type === 'filter') {
    const fieldKey = data.conditions?.[0]?.field_key || data.field_key;
    return conditionFieldsForWorkflow.value.find(
      field => field.key === fieldKey
    )?.label;
  }
  if (node.type === 'message_eligibility') return data.channel;
  if (node.type === 'round_robin') {
    return `${data.options?.length || 0}`;
  }
  if (node.type === 'webhook') {
    return props.connections.find(
      item => item.id === Number(data.connection_id)
    )?.name;
  }
  if (node.type === 'human_handoff') {
    return (
      props.agents.find(agent => agent.id === Number(data.owner_id))?.name ||
      props.teams.find(team => team.id === Number(data.team_id))?.name
    );
  }
  if (node.type === 'update_contact') return data.action_params?.attribute_key;
  if (node.type === 'audit_log') return data.content;
  if (node.type === 'end')
    return endOutcomeOptions.value.find(option => option.value === data.outcome)
      ?.label;
  return '';
};

const routedOutputLabel = (nodeType, status) => {
  if (nodeType === 'send_message') {
    return status === 'succeeded'
      ? t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.MESSAGE_SENT')
      : t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.MESSAGE_NOT_SENT');
  }

  return status === 'succeeded'
    ? t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.SUCCEEDED')
    : t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.FAILED');
};

const nodeLabel = node => {
  if (node.type === 'action') {
    const actionName = node.data?.action_name;
    return (
      actionOptions.value.find(option => option.value === actionName)?.label ||
      nodeLabels.value[node.type]
    );
  }

  return nodeLabels.value[node.type] || node.type;
};

const executionNodeState = nodeId =>
  props.executionHistory.filter(result => result.nodeId === nodeId).at(-1)
    ?.status;

const nodeState = node => {
  if (props.invalidNodeIds.includes(node.id)) return 'invalid';

  const executionState = executionNodeState(node.id);
  if (['waiting', 'completed', 'skipped', 'failed'].includes(executionState)) {
    return executionState;
  }

  const runtimeState = node.data?.runtime_state;
  if (['waiting', 'completed', 'skipped', 'failed'].includes(runtimeState)) {
    return runtimeState;
  }

  const data = node.data || {};
  const configured = {
    trigger: Boolean(props.triggerValue),
    delay: Number(data.delay_hours) > 0,
    wait_until_field: Boolean(data.field_key),
    wait_for_response: Number(data.timeout_hours) > 0,
    wait_for_inactivity: Number(data.timeout_hours) > 0,
    wait_for_business_hours: Boolean(data.start_time && data.end_time),
    send_message: Boolean(data.content || data.whatsapp_template_name),
    action:
      Boolean(data.action_name) &&
      (!['set_field', 'increment_field', 'clear_field'].includes(
        data.action_name
      ) ||
        Boolean(data.action_params?.field_key)),
    set_field: Boolean(data.action_params?.field_key),
    update_contact: Boolean(data.action_params?.attribute_key),
    condition: (data.branches || []).every(branch =>
      (branch.conditions || []).every(condition => Boolean(condition.field_key))
    ),
    filter: (data.conditions || []).every(condition =>
      Boolean(condition.field_key)
    ),
    webhook: Boolean(data.connection_id),
    human_handoff: Boolean(data.owner_id || data.team_id),
    audit_log: Boolean(data.content),
    mark_lost: Boolean(data.action_params?.lost_reason),
  };

  return configured[node.type] === false ? 'draft' : 'valid';
};

const nodeStateLabels = computed(() => ({
  draft: t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODE_STATES.DRAFT'),
  valid: t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODE_STATES.VALID'),
  invalid: t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODE_STATES.INVALID'),
  waiting: t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODE_STATES.WAITING'),
  completed: t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODE_STATES.COMPLETED'),
  skipped: t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODE_STATES.SKIPPED'),
  failed: t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODE_STATES.FAILED'),
}));

const inspectorTabLabel = tab => {
  switch (tab) {
    case 'configure':
      return t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.INSPECTOR.CONFIGURE');
    case 'test':
      return t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.INSPECTOR.TEST');
    default:
      return t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.INSPECTOR.HISTORY');
  }
};

const inspectorTabIcon = tab =>
  ({
    configure: 'i-lucide-sliders-horizontal',
    test: 'i-lucide-flask-conical',
    history: 'i-lucide-history',
  })[tab];

const inspectorStateTone = state =>
  ({
    draft: 'bg-n-slate-3 text-n-slate-11',
    valid: 'bg-n-green-3 text-n-green-11',
    invalid: 'bg-n-ruby-3 text-n-ruby-11',
    waiting: 'bg-n-amber-3 text-n-amber-11',
    completed: 'bg-n-green-3 text-n-green-11',
    skipped: 'bg-n-slate-3 text-n-slate-11',
    failed: 'bg-n-ruby-3 text-n-ruby-11',
  })[state] || 'bg-n-slate-3 text-n-slate-11';

const handleInspectorTabKeydown = (event, tab) => {
  const currentIndex = inspectorTabs.indexOf(tab);
  const nextIndex = {
    ArrowRight: (currentIndex + 1) % inspectorTabs.length,
    ArrowDown: (currentIndex + 1) % inspectorTabs.length,
    ArrowLeft: (currentIndex - 1 + inspectorTabs.length) % inspectorTabs.length,
    ArrowUp: (currentIndex - 1 + inspectorTabs.length) % inspectorTabs.length,
    Home: 0,
    End: inspectorTabs.length - 1,
  }[event.key];

  if (nextIndex === undefined) return;

  event.preventDefault();
  const nextTab = inspectorTabs[nextIndex];
  inspectorTab.value = nextTab;
  nextTick(() =>
    inspector.value?.querySelector(`[data-inspector-tab="${nextTab}"]`)?.focus()
  );
};

const historyStatusLabel = status => {
  const state = status === 'succeeded' ? 'completed' : status;
  return nodeStateLabels.value[state] || nodeStateLabels.value.skipped;
};

const historyTimestamp = timestamp => {
  const parsed = new Date(timestamp).getTime();
  return Number.isFinite(parsed) ? new Date(parsed).toLocaleString() : '';
};

const executionResultForNode = nodeId =>
  props.executionHistory.filter(result => result.nodeId === nodeId).at(-1);

const messageEligibilityBlockReason = reason => {
  if (reason === 'opt_in_required') {
    return t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.MESSAGE_BLOCKED_OPT_IN');
  }
  if (reason === 'outside_whatsapp_window') {
    return t(
      'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.MESSAGE_BLOCKED_REPLY_WINDOW'
    );
  }
  if (reason === 'no_compatible_conversation') {
    return t(
      'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.MESSAGE_BLOCKED_CONVERSATION'
    );
  }

  return '';
};

const contactAttributeValueSummary = params => {
  const value = params?.value;
  if (!contactConsentAttributeKeys.includes(params?.attribute_key)) {
    return value;
  }

  const enabled =
    value === true || value === 'true' || value === 1 || value === '1';
  if (enabled) {
    return t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.CONTACT_VALUE_ENABLED');
  }

  return t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.CONTACT_VALUE_DISABLED');
};

const nodeChips = node => {
  const data = node.data || {};
  if (node.type === 'send_message') {
    return [
      data.channel,
      data.content?.split('\n')[0] || data.whatsapp_template_params?.name,
    ].filter(Boolean);
  }
  if (node.type === 'message_eligibility') {
    const blockReason = messageEligibilityBlockReason(
      executionResultForNode(node.id)?.reason
    );
    return [data.channel, data.opt_in_attribute_key, blockReason].filter(
      Boolean
    );
  }
  if (node.type === 'set_field') {
    const field = props.customFields.find(
      item => item.key === data.action_params?.field_key
    );
    return [field?.label, data.action_params?.value].filter(Boolean);
  }
  if (node.type === 'update_contact') {
    return [
      data.action_params?.attribute_key,
      contactAttributeValueSummary(data.action_params),
    ].filter(item => item !== undefined && item !== null && item !== '');
  }
  if (node.type === 'complete_next_action') {
    return [data.action_params?.completion_note].filter(Boolean);
  }
  if (
    node.type === 'action' &&
    ['set_field', 'increment_field', 'clear_field'].includes(data.action_name)
  ) {
    const field = props.customFields.find(
      item => item.key === data.action_params?.field_key
    );
    return [field?.label, data.action_params?.value].filter(Boolean);
  }
  if (node.type === 'action') {
    const params = data.action_params || {};
    if (data.action_name === 'move_stage') {
      return props.stages
        .filter(stage => stage.id === Number(params.stage_id))
        .map(stage => stage.name);
    }
    if (data.action_name === 'assign_owner') {
      return props.agents
        .filter(agent => agent.id === Number(params.owner_id))
        .map(agent => agent.name);
    }
    if (data.action_name === 'assign_round_robin') {
      return props.agents
        .filter(agent => Array(params.owner_ids).map(Number).includes(agent.id))
        .map(agent => agent.name);
    }
    if (data.action_name === 'set_next_action') {
      return [params.next_action_type, params.next_action_at].filter(Boolean);
    }
    if (['add_label', 'remove_label'].includes(data.action_name)) {
      return [params.label].filter(Boolean);
    }
    if (data.action_name === 'add_note') {
      return [params.content?.split('\n')[0]].filter(Boolean);
    }
  }
  if (node.type === 'webhook') {
    const connection = props.connections.find(
      item => item.id === Number(data.connection_id)
    );
    return [
      connection?.name,
      data.failure_mode === 'route'
        ? t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.FAILED')
        : null,
    ].filter(Boolean);
  }
  if (node.type === 'round_robin') {
    return (data.options || []).map(option => option.label).filter(Boolean);
  }

  return [];
};

function openNodeMenuAfter(nodeId, sourceHandle = null) {
  insertAfterNodeId.value = nodeId;
  insertAfterHandle.value = sourceHandle;
  showNodeMenu.value = true;
}

function nodePosition() {
  const source = nodes.value.find(node => node.id === insertAfterNodeId.value);
  if (!source)
    return {
      x: 220 + nodes.value.length * 36,
      y: 80 + nodes.value.length * 28,
    };

  return { x: source.position.x + 220, y: source.position.y };
}

function selectNode(nodeOrId) {
  selectedNodeId.value = typeof nodeOrId === 'string' ? nodeOrId : nodeOrId.id;
  selectedEdgeId.value = null;
  inspectorTab.value = 'configure';
  nextTick(() => inspector.value?.focus());
}

const decorateNode = node => {
  const data = {
    ...defaultData(node.type),
    ...(node.data || {}),
  };
  if (node.type === 'action') {
    data.action_params = {
      availability_policy: 'any',
      ...(node.data?.action_params || {}),
    };
  }
  if (node.type === 'complete_next_action') {
    data.action_params = {
      completion_note: '',
      schedule_next_action: false,
      next_action_type: '',
      next_action_at: '',
      next_action_note: '',
      ...(node.data?.action_params || {}),
    };
  }
  if (node.type === 'condition' && !Array.isArray(node.data?.branches)) {
    data.branches = [
      {
        id: 'yes',
        label: t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.YES'),
        match_mode: node.data?.match_mode || 'all',
        conditions: node.data?.conditions || [
          {
            field_key: node.data?.field_key || '',
            operator: node.data?.operator || 'equals',
            value: node.data?.value || '',
          },
        ],
      },
    ];
    data.fallback_id = 'no';
  }
  if (node.type === 'condition') {
    data.branches = data.branches.map(branch => ({
      ...branch,
      conditions: (branch.conditions || []).map((condition, index) =>
        index === 0
          ? condition
          : {
              ...condition,
              join_operator:
                condition.join_operator ||
                (branch.match_mode === 'any' ? 'or' : 'and'),
            }
      ),
    }));
  }
  if (node.type === 'filter') {
    data.conditions = (data.conditions || []).map((condition, index) =>
      index === 0
        ? condition
        : {
            ...condition,
            join_operator:
              condition.join_operator ||
              (data.match_mode === 'any' ? 'or' : 'and'),
          }
    );
  }
  if (node.type === 'message_eligibility') {
    data.outputs = [
      {
        id: 'eligible',
        label: t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.ELIGIBLE'),
      },
      {
        id: 'otherwise',
        label: t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.OTHERWISE'),
      },
    ];
  }
  if (node.type === 'wait_until_field' && data.failure_mode === 'route') {
    data.outputs = [
      {
        id: 'succeeded',
        label: t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.DATE_READY'),
      },
      {
        id: 'failed',
        label: t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.DATE_UNAVAILABLE'),
      },
    ];
  }
  if (node.type === 'wait_for_response' && data.timeout_mode === 'route') {
    data.outputs = [
      {
        id: 'received',
        label: t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.RESPONSE_RECEIVED'),
      },
      {
        id: 'timeout',
        label: t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.RESPONSE_EXPIRED'),
      },
    ];
  }
  if (
    node.type === 'wait_for_inactivity' &&
    data.interruption_mode === 'route'
  ) {
    data.outputs = [
      {
        id: 'inactive',
        label: t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.INACTIVITY_CONFIRMED'),
      },
      {
        id: 'responded',
        label: t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.INACTIVITY_INTERRUPTED'),
      },
    ];
  }
  if (
    node.type === 'wait_for_business_hours' &&
    data.failure_mode === 'route'
  ) {
    data.outputs = [
      {
        id: 'succeeded',
        label: t(
          'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.BUSINESS_HOURS_AVAILABLE'
        ),
      },
      {
        id: 'failed',
        label: t(
          'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.BUSINESS_HOURS_UNAVAILABLE'
        ),
      },
    ];
  }
  if (
    ['send_message', 'webhook'].includes(node.type) &&
    data.failure_mode === 'route'
  ) {
    data.outputs = [
      {
        id: 'succeeded',
        label: routedOutputLabel(node.type, 'succeeded'),
      },
      {
        id: 'failed',
        label: routedOutputLabel(node.type, 'failed'),
      },
    ];
  }

  return {
    ...node,
    data: {
      ...data,
      kind: node.type,
      category: getKanbanWorkflowNodeDefinition(node.type)?.category,
      categoryLabel:
        nodeCategoryLabels.value[
          getKanbanWorkflowNodeDefinition(node.type)?.category
        ],
      icon: getKanbanWorkflowNodeDefinition(node.type)?.icon,
      terminal: getKanbanWorkflowNodeDefinition(node.type)?.terminal,
      label: nodeLabel({ ...node, data }),
      summary: nodeSummary({ ...node, data }),
      invalid: props.invalidNodeIds.includes(node.id),
      state: nodeState({ ...node, data }),
      stateLabel: nodeStateLabels.value[nodeState({ ...node, data })],
      chips: nodeChips({ ...node, data }),
      branches: data.branches,
      outputs: data.outputs,
      fallbackId: data.fallback_id,
      fallbackLabel: t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.OTHERWISE'),
      canAddAfter:
        !getKanbanWorkflowNodeDefinition(node.type)?.terminal &&
        ![
          'condition',
          'round_robin',
          'message_eligibility',
          'send_message',
          'wait_for_response',
          'wait_for_inactivity',
          'wait_for_business_hours',
          'webhook',
          'end',
        ].includes(node.type) &&
        !data.outputs?.length,
      addAfterLabel: t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.ADD_AFTER'),
      addAfter: openNodeMenuAfter,
      addAfterOption: openNodeMenuAfter,
      id: node.id,
      select: selectNode,
    },
  };
};

function focusFirstInvalidNode() {
  const invalidNodeId = props.invalidNodeIds.find(id =>
    nodes.value.some(node => node.id === id)
  );
  if (!invalidNodeId) return;

  selectedNodeId.value = invalidNodeId;
  selectedEdgeId.value = null;
  nextTick(() => inspector.value?.focus());
}

const defaultFlow = () => ({
  nodes: [
    { id: 'trigger', type: 'trigger', position: { x: 32, y: 180 }, data: {} },
    { id: 'end', type: 'end', position: { x: 300, y: 180 }, data: {} },
  ],
  edges: [{ id: 'trigger-end', source: 'trigger', target: 'end' }],
});

const applyFlow = flow => {
  const source = flow?.nodes?.length ? flow : defaultFlow();
  const previousSelectedNodeId = selectedNodeId.value;
  nodes.value = source.nodes.map(decorateNode);
  // The decorator is initialized before this function is invoked by the watcher.
  // eslint-disable-next-line no-use-before-define
  edges.value = (source.edges || []).map(decorateEdge);
  selectedNodeId.value = nodes.value.some(
    node => node.id === previousSelectedNodeId
  )
    ? previousSelectedNodeId
    : null;
  focusFirstInvalidNode();
};

const persistedNodeData = data => {
  const persisted = Object.fromEntries(
    Object.entries(data).filter(
      ([key]) =>
        ![
          'kind',
          'category',
          'categoryLabel',
          'icon',
          'terminal',
          'label',
          'summary',
          'yesLabel',
          'noLabel',
          'canAddAfter',
          'addAfterLabel',
          'addAfter',
          'invalid',
          'state',
          'stateLabel',
          'chips',
          'runtime_state',
          'outputs',
          'id',
          'select',
        ].includes(key)
    )
  );
  const quietHours = persisted.quiet_hours || {};

  if (!quietHours.start && !quietHours.end) delete persisted.quiet_hours;

  return persisted;
};

const canvasSnapshot = () => ({
  nodes: nodes.value.map(({ id, type, position, data }) => ({
    id,
    type,
    position,
    data: persistedNodeData(data),
  })),
  edges: edges.value.map(
    ({ id, source, target, sourceHandle, targetHandle }) => ({
      id,
      source,
      target,
      sourceHandle,
      targetHandle,
    })
  ),
});

const restoreCanvasSnapshot = snapshot => {
  nodes.value = snapshot.nodes.map(decorateNode);
  // eslint-disable-next-line no-use-before-define
  edges.value = snapshot.edges.map(decorateEdge);
  selectedNodeId.value = null;
  selectedEdgeId.value = null;
  showEmojiPicker.value = false;
  showMessageVariableMenu.value = false;
  messageVariableQuery.value = '';
};

function recordCanvasState() {
  recordCanvasSnapshot(canvasSnapshot());
}

function recordInspectorState(event) {
  if (!['INPUT', 'SELECT', 'TEXTAREA'].includes(event.target?.tagName)) return;

  recordCanvasState();
}

const edgeWasTraversed = edge => {
  const sourceResult = executionResultForNode(edge.source);
  const targetResult = executionResultForNode(edge.target);
  if (!sourceResult && !targetResult) return false;
  if (!edge.sourceHandle) return true;

  const selectedHandle = sourceResult?.branch || sourceResult?.optionId;
  return selectedHandle === edge.sourceHandle;
};

const decorateEdge = edge => ({
  ...edge,
  type: 'kanbanWorkflow',
  data: {
    active: edgeWasTraversed(edge),
    remove: () => {
      recordCanvasState();
      removeEdge(edge.id);
    },
    removeLabel: t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.DELETE_CONNECTION'),
  },
});

const undoCanvas = () => {
  const snapshot = undo(canvasSnapshot());
  if (snapshot) restoreCanvasSnapshot(snapshot);
};

const redoCanvas = () => {
  const snapshot = redo(canvasSnapshot());
  if (snapshot) restoreCanvasSnapshot(snapshot);
};

const autoArrangeCanvas = () => {
  recordCanvasState();
  nodes.value = layoutKanbanWorkflow(nodes.value, edges.value).map(
    decorateNode
  );
};

const emitFlow = () => {
  const flow = {
    nodes: nodes.value.map(({ id, type, position, data }) => ({
      id,
      type,
      position,
      data: persistedNodeData(data),
    })),
    edges: edges.value.map(
      ({ id, source, target, sourceHandle, targetHandle }) => ({
        id,
        source,
        target,
        sourceHandle,
        targetHandle,
      })
    ),
  };
  if (JSON.stringify(flow) !== JSON.stringify(props.modelValue)) {
    emit('update:modelValue', flow);
  }
};

watch(
  () => props.modelValue,
  flow => applyFlow(flow),
  { deep: true, immediate: true }
);
watch(
  () => props.invalidNodeIds,
  () => {
    nodes.value = nodes.value.map(decorateNode);
    focusFirstInvalidNode();
  },
  { deep: true }
);
watch(
  () => props.executionHistory,
  () => {
    nodes.value = nodes.value.map(decorateNode);
    edges.value = edges.value.map(decorateEdge);
  },
  { deep: true }
);
watch([nodes, edges], emitFlow, { deep: true });

const addNodeOfType = (type, position = null) => {
  recordCanvasState();
  const id = `${type}-${Date.now()}`;
  const node = decorateNode({
    id,
    type,
    position: position || nodePosition(type),
    data: defaultData(type),
  });
  nodes.value.push(node);
  insertNodeInCanvas({
    node,
    sourceId: insertAfterNodeId.value,
    sourceHandle: insertAfterHandle.value,
  });
  edges.value = edges.value.map(decorateEdge);
  selectedNodeId.value = id;
  showNodeMenu.value = false;
  insertAfterNodeId.value = null;
  insertAfterHandle.value = null;
};

const addNodeFromMobilePalette = type => {
  showMobilePalette.value = false;
  addNodeOfType(type);
};

const closeMobilePalette = () => {
  showMobilePalette.value = false;
  nextTick(() => mobilePaletteTrigger.value?.focus());
};

const startPaletteDrag = type => {
  draggedPaletteNodeType.value = type;
};

const onCanvasDrop = event => {
  event.preventDefault();
  const type =
    event.dataTransfer.getData('application/x-kanban-workflow-node') ||
    draggedPaletteNodeType.value;
  draggedPaletteNodeType.value = null;
  if (!addableNodeTypes.value.includes(type)) return;

  addNodeOfType(
    type,
    screenToFlowCoordinate({ x: event.clientX, y: event.clientY })
  );
};

const onConnect = connection => {
  recordCanvasState();
  connectNodes({ ...connection, type: 'kanbanWorkflow' });
};

const onNodeDragStart = () => {
  recordCanvasState();
};

const onEdgeClick = ({ edge }) => {
  selectedNodeId.value = null;
  selectedEdgeId.value = edge.id;
  nextTick(() => inspector.value?.focus());
};

function closeInspector() {
  selectedNodeId.value = null;
  selectedEdgeId.value = null;
  inspectorTab.value = 'configure';
  showEmojiPicker.value = false;
  showMessageVariableMenu.value = false;
  messageVariableQuery.value = '';
  showConnectionForm.value = false;
  connectionTargetId.value = '';
  connectionSourceHandle.value = '';
  nextTick(() => builder.value?.focus());
}

const openConnectionForm = () => {
  if (!selectedNode.value || selectedNode.value.data.terminal) return;

  connectionSourceHandle.value =
    selectedNodeOutputOptions.value[0]?.value || '';
  connectionTargetId.value = availableConnectionTargets.value[0]?.id || '';
  connectionError.value = '';
  showConnectionForm.value = true;
};

const connectionCreatesCycle = (sourceId, targetId) => {
  const visited = new Set();
  const pending = [targetId];

  while (pending.length) {
    const nodeId = pending.pop();
    if (nodeId === sourceId) return true;
    if (!visited.has(nodeId)) {
      visited.add(nodeId);
      edges.value
        .filter(edge => edge.source === nodeId)
        .forEach(edge => pending.push(edge.target));
    }
  }

  return false;
};

const connectSelectedNode = () => {
  if (!selectedNode.value || !connectionTargetId.value) return;
  if (connectionCreatesCycle(selectedNode.value.id, connectionTargetId.value)) {
    connectionError.value = t(
      'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.CONNECTION_CYCLE_ERROR'
    );
    return;
  }

  recordCanvasState();
  connectNodes({
    source: selectedNode.value.id,
    sourceHandle: connectionSourceHandle.value || undefined,
    target: connectionTargetId.value,
    type: 'kanbanWorkflow',
  });
  edges.value = edges.value.map(decorateEdge);
  showConnectionForm.value = false;
};

const selectContactAttribute = event => {
  if (!selectedNode.value || selectedNode.value.type !== 'update_contact')
    return;

  recordCanvasState();
  selectedNode.value.data.action_params.attribute_key =
    event.target.value === '__custom__' ? '' : event.target.value;
};

const updateContactBooleanValue = event => {
  if (!selectedNode.value || selectedNode.value.type !== 'update_contact')
    return;

  recordCanvasState();
  selectedNode.value.data.action_params.value = event.target.checked;
};

const handleInspectorKeydown = event => {
  if (event.key === 'Escape') {
    event.preventDefault();
    closeInspector();
    return;
  }

  if (event.key !== 'Tab') return;

  const focusable = [
    ...event.currentTarget.querySelectorAll(
      'button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled])'
    ),
  ];
  if (!focusable.length) return;

  const first = focusable[0];
  const last = focusable.at(-1);
  if (event.shiftKey && document.activeElement === first) {
    event.preventDefault();
    last.focus();
  } else if (!event.shiftKey && document.activeElement === last) {
    event.preventDefault();
    first.focus();
  }
};

const removeSelectedEdge = () => {
  if (!selectedEdgeId.value) return;
  recordCanvasState();
  removeEdge(selectedEdgeId.value);
  closeInspector();
};

const insertMessageText = value => {
  const node = selectedNode.value;
  if (!node || node.type !== 'send_message') return;

  const input = messageContentInput.value;
  const content = node.data.content || '';
  const start = input?.selectionStart ?? content.length;
  const end = input?.selectionEnd ?? content.length;
  node.data.content = `${content.slice(0, start)}${value}${content.slice(end)}`;
  node.data = decorateNode(node).data;
  emit('clearValidation');
  showEmojiPicker.value = false;
  showMessageVariableMenu.value = false;
  messageVariableQuery.value = '';

  nextTick(() => {
    input?.focus();
    input?.setSelectionRange(start + value.length, start + value.length);
  });
};

const refreshSelectedNode = () => {
  const node = selectedNode.value;
  if (!node) return;

  node.data = decorateNode(node).data;
  emit('clearValidation');
};

const uploadMessageAttachment = async event => {
  const file = event.target.files?.[0];
  if (
    !file ||
    !selectedNode.value ||
    selectedNode.value.type !== 'send_message'
  ) {
    return;
  }

  if (!file.type.startsWith('image/') || file.size > 10 * 1024 * 1024) {
    emit('clearValidation');
    event.target.value = '';
    return;
  }

  isUploadingMessageAttachment.value = true;
  const upload = new DirectUpload(file, '/rails/active_storage/direct_uploads');
  upload.create((uploadError, blob) => {
    isUploadingMessageAttachment.value = false;
    event.target.value = '';
    if (uploadError) return;

    selectedNode.value.data.message_attachment = {
      signed_id: blob.signed_id,
      filename: blob.filename,
      content_type: blob.content_type,
    };
    refreshSelectedNode();
  });
};

const removeMessageAttachment = () => {
  if (!selectedNode.value || selectedNode.value.type !== 'send_message') return;

  selectedNode.value.data.message_attachment = {};
  refreshSelectedNode();
};

const updateNode = () => {
  refreshSelectedNode();
};

const addCondition = branch => {
  if (!['condition', 'filter'].includes(selectedNode.value?.type)) return;

  branch.conditions.push({
    join_operator: branch.match_mode === 'any' ? 'or' : 'and',
    field_key: '',
    operator: 'equals',
    value: '',
  });
  updateNode();
};

const removeCondition = (branch, index) => {
  if (
    !['condition', 'filter'].includes(selectedNode.value?.type) ||
    branch.conditions.length === 1
  ) {
    return;
  }

  branch.conditions.splice(index, 1);
  updateNode();
};

const addConditionBranch = () => {
  if (selectedNode.value?.type !== 'condition') return;

  const number = selectedNode.value.data.branches.length + 1;
  selectedNode.value.data.branches.push({
    id: `branch-${Date.now()}`,
    label: `${t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.BRANCH')} ${number}`,
    conditions: [{ field_key: '', operator: 'equals', value: '' }],
  });
  updateNode();
};

const removeConditionBranch = index => {
  if (
    selectedNode.value?.type !== 'condition' ||
    selectedNode.value.data.branches.length === 1
  ) {
    return;
  }

  const [removedBranch] = selectedNode.value.data.branches.splice(index, 1);
  edges.value = edges.value.filter(
    edge =>
      !(
        edge.source === selectedNode.value.id &&
        edge.sourceHandle === removedBranch.id
      )
  );
  updateNode();
};

const moveConditionBranch = (index, direction) => {
  const branches = selectedNode.value?.data?.branches;
  const targetIndex = index + direction;
  if (
    selectedNode.value?.type !== 'condition' ||
    !branches?.[targetIndex] ||
    !branches[index]
  ) {
    return;
  }

  recordCanvasState();
  [branches[index], branches[targetIndex]] = [
    branches[targetIndex],
    branches[index],
  ];
  updateNode();
};

const startConditionBranchDrag = index => {
  draggedConditionBranchIndex.value = index;
};

const dropConditionBranch = targetIndex => {
  const sourceIndex = draggedConditionBranchIndex.value;
  draggedConditionBranchIndex.value = null;
  if (sourceIndex === null || sourceIndex === targetIndex) return;

  const branches = selectedNode.value?.data?.branches;
  if (
    selectedNode.value?.type !== 'condition' ||
    !branches?.[sourceIndex] ||
    !branches[targetIndex]
  ) {
    return;
  }

  recordCanvasState();
  const [branch] = branches.splice(sourceIndex, 1);
  branches.splice(targetIndex, 0, branch);
  updateNode();
};

const addRoundRobinOption = () => {
  if (selectedNode.value?.type !== 'round_robin') return;

  const number = selectedNode.value.data.options.length + 1;
  selectedNode.value.data.options.push({
    id: `option-${Date.now()}`,
    label: t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.ROUND_ROBIN_PATH', {
      number,
    }),
  });
  updateNode();
};

const removeRoundRobinOption = index => {
  if (
    selectedNode.value?.type !== 'round_robin' ||
    selectedNode.value.data.options.length <= 2
  ) {
    return;
  }

  selectedNode.value.data.options.splice(index, 1);
  updateNode();
};

const removeSelectedNode = () => {
  const node = selectedNode.value;
  if (!node || ['trigger', 'end'].includes(node.type)) return;
  recordCanvasState();
  removeNode(node.id);
  closeInspector();
};

const moveSelectedNode = event => {
  const offsets = {
    ArrowUp: { x: 0, y: -1 },
    ArrowDown: { x: 0, y: 1 },
    ArrowLeft: { x: -1, y: 0 },
    ArrowRight: { x: 1, y: 0 },
  };
  const offset = offsets[event.key];
  if (!selectedNode.value || !offset) return false;

  event.preventDefault();
  recordCanvasState();
  const distance = event.shiftKey ? 40 : 16;
  const nodeId = selectedNode.value.id;
  nodes.value = nodes.value.map(node =>
    node.id === nodeId
      ? {
          ...node,
          position: {
            x: node.position.x + offset.x * distance,
            y: node.position.y + offset.y * distance,
          },
        }
      : node
  );
  return true;
};

const handleBuilderKeydown = event => {
  if (event.key === 'Escape' && showMobilePalette.value) {
    event.preventDefault();
    closeMobilePalette();
    return;
  }

  if (event.key === 'Escape' && showNodeMenu.value) {
    event.preventDefault();
    showNodeMenu.value = false;
    insertAfterNodeId.value = null;
    insertAfterHandle.value = null;
    return;
  }

  const target = event.target;
  if (
    target instanceof HTMLElement &&
    target.closest('input, select, textarea, [contenteditable="true"]')
  ) {
    return;
  }

  if (
    (event.ctrlKey || event.metaKey) &&
    event.key.toLocaleLowerCase() === 'z'
  ) {
    event.preventDefault();
    if (event.shiftKey) redoCanvas();
    else undoCanvas();
    return;
  }

  if (moveSelectedNode(event)) return;

  if (!['Delete', 'Backspace'].includes(event.key)) return;

  if (selectedEdge.value) {
    event.preventDefault();
    removeSelectedEdge();
  } else if (
    selectedNode.value &&
    !['trigger', 'end'].includes(selectedNode.value.type)
  ) {
    event.preventDefault();
    removeSelectedNode();
  }
};
</script>

<template>
  <section
    ref="builder"
    data-testid="kanban-workflow-builder"
    class="relative flex h-full min-h-[34rem] min-w-0 flex-1 overflow-hidden rounded-md border border-n-weak bg-n-surface-2"
    tabindex="0"
    @keydown="handleBuilderKeydown"
  >
    <KanbanWorkflowPalette
      :groups="paletteGroups"
      :title="t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.PALETTE.TITLE')"
      :search-placeholder="
        t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.PALETTE.SEARCH')
      "
      :empty-label="t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.PALETTE.EMPTY')"
      @add="addNodeOfType"
      @drag-start="startPaletteDrag"
    />
    <div
      data-testid="kanban-workflow-canvas"
      role="region"
      class="relative h-full min-h-[34rem] flex-1"
      :aria-label="t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.CANVAS_LABEL')"
    >
      <div
        data-testid="kanban-workflow-canvas-toolbar"
        class="absolute right-3 top-3 z-20 flex items-center gap-1 rounded-md border border-n-weak bg-n-surface-1 p-1 shadow-sm"
      >
        <button
          type="button"
          data-testid="kanban-workflow-undo"
          class="flex size-8 items-center justify-center rounded-md border border-n-weak bg-n-surface-1 text-n-slate-11 shadow-sm hover:bg-n-surface-2 disabled:cursor-not-allowed disabled:opacity-50 focus:outline-none focus:ring-2 focus:ring-n-brand"
          :disabled="!canUndo"
          :aria-label="t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.UNDO')"
          :title="t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.UNDO')"
          @click="undoCanvas"
        >
          <i class="i-lucide-undo-2 size-4" aria-hidden="true" />
        </button>
        <button
          type="button"
          data-testid="kanban-workflow-redo"
          class="flex size-8 items-center justify-center rounded-md border border-n-weak bg-n-surface-1 text-n-slate-11 shadow-sm hover:bg-n-surface-2 disabled:cursor-not-allowed disabled:opacity-50 focus:outline-none focus:ring-2 focus:ring-n-brand"
          :disabled="!canRedo"
          :aria-label="t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.REDO')"
          :title="t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.REDO')"
          @click="redoCanvas"
        >
          <i class="i-lucide-redo-2 size-4" aria-hidden="true" />
        </button>
        <button
          type="button"
          data-testid="kanban-workflow-auto-arrange"
          class="flex size-8 items-center justify-center rounded-md border border-n-weak bg-n-surface-1 text-n-slate-11 shadow-sm hover:bg-n-surface-2 focus:outline-none focus:ring-2 focus:ring-n-brand"
          :aria-label="t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.AUTO_ARRANGE')"
          :title="t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.AUTO_ARRANGE')"
          @click="autoArrangeCanvas"
        >
          <i class="i-lucide-layout-dashboard size-4" aria-hidden="true" />
        </button>
        <button
          ref="mobilePaletteTrigger"
          type="button"
          data-testid="kanban-workflow-open-mobile-palette"
          class="flex size-8 items-center justify-center rounded-md bg-n-brand text-white hover:bg-n-brand/90 focus:outline-none focus:ring-2 focus:ring-n-brand lg:hidden"
          :aria-label="t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.ADD_NODE')"
          :aria-expanded="showMobilePalette"
          aria-controls="kanban-workflow-mobile-palette"
          @click="showMobilePalette = true"
        >
          <i class="i-lucide-plus size-4" aria-hidden="true" />
        </button>
        <button
          type="button"
          data-testid="kanban-workflow-add-node"
          class="hidden size-8 items-center justify-center rounded-md bg-n-brand text-white hover:bg-n-brand/90 focus:outline-none focus:ring-2 focus:ring-n-brand lg:flex"
          :aria-label="t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.ADD_NODE')"
          :aria-expanded="showNodeMenu"
          aria-controls="kanban-workflow-node-menu"
          @click="openNodeMenuAfter(null)"
        >
          <i class="i-lucide-plus size-4" />
        </button>
        <div
          v-if="showNodeMenu"
          id="kanban-workflow-node-menu"
          data-testid="kanban-workflow-node-menu"
          class="absolute right-0 top-10 grid max-h-[min(28rem,calc(100vh-7rem))] min-w-56 overflow-y-auto rounded-md border border-n-weak bg-n-surface-1 p-1.5 shadow-lg"
        >
          <div
            v-for="group in paletteGroups"
            :key="group.key"
            data-testid="kanban-workflow-node-menu-group"
            class="border-b border-n-weak py-1.5 first:pt-0 last:border-b-0 last:pb-0"
          >
            <p
              class="m-0 flex h-6 items-center gap-1.5 px-1.5 text-2xs font-semibold uppercase tracking-wide text-n-slate-10"
            >
              <i class="size-3" :class="group.icon" aria-hidden="true" />
              {{ group.label }}
            </p>
            <button
              v-for="node in group.nodes"
              :key="node.type"
              type="button"
              class="flex h-8 w-full items-center gap-2 rounded px-1.5 text-left text-xs font-medium text-n-slate-12 hover:bg-n-surface-2 focus:outline-none focus:ring-2 focus:ring-n-brand"
              @click="addNodeOfType(node.type)"
            >
              <i
                class="size-3.5 text-n-slate-10"
                :class="node.icon"
                aria-hidden="true"
              />
              <span class="truncate">{{ node.label }}</span>
            </button>
          </div>
        </div>
      </div>
      <div
        v-if="showMobilePalette"
        id="kanban-workflow-mobile-palette"
        data-testid="kanban-workflow-mobile-palette"
        class="absolute inset-3 z-30 flex flex-col overflow-hidden rounded-md border border-n-weak bg-n-surface-1 shadow-xl lg:hidden"
      >
        <div
          class="flex h-11 items-center justify-end border-b border-n-weak px-2"
        >
          <button
            type="button"
            class="flex size-8 items-center justify-center rounded-md text-n-slate-10 hover:bg-n-surface-2 hover:text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand"
            :aria-label="t('KANBAN.ACTIONS.CLOSE')"
            :title="t('KANBAN.ACTIONS.CLOSE')"
            @click="closeMobilePalette"
          >
            <i class="i-lucide-x size-4" aria-hidden="true" />
          </button>
        </div>
        <KanbanWorkflowPalette
          mobile
          :groups="paletteGroups"
          :title="t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.PALETTE.TITLE')"
          :search-placeholder="
            t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.PALETTE.SEARCH')
          "
          :empty-label="t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.PALETTE.EMPTY')"
          @add="addNodeFromMobilePalette"
          @drag-start="startPaletteDrag"
        />
      </div>
      <div
        class="h-full min-h-[34rem] overflow-hidden bg-n-surface-1"
        @dragover.prevent
        @drop="onCanvasDrop"
      >
        <VueFlow
          v-model:nodes="nodes"
          v-model:edges="edges"
          :node-types="nodeTypes"
          :edge-types="edgeTypes"
          :min-zoom="0.4"
          :max-zoom="1.8"
          fit-view-on-init
          @connect="onConnect"
          @node-drag-start="onNodeDragStart"
          @edge-click="onEdgeClick"
          @node-click="({ node }) => selectNode(node)"
        >
          <Background pattern-color="var(--color-n-slate-5)" :gap="16" />
          <Controls :show-interactive="false" />
          <MiniMap
            v-if="showMiniMap"
            data-testid="kanban-workflow-minimap"
            pannable
            zoomable
          />
        </VueFlow>
      </div>

      <div
        v-if="selectedNode || selectedEdge"
        data-testid="kanban-workflow-inspector-backdrop"
        class="fixed inset-0 z-40 bg-n-slate-12/10"
        @click="closeInspector"
      />
      <aside
        v-if="selectedNode || selectedEdge"
        ref="inspector"
        :data-testid="
          selectedNode
            ? 'kanban-workflow-node-drawer'
            : 'kanban-workflow-connection-dialog'
        "
        class="fixed inset-x-4 bottom-4 top-4 z-50 grid max-h-[calc(100vh-2rem)] w-auto content-start gap-4 overflow-y-auto rounded-lg border border-n-weak bg-n-surface-1 p-4 shadow-2xl outline-none sm:inset-x-auto sm:bottom-6 sm:right-6 sm:top-6 sm:w-[min(26rem,calc(100vw-3rem))] sm:p-5"
        role="dialog"
        aria-modal="true"
        :aria-labelledby="
          selectedNode
            ? 'kanban-workflow-inspector-title'
            : 'kanban-workflow-connection-title'
        "
        tabindex="-1"
        @focusin="recordInspectorState"
        @keydown="handleInspectorKeydown"
      >
        <template v-if="selectedNode">
          <div
            data-testid="kanban-workflow-inspector-header"
            class="sticky top-0 z-10 -mx-4 -mt-4 flex items-center justify-between gap-3 border-b border-n-weak bg-n-surface-1 px-4 pb-3 pt-4 sm:-mx-5 sm:-mt-5 sm:px-5 sm:pt-5"
          >
            <div class="flex min-w-0 items-center gap-2.5">
              <span
                class="flex size-9 shrink-0 items-center justify-center rounded-md bg-n-surface-2 text-n-slate-11"
              >
                <i
                  v-if="selectedNode.data.icon"
                  data-testid="kanban-workflow-inspector-icon"
                  class="size-4"
                  :class="selectedNode.data.icon"
                  aria-hidden="true"
                />
              </span>
              <div class="min-w-0">
                <p
                  data-testid="kanban-workflow-inspector-category"
                  class="m-0 truncate text-2xs font-semibold uppercase tracking-wide text-n-slate-10"
                >
                  {{ selectedNode.data.categoryLabel }}
                </p>
                <p
                  id="kanban-workflow-inspector-title"
                  class="m-0 truncate text-base font-semibold text-n-slate-12"
                >
                  {{ selectedNode.data.label }}
                </p>
                <span
                  data-testid="kanban-workflow-inspector-state"
                  class="mt-1 inline-flex rounded px-1.5 py-0.5 text-2xs font-medium"
                  :class="inspectorStateTone(selectedNode.data.state)"
                >
                  {{ selectedNode.data.stateLabel }}
                </span>
              </div>
            </div>
            <div class="flex items-center gap-1">
              <button
                v-if="!selectedNode.data.terminal"
                type="button"
                data-testid="kanban-workflow-connect-node"
                class="flex size-8 items-center justify-center rounded-md text-n-slate-10 hover:bg-n-surface-2 hover:text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand"
                :aria-label="
                  t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.CONNECT_NODE')
                "
                :title="t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.CONNECT_NODE')"
                @click="openConnectionForm"
              >
                <i class="i-lucide-link size-4" aria-hidden="true" />
              </button>
              <button
                type="button"
                class="flex size-8 items-center justify-center rounded-md text-n-slate-10 hover:bg-n-surface-2 hover:text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand"
                :aria-label="t('KANBAN.ACTIONS.CLOSE')"
                :title="t('KANBAN.ACTIONS.CLOSE')"
                @click="closeInspector"
              >
                <i class="i-lucide-x size-4" />
              </button>
              <button
                v-if="!['trigger', 'end'].includes(selectedNode.type)"
                type="button"
                class="flex size-8 items-center justify-center rounded-md text-n-ruby-11 hover:bg-n-ruby-3 focus:outline-none focus:ring-2 focus:ring-n-brand"
                :aria-label="
                  t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.DELETE_NODE')
                "
                :title="t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.DELETE_NODE')"
                @click="removeSelectedNode"
              >
                <i class="i-lucide-trash-2 size-4" />
              </button>
            </div>
          </div>

          <section
            v-if="showConnectionForm"
            data-testid="kanban-workflow-connect-form"
            class="grid gap-3 rounded-md border border-n-weak bg-n-surface-2 p-3 sm:grid-cols-[minmax(0,1fr)_minmax(0,1fr)_auto]"
          >
            <label
              v-if="selectedNodeOutputOptions.length"
              class="grid gap-1 text-xs font-medium text-n-slate-11"
            >
              {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.CONNECTION_OUTPUT') }}
              <select
                v-model="connectionSourceHandle"
                class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
              >
                <option
                  v-for="option in selectedNodeOutputOptions"
                  :key="option.value"
                  :value="option.value"
                >
                  {{ option.label }}
                </option>
              </select>
            </label>
            <label class="grid gap-1 text-xs font-medium text-n-slate-11">
              {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.CONNECTION_TARGET') }}
              <select
                v-model="connectionTargetId"
                data-testid="kanban-workflow-connect-target"
                class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
              >
                <option
                  v-for="node in availableConnectionTargets"
                  :key="node.id"
                  :value="node.id"
                >
                  {{ node.data.label }}
                </option>
              </select>
            </label>
            <p
              v-if="connectionError"
              class="m-0 text-xs text-n-ruby-11 sm:col-span-full"
              role="alert"
            >
              {{ connectionError }}
            </p>
            <div class="flex items-end">
              <button
                type="button"
                data-testid="kanban-workflow-connect-confirm"
                class="h-9 rounded-md bg-n-brand px-3 text-sm font-medium text-white hover:bg-n-brand/90 focus:outline-none focus:ring-2 focus:ring-n-brand disabled:cursor-not-allowed disabled:opacity-50"
                :disabled="!connectionTargetId"
                @click="connectSelectedNode"
              >
                {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.CONNECT_CONFIRM') }}
              </button>
            </div>
          </section>

          <div
            data-testid="kanban-workflow-inspector-tabs"
            class="grid w-full grid-cols-3 items-center gap-1 rounded-md bg-n-surface-2 p-1"
            role="tablist"
            :aria-label="
              t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.INSPECTOR.TABS_LABEL')
            "
          >
            <button
              v-for="tab in inspectorTabs"
              :key="tab"
              type="button"
              :data-testid="`kanban-workflow-inspector-tab-${tab}`"
              :data-inspector-tab="tab"
              role="tab"
              :aria-selected="inspectorTab === tab"
              :tabindex="inspectorTab === tab ? 0 : -1"
              class="flex h-8 items-center justify-center gap-1.5 rounded px-2 text-xs font-medium focus:outline-none focus:ring-2 focus:ring-n-brand"
              :class="
                inspectorTab === tab
                  ? 'bg-n-surface-1 text-n-slate-12 shadow-sm'
                  : 'text-n-slate-11 hover:text-n-slate-12'
              "
              @click="inspectorTab = tab"
              @keydown="handleInspectorTabKeydown($event, tab)"
            >
              <i
                :class="inspectorTabIcon(tab)"
                class="size-3.5 shrink-0"
                aria-hidden="true"
              />
              {{ inspectorTabLabel(tab) }}
            </button>
          </div>

          <section
            v-if="inspectorTab === 'test'"
            data-testid="kanban-workflow-inspector-test"
            class="grid gap-2 rounded-md border border-n-weak bg-n-surface-2 p-3"
          >
            <p class="m-0 text-sm font-medium text-n-slate-12">
              {{
                t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.INSPECTOR.TEST_TITLE')
              }}
            </p>
            <p class="m-0 text-sm text-n-slate-11">
              {{
                nodeSummary(selectedNode) ||
                t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.INSPECTOR.TEST_EMPTY')
              }}
            </p>
          </section>
          <section
            v-else-if="inspectorTab === 'history'"
            data-testid="kanban-workflow-inspector-history"
            class="grid gap-2 rounded-md border border-n-weak bg-n-surface-2 p-3"
          >
            <p class="m-0 text-sm font-medium text-n-slate-12">
              {{
                t(
                  'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.INSPECTOR.HISTORY_TITLE'
                )
              }}
            </p>
            <ol
              v-if="selectedNodeHistory.length"
              class="m-0 grid list-none gap-2"
            >
              <li
                v-for="(result, index) in selectedNodeHistory"
                :key="`${result.executionId}-${index}`"
                class="flex flex-wrap items-center justify-between gap-x-2 gap-y-1 rounded border border-n-weak bg-n-surface-1 px-2 py-1.5 text-xs"
              >
                <span class="font-medium text-n-slate-12">
                  {{ historyStatusLabel(result.status) }}
                </span>
                <time
                  v-if="historyTimestamp(result.executedAt)"
                  :datetime="result.executedAt"
                  class="text-n-slate-11"
                >
                  {{ historyTimestamp(result.executedAt) }}
                </time>
              </li>
            </ol>
            <p v-else class="m-0 text-sm text-n-slate-11">
              {{
                t(
                  'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.INSPECTOR.HISTORY_EMPTY'
                )
              }}
            </p>
          </section>

          <template
            v-else-if="selectedNode.type === 'trigger' && triggerOptions.length"
          >
            <label class="grid gap-1 text-xs font-medium text-n-slate-11">
              {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.EVENT') }}
              <select
                :value="triggerValue"
                data-testid="kanban-workflow-trigger-select"
                class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                @change="emit('update:triggerValue', $event.target.value)"
              >
                <option
                  v-for="option in triggerOptions"
                  :key="option.value"
                  :value="option.value"
                >
                  {{ option.label }}
                </option>
              </select>
            </label>
          </template>

          <template v-else-if="selectedNode.type === 'delay'">
            <label class="grid gap-1 text-xs font-medium text-n-slate-11">
              {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.DELAY_HOURS') }}
              <input
                v-model.number="selectedNode.data.delay_hours"
                min="1"
                type="number"
                class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                @change="updateNode"
              />
            </label>
          </template>

          <template v-else-if="selectedNode.type === 'wait_until_field'">
            <label class="grid gap-1 text-xs font-medium text-n-slate-11">
              {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.DATE_FIELD') }}
              <select
                v-model="selectedNode.data.field_key"
                class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                @change="updateNode"
              >
                <option value="">
                  {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.DATE_FIELD') }}
                </option>
                <option
                  v-for="field in dateFields"
                  :key="field.key"
                  :value="field.key"
                >
                  {{ field.label }}
                </option>
              </select>
            </label>
            <label class="grid gap-1 text-xs font-medium text-n-slate-11">
              {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.DATE_OFFSET_HOURS') }}
              <input
                v-model.number="selectedNode.data.offset_hours"
                type="number"
                class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                @change="updateNode"
              />
            </label>
            <label class="grid gap-1 text-xs font-medium text-n-slate-11">
              {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.DATE_TIMEZONE') }}
              <select
                v-model="selectedNode.data.timezone"
                class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
              >
                <option
                  v-for="timezone in quietHoursTimezoneOptions"
                  :key="timezone.value"
                  :value="timezone.value"
                >
                  {{ timezone.label }}
                </option>
              </select>
            </label>
            <label class="grid gap-1 text-xs font-medium text-n-slate-11">
              {{
                t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.DATE_FAILURE_POLICY')
              }}
              <select
                v-model="selectedNode.data.failure_mode"
                data-testid="kanban-workflow-date-failure-mode"
                class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                @change="updateNode"
              >
                <option value="stop">
                  {{
                    t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.DATE_FAILURE_STOP')
                  }}
                </option>
                <option value="route">
                  {{
                    t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.DATE_FAILURE_ROUTE')
                  }}
                </option>
              </select>
            </label>
          </template>

          <template v-else-if="selectedNode.type === 'wait_for_response'">
            <label class="grid gap-1 text-xs font-medium text-n-slate-11">
              {{ selectedWaitTimeoutLabel }}
              <input
                v-model.number="selectedNode.data.timeout_hours"
                min="1"
                type="number"
                class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                @change="updateNode"
              />
            </label>
            <label class="grid gap-1 text-xs font-medium text-n-slate-11">
              {{
                t(
                  'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.RESPONSE_TIMEOUT_POLICY'
                )
              }}
              <select
                v-model="selectedNode.data.timeout_mode"
                data-testid="kanban-workflow-response-timeout-mode"
                class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                @change="updateNode"
              >
                <option value="continue">
                  {{
                    t(
                      'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.RESPONSE_TIMEOUT_CONTINUE'
                    )
                  }}
                </option>
                <option value="route">
                  {{
                    t(
                      'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.RESPONSE_TIMEOUT_ROUTE'
                    )
                  }}
                </option>
              </select>
            </label>
          </template>

          <template v-else-if="selectedNode.type === 'wait_for_inactivity'">
            <label class="grid gap-1 text-xs font-medium text-n-slate-11">
              {{ selectedWaitTimeoutLabel }}
              <input
                v-model.number="selectedNode.data.timeout_hours"
                min="1"
                type="number"
                class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                @change="updateNode"
              />
            </label>
            <label class="grid gap-1 text-xs font-medium text-n-slate-11">
              {{
                t(
                  'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.INACTIVITY_INTERRUPTION_POLICY'
                )
              }}
              <select
                v-model="selectedNode.data.interruption_mode"
                data-testid="kanban-workflow-inactivity-interruption-mode"
                class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                @change="updateNode"
              >
                <option value="stop">
                  {{
                    t(
                      'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.INACTIVITY_INTERRUPTION_STOP'
                    )
                  }}
                </option>
                <option value="route">
                  {{
                    t(
                      'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.INACTIVITY_INTERRUPTION_ROUTE'
                    )
                  }}
                </option>
              </select>
            </label>
          </template>

          <template v-else-if="selectedNode.type === 'wait_for_business_hours'">
            <fieldset
              class="grid gap-1 border-0 p-0 text-xs font-medium text-n-slate-11"
            >
              <legend class="p-0">
                {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.BUSINESS_DAYS') }}
              </legend>
              <div class="grid grid-cols-4 gap-1">
                <label
                  v-for="day in businessDays"
                  :key="day.value"
                  class="flex items-center gap-1 rounded border border-n-weak px-2 py-1 text-xs"
                >
                  <input
                    v-model="selectedNode.data.weekdays"
                    :value="day.value"
                    type="checkbox"
                    class="size-3 rounded border-n-weak text-n-brand focus:ring-n-brand"
                    @change="updateNode"
                  />
                  {{ day.label }}
                </label>
              </div>
            </fieldset>
            <div class="grid grid-cols-2 gap-2">
              <label class="grid gap-1 text-xs font-medium text-n-slate-11">
                {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.BUSINESS_START') }}
                <input
                  v-model="selectedNode.data.start_time"
                  type="time"
                  class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                  @change="updateNode"
                />
              </label>
              <label class="grid gap-1 text-xs font-medium text-n-slate-11">
                {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.BUSINESS_END') }}
                <input
                  v-model="selectedNode.data.end_time"
                  type="time"
                  class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                  @change="updateNode"
                />
              </label>
            </div>
            <label class="grid gap-1 text-xs font-medium text-n-slate-11">
              {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.QUIET_TIMEZONE') }}
              <select
                v-model="selectedNode.data.timezone"
                class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                @change="updateNode"
              >
                <option
                  v-for="timezone in quietHoursTimezoneOptions"
                  :key="timezone.value"
                  :value="timezone.value"
                >
                  {{ timezone.label }}
                </option>
              </select>
            </label>
            <label class="grid gap-1 text-xs font-medium text-n-slate-11">
              {{
                t(
                  'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.BUSINESS_HOURS_FAILURE_POLICY'
                )
              }}
              <select
                v-model="selectedNode.data.failure_mode"
                data-testid="kanban-workflow-business-hours-failure-mode"
                class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                @change="updateNode"
              >
                <option value="stop">
                  {{
                    t(
                      'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.BUSINESS_HOURS_FAILURE_STOP'
                    )
                  }}
                </option>
                <option value="route">
                  {{
                    t(
                      'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.BUSINESS_HOURS_FAILURE_ROUTE'
                    )
                  }}
                </option>
              </select>
            </label>
          </template>

          <template v-else-if="selectedNode.type === 'condition'">
            <fieldset
              v-for="(branch, branchIndex) in selectedNode.data.branches"
              :key="branch.id"
              data-testid="kanban-workflow-condition-branch"
              class="grid gap-3 rounded-md border border-n-weak bg-n-surface-2 p-3"
              @dragover.prevent
              @drop="dropConditionBranch(branchIndex)"
            >
              <legend class="px-1 text-xs font-semibold text-n-slate-11">
                {{
                  branch.label ||
                  t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.BRANCH')
                }}
              </legend>
              <div class="grid gap-2 sm:grid-cols-[2rem_minmax(0,1fr)_4.5rem]">
                <button
                  type="button"
                  draggable="true"
                  class="hidden size-9 cursor-grab items-center justify-center rounded-md text-n-slate-10 hover:bg-n-surface-1 focus:outline-none focus:ring-2 focus:ring-n-brand active:cursor-grabbing sm:flex"
                  :aria-label="
                    t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.DRAG_BRANCH')
                  "
                  @dragstart="startConditionBranchDrag(branchIndex)"
                >
                  <i class="i-lucide-grip-vertical size-4" aria-hidden="true" />
                </button>
                <input
                  v-model="branch.label"
                  type="text"
                  :aria-label="t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.BRANCH')"
                  class="h-9 min-w-0 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm font-medium text-n-slate-12 outline-none focus:border-n-brand"
                  @change="updateNode"
                />
                <div class="flex items-center justify-end gap-1">
                  <button
                    type="button"
                    :data-testid="`kanban-workflow-move-branch-up-${branchIndex}`"
                    class="flex size-9 items-center justify-center rounded-md text-n-slate-10 hover:bg-n-surface-1 hover:text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand disabled:cursor-not-allowed disabled:opacity-40"
                    :aria-label="
                      t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.MOVE_BRANCH_UP')
                    "
                    :disabled="branchIndex === 0"
                    @click="moveConditionBranch(branchIndex, -1)"
                  >
                    <i class="i-lucide-arrow-up size-4" />
                  </button>
                  <button
                    type="button"
                    :data-testid="`kanban-workflow-move-branch-down-${branchIndex}`"
                    class="flex size-9 items-center justify-center rounded-md text-n-slate-10 hover:bg-n-surface-1 hover:text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand disabled:cursor-not-allowed disabled:opacity-40"
                    :aria-label="
                      t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.MOVE_BRANCH_DOWN')
                    "
                    :disabled="
                      branchIndex === selectedNode.data.branches.length - 1
                    "
                    @click="moveConditionBranch(branchIndex, 1)"
                  >
                    <i class="i-lucide-arrow-down size-4" />
                  </button>
                  <button
                    type="button"
                    class="flex size-9 items-center justify-center rounded-md text-n-ruby-11 hover:bg-n-ruby-3 focus:outline-none focus:ring-2 focus:ring-n-brand"
                    :aria-label="
                      t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.REMOVE_BRANCH')
                    "
                    :disabled="selectedNode.data.branches.length === 1"
                    @click="removeConditionBranch(branchIndex)"
                  >
                    <i class="i-lucide-trash-2 size-4" />
                  </button>
                </div>
              </div>
              <div
                v-for="(condition, index) in branch.conditions"
                :key="`${branch.id}-${index}`"
                data-testid="kanban-workflow-condition-row"
                class="grid gap-2 sm:grid-cols-[4.5rem_minmax(0,1fr)_10rem_minmax(0,1fr)_2rem]"
              >
                <select
                  v-if="index > 0"
                  v-model="condition.join_operator"
                  data-testid="kanban-workflow-condition-join-operator"
                  class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-2 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                  @change="updateNode"
                >
                  <option value="and">
                    {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.JOIN_AND') }}
                  </option>
                  <option value="or">
                    {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.JOIN_OR') }}
                  </option>
                </select>
                <span v-else />
                <select
                  v-model="condition.field_key"
                  class="h-9 min-w-0 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                  @change="updateNode"
                >
                  <option value="">
                    {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.SELECT_FIELD') }}
                  </option>
                  <option
                    v-for="field in conditionFieldsForWorkflow"
                    :key="field.key"
                    :value="field.key"
                  >
                    {{ field.label }}
                  </option>
                </select>
                <select
                  v-model="condition.operator"
                  class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                  @change="updateNode"
                >
                  <option
                    v-for="option in conditionOperatorOptions"
                    :key="option.value"
                    :value="option.value"
                  >
                    {{ option.label }}
                  </option>
                </select>
                <select
                  v-if="
                    conditionOptionsFor(condition).length &&
                    condition.operator !== 'exists'
                  "
                  v-model="condition.value"
                  data-testid="kanban-workflow-condition-value"
                  class="h-9 min-w-0 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                  @change="updateNode"
                >
                  <option value="">
                    {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.VALUE') }}
                  </option>
                  <option
                    v-for="option in conditionOptionsFor(condition)"
                    :key="option.value"
                    :value="option.value"
                  >
                    {{ option.label }}
                  </option>
                </select>
                <input
                  v-else-if="condition.operator !== 'exists'"
                  v-model="condition.value"
                  data-testid="kanban-workflow-condition-value"
                  type="text"
                  class="h-9 min-w-0 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                  @change="updateNode"
                />
                <span v-else />
                <button
                  type="button"
                  class="flex size-9 items-center justify-center self-end rounded-md text-n-ruby-11 hover:bg-n-ruby-3 focus:outline-none focus:ring-2 focus:ring-n-brand disabled:cursor-not-allowed disabled:opacity-40"
                  :aria-label="
                    t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.REMOVE_CONDITION')
                  "
                  :disabled="branch.conditions.length === 1"
                  @click="removeCondition(branch, index)"
                >
                  <i class="i-lucide-trash-2 size-4" />
                </button>
              </div>
              <button
                type="button"
                data-testid="kanban-workflow-add-condition"
                class="flex h-8 w-fit items-center gap-1 rounded-md border border-n-weak bg-n-surface-1 px-2 text-xs font-medium text-n-slate-12 hover:bg-n-surface-2 focus:outline-none focus:ring-2 focus:ring-n-brand"
                @click="addCondition(branch)"
              >
                <i class="i-lucide-plus size-3.5" />{{
                  t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.ADD_CONDITION')
                }}
              </button>
            </fieldset>
            <button
              type="button"
              data-testid="kanban-workflow-add-branch"
              class="flex h-8 w-fit items-center gap-1 rounded-md border border-n-weak bg-n-surface-1 px-2 text-xs font-medium text-n-slate-12 hover:bg-n-surface-2 focus:outline-none focus:ring-2 focus:ring-n-brand"
              @click="addConditionBranch"
            >
              <i class="i-lucide-plus size-3.5" />{{
                t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.ADD_BRANCH')
              }}
            </button>
          </template>

          <template v-else-if="selectedNode.type === 'filter'">
            <fieldset
              class="grid gap-3 rounded-md border border-n-weak bg-n-surface-2 p-3"
            >
              <legend class="px-1 text-xs font-semibold text-n-slate-11">
                {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODES.FILTER') }}
              </legend>
              <select
                v-model="selectedNode.data.match_mode"
                data-testid="kanban-workflow-filter-match-mode"
                class="h-9 w-full rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                @change="updateNode"
              >
                <option value="all">
                  {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.MATCH_ALL') }}
                </option>
                <option value="any">
                  {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.MATCH_ANY') }}
                </option>
              </select>
              <div
                v-for="(condition, index) in selectedNode.data.conditions"
                :key="index"
                data-testid="kanban-workflow-filter-row"
                class="grid gap-2 sm:grid-cols-[minmax(0,1fr)_10rem_minmax(0,1fr)_2rem]"
              >
                <select
                  v-model="condition.field_key"
                  class="h-9 min-w-0 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                  @change="updateNode"
                >
                  <option value="">
                    {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.SELECT_FIELD') }}
                  </option>
                  <option
                    v-for="field in conditionFieldsForWorkflow"
                    :key="field.key"
                    :value="field.key"
                  >
                    {{ field.label }}
                  </option>
                </select>
                <select
                  v-model="condition.operator"
                  class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                  @change="updateNode"
                >
                  <option
                    v-for="option in conditionOperatorOptions"
                    :key="option.value"
                    :value="option.value"
                  >
                    {{ option.label }}
                  </option>
                </select>
                <select
                  v-if="
                    conditionOptionsFor(condition).length &&
                    condition.operator !== 'exists'
                  "
                  v-model="condition.value"
                  data-testid="kanban-workflow-filter-condition-value"
                  class="h-9 min-w-0 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                  @change="updateNode"
                >
                  <option value="">
                    {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.VALUE') }}
                  </option>
                  <option
                    v-for="option in conditionOptionsFor(condition)"
                    :key="option.value"
                    :value="option.value"
                  >
                    {{ option.label }}
                  </option>
                </select>
                <input
                  v-else-if="condition.operator !== 'exists'"
                  v-model="condition.value"
                  data-testid="kanban-workflow-filter-condition-value"
                  type="text"
                  class="h-9 min-w-0 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                  @change="updateNode"
                />
                <span v-else />
                <button
                  type="button"
                  class="flex size-9 items-center justify-center self-end rounded-md text-n-ruby-11 hover:bg-n-ruby-3 focus:outline-none focus:ring-2 focus:ring-n-brand disabled:cursor-not-allowed disabled:opacity-40"
                  :aria-label="
                    t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.REMOVE_CONDITION')
                  "
                  :disabled="selectedNode.data.conditions.length === 1"
                  @click="removeCondition(selectedNode.data, index)"
                >
                  <i class="i-lucide-trash-2 size-4" />
                </button>
              </div>
              <button
                type="button"
                data-testid="kanban-workflow-add-filter-condition"
                class="flex h-8 w-fit items-center gap-1 rounded-md border border-n-weak bg-n-surface-1 px-2 text-xs font-medium text-n-slate-12 hover:bg-n-surface-2 focus:outline-none focus:ring-2 focus:ring-n-brand"
                @click="addCondition(selectedNode.data)"
              >
                <i class="i-lucide-plus size-3.5" />{{
                  t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.ADD_CONDITION')
                }}
              </button>
            </fieldset>
          </template>

          <template v-else-if="selectedNode.type === 'round_robin'">
            <div class="grid gap-2">
              <div
                v-for="(option, index) in selectedNode.data.options"
                :key="option.id"
                class="grid grid-cols-[minmax(0,1fr)_2rem] gap-2 rounded-md border border-n-weak bg-n-surface-2 p-2"
              >
                <input
                  v-model="option.label"
                  type="text"
                  class="h-9 min-w-0 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                  @change="updateNode"
                />
                <button
                  type="button"
                  class="flex size-9 items-center justify-center rounded-md text-n-ruby-11 hover:bg-n-ruby-3 focus:outline-none focus:ring-2 focus:ring-n-brand disabled:cursor-not-allowed disabled:opacity-40"
                  :aria-label="
                    t(
                      'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.ROUND_ROBIN_REMOVE_OPTION'
                    )
                  "
                  :title="
                    t(
                      'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.ROUND_ROBIN_REMOVE_OPTION'
                    )
                  "
                  :disabled="selectedNode.data.options.length <= 2"
                  @click="removeRoundRobinOption(index)"
                >
                  <i class="i-lucide-trash-2 size-4" />
                </button>
              </div>
            </div>
            <p class="m-0 text-xs text-n-slate-11">
              {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.ROUND_ROBIN_HINT') }}
            </p>
            <p class="m-0 text-xs text-n-slate-11">
              {{
                t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.ROUND_ROBIN_RESET_HINT')
              }}
            </p>
            <div>
              <button
                type="button"
                data-testid="kanban-workflow-add-round-robin-option"
                class="flex h-8 items-center gap-1 rounded-md border border-n-weak bg-n-surface-2 px-2 text-xs font-medium text-n-slate-12 hover:bg-n-surface-3 focus:outline-none focus:ring-2 focus:ring-n-brand"
                @click="addRoundRobinOption"
              >
                <i class="i-lucide-plus size-3.5" />
                {{
                  t(
                    'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.ROUND_ROBIN_ADD_OPTION'
                  )
                }}
              </button>
            </div>
          </template>

          <template v-else-if="selectedNode.type === 'send_message'">
            <label class="grid gap-1 text-xs font-medium text-n-slate-11">
              {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.CHANNEL') }}
              <select
                v-model="selectedNode.data.channel"
                class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                @change="updateNode"
              >
                <option value="whatsapp">
                  {{ t('KANBAN.SETTINGS.AUTOMATIONS.BIRTHDAY.WHATSAPP') }}
                </option>
                <option value="email">
                  {{ t('KANBAN.SETTINGS.AUTOMATIONS.BIRTHDAY.EMAIL') }}
                </option>
              </select>
            </label>
            <label class="grid gap-1 text-xs font-medium text-n-slate-11">
              {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.OPT_IN') }}
              <input
                v-model="selectedNode.data.opt_in_attribute_key"
                type="text"
                class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                @change="updateNode"
              />
            </label>
            <label class="grid gap-1 text-xs font-medium text-n-slate-11">
              {{
                t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.MESSAGE_FAILURE_POLICY')
              }}
              <select
                v-model="selectedNode.data.failure_mode"
                data-testid="kanban-workflow-message-failure-mode"
                class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                @change="updateNode"
              >
                <option value="stop">
                  {{
                    t(
                      'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.MESSAGE_FAILURE_STOP'
                    )
                  }}
                </option>
                <option value="route">
                  {{
                    t(
                      'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.MESSAGE_FAILURE_ROUTE'
                    )
                  }}
                </option>
              </select>
            </label>
            <label class="grid gap-1 text-xs font-medium text-n-slate-11">
              {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.MESSAGE') }}
              <div class="rounded-md border border-n-weak bg-n-surface-2">
                <textarea
                  ref="messageContentInput"
                  v-model="selectedNode.data.content"
                  rows="5"
                  class="block min-h-28 w-full resize-y border-0 bg-transparent px-3 py-2 text-sm text-n-slate-12 outline-none placeholder:text-n-slate-10 focus:ring-0"
                  :placeholder="
                    t(
                      'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.MESSAGE_PLACEHOLDER'
                    )
                  "
                  @change="updateNode"
                />
                <div
                  class="flex items-center gap-1 border-t border-n-weak px-2 py-1.5"
                >
                  <div
                    v-on-click-outside="() => (showEmojiPicker = false)"
                    class="relative"
                  >
                    <button
                      type="button"
                      data-testid="kanban-message-emoji-button"
                      class="flex size-8 items-center justify-center rounded-md text-n-slate-10 hover:bg-n-surface-1 hover:text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand"
                      :aria-label="
                        t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.INSERT_EMOJI')
                      "
                      :title="
                        t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.INSERT_EMOJI')
                      "
                      @click="showEmojiPicker = !showEmojiPicker"
                    >
                      <i class="i-lucide-smile size-4" />
                    </button>
                    <EmojiIconPicker
                      v-if="showEmojiPicker"
                      mode="emoji"
                      class="!bottom-full !left-0 !top-auto mb-2"
                      @select="insertMessageText($event.value)"
                    />
                  </div>
                  <div
                    v-on-click-outside="() => (showMessageVariableMenu = false)"
                    class="relative"
                  >
                    <button
                      type="button"
                      data-testid="kanban-message-variable-button"
                      class="flex size-8 items-center justify-center rounded-md text-n-slate-10 hover:bg-n-surface-1 hover:text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand"
                      :aria-label="
                        t(
                          'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.INSERT_VARIABLE'
                        )
                      "
                      :title="
                        t(
                          'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.INSERT_VARIABLE'
                        )
                      "
                      @click="
                        showMessageVariableMenu = !showMessageVariableMenu
                      "
                    >
                      <i class="i-lucide-braces size-4" />
                    </button>
                    <div
                      v-if="showMessageVariableMenu"
                      data-testid="kanban-message-variable-menu"
                      class="absolute bottom-full left-0 z-20 grid max-h-72 w-72 gap-1 overflow-y-auto rounded-md border border-n-weak bg-n-surface-1 p-1 shadow-xl"
                    >
                      <input
                        v-model="messageVariableQuery"
                        type="search"
                        class="h-8 rounded border border-n-weak bg-n-surface-2 px-2 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                        :placeholder="
                          t(
                            'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.SEARCH_VARIABLE'
                          )
                        "
                      />
                      <button
                        v-for="variable in filteredMessageVariables"
                        :key="variable.token"
                        type="button"
                        class="grid gap-0.5 rounded px-2 py-1.5 text-left hover:bg-n-surface-2 focus:outline-none focus:ring-2 focus:ring-n-brand"
                        @click="insertMessageText(variable.token)"
                      >
                        <span class="text-sm font-medium text-n-slate-12">
                          {{ variable.label }}
                        </span>
                        <span class="font-mono text-xs text-n-slate-10">
                          {{ variable.token }}
                        </span>
                      </button>
                      <p
                        v-if="!filteredMessageVariables.length"
                        class="m-0 px-2 py-3 text-xs text-n-slate-10"
                      >
                        {{
                          t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NO_VARIABLES')
                        }}
                      </p>
                    </div>
                  </div>
                  <label
                    class="flex size-8 cursor-pointer items-center justify-center rounded-md text-n-slate-10 hover:bg-n-surface-1 hover:text-n-slate-12 focus-within:ring-2 focus-within:ring-n-brand"
                    :aria-label="
                      t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.UPLOAD_IMAGE')
                    "
                    :title="
                      t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.UPLOAD_IMAGE')
                    "
                  >
                    <i class="i-lucide-image-plus size-4" />
                    <input
                      class="sr-only"
                      type="file"
                      accept="image/png,image/jpeg,image/webp,image/gif"
                      :disabled="isUploadingMessageAttachment"
                      @change="uploadMessageAttachment"
                    />
                  </label>
                  <span class="ml-auto text-xs font-normal text-n-slate-10">
                    {{
                      t(
                        'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.MESSAGE_VARIABLE_HINT'
                      )
                    }}
                  </span>
                </div>
              </div>
            </label>
            <div
              class="grid gap-2 rounded-md border border-n-weak bg-n-surface-2 p-3"
              data-testid="kanban-message-preview"
            >
              <p class="m-0 text-xs font-medium text-n-slate-11">
                {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.PREVIEW') }}
              </p>
              <img
                v-if="messageAttachmentUrl"
                :src="messageAttachmentUrl"
                :alt="
                  t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.ATTACHMENT_PREVIEW')
                "
                class="max-h-56 w-auto rounded-md object-cover"
              />
              <div
                class="max-w-[85%] rounded-lg rounded-tl-sm bg-n-brand px-3 py-2 text-sm text-white"
              >
                {{
                  messagePreview ||
                  t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.PREVIEW_EMPTY')
                }}
              </div>
              <div v-if="messageAttachmentUrl" class="flex justify-end">
                <button
                  type="button"
                  class="text-xs font-medium text-n-ruby-11 hover:underline focus:outline-none focus:ring-2 focus:ring-n-brand"
                  @click="removeMessageAttachment"
                >
                  {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.REMOVE_IMAGE') }}
                </button>
              </div>
            </div>
            <template v-if="selectedNode.data.channel === 'whatsapp'">
              <label class="grid gap-1 text-xs font-medium text-n-slate-11">
                {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.TEMPLATE_NAME') }}
                <input
                  v-model="selectedNode.data.whatsapp_template_params.name"
                  type="text"
                  class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                  @change="updateNode"
                />
              </label>
              <div class="grid grid-cols-2 gap-2">
                <label class="grid gap-1 text-xs font-medium text-n-slate-11">
                  {{
                    t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.TEMPLATE_LANGUAGE')
                  }}
                  <input
                    v-model="
                      selectedNode.data.whatsapp_template_params.language
                    "
                    type="text"
                    class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                    @change="updateNode"
                  />
                </label>
                <label class="grid gap-1 text-xs font-medium text-n-slate-11">
                  {{
                    t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.TEMPLATE_CATEGORY')
                  }}
                  <input
                    v-model="
                      selectedNode.data.whatsapp_template_params.category
                    "
                    type="text"
                    class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                    @change="updateNode"
                  />
                </label>
              </div>
              <label class="grid gap-1 text-xs font-medium text-n-slate-11">
                {{
                  t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.TEMPLATE_NAMESPACE')
                }}
                <input
                  v-model="selectedNode.data.whatsapp_template_params.namespace"
                  type="text"
                  class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                  @change="updateNode"
                />
              </label>
            </template>
            <label class="grid gap-1 text-xs font-medium text-n-slate-11">
              {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.FREQUENCY_LIMIT') }}
              <input
                v-model="selectedNode.data.frequency_limit_hours"
                type="number"
                min="1"
                max="720"
                class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                @change="updateNode"
              />
            </label>
            <div class="grid grid-cols-2 gap-2">
              <label class="grid gap-1 text-xs font-medium text-n-slate-11">
                {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.QUIET_START') }}
                <input
                  v-model="selectedNode.data.quiet_hours.start"
                  type="time"
                  class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                  @change="updateNode"
                />
              </label>
              <label class="grid gap-1 text-xs font-medium text-n-slate-11">
                {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.QUIET_END') }}
                <input
                  v-model="selectedNode.data.quiet_hours.end"
                  type="time"
                  class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                  @change="updateNode"
                />
              </label>
            </div>
            <label class="grid gap-1 text-xs font-medium text-n-slate-11">
              {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.QUIET_TIMEZONE') }}
              <select
                v-model="selectedNode.data.quiet_hours.timezone"
                class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                @change="updateNode"
              >
                <option
                  v-for="timezone in quietHoursTimezoneOptions"
                  :key="timezone.value"
                  :value="timezone.value"
                >
                  {{ timezone.label }}
                </option>
              </select>
            </label>
          </template>

          <template v-else-if="selectedNode.type === 'webhook'">
            <label class="grid gap-1 text-xs font-medium text-n-slate-11">
              {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.WEBHOOK_CONNECTION') }}
              <select
                v-model="selectedNode.data.connection_id"
                class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                @change="updateNode"
              >
                <option value="">
                  {{
                    t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.WEBHOOK_CONNECTION')
                  }}
                </option>
                <option
                  v-for="connection in connections.filter(item => item.active)"
                  :key="connection.id"
                  :value="connection.id"
                >
                  {{ connection.name }}
                </option>
              </select>
            </label>
            <label class="grid gap-1 text-xs font-medium text-n-slate-11">
              {{
                t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.WEBHOOK_FAILURE_POLICY')
              }}
              <select
                v-model="selectedNode.data.failure_mode"
                class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                @change="updateNode"
              >
                <option value="stop">
                  {{
                    t(
                      'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.WEBHOOK_FAILURE_STOP'
                    )
                  }}
                </option>
                <option value="route">
                  {{
                    t(
                      'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.WEBHOOK_FAILURE_ROUTE'
                    )
                  }}
                </option>
              </select>
            </label>
            <p class="m-0 text-xs text-n-slate-11">
              {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.WEBHOOK_HINT') }}
            </p>
          </template>

          <template v-else-if="selectedNode.type === 'end'">
            <label class="grid gap-1 text-xs font-medium text-n-slate-11">
              {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.END_OUTCOME') }}
              <select
                v-model="selectedNode.data.outcome"
                class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                @change="updateNode"
              >
                <option
                  v-for="outcome in endOutcomeOptions"
                  :key="outcome.value"
                  :value="outcome.value"
                >
                  {{ outcome.label }}
                </option>
              </select>
            </label>
          </template>

          <template v-else-if="selectedNode.type === 'human_handoff'">
            <label class="grid gap-1 text-xs font-medium text-n-slate-11">
              {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.HANDOFF_TEAM') }}
              <select
                v-model="selectedNode.data.team_id"
                data-testid="kanban-workflow-handoff-team"
                class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                @change="updateNode"
              >
                <option value="">
                  {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.SELECT_TEAM') }}
                </option>
                <option v-for="team in teams" :key="team.id" :value="team.id">
                  {{ team.name }}
                </option>
              </select>
            </label>
            <label class="grid gap-1 text-xs font-medium text-n-slate-11">
              {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.HANDOFF_AGENT') }}
              <select
                v-model="selectedNode.data.owner_id"
                data-testid="kanban-workflow-handoff-owner"
                class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                @change="updateNode"
              >
                <option value="">
                  {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.SELECT_AGENT') }}
                </option>
                <option
                  v-for="agent in agents"
                  :key="agent.id"
                  :value="agent.id"
                >
                  {{ agent.name }}
                </option>
              </select>
            </label>
            <label class="grid gap-1 text-xs font-medium text-n-slate-11">
              {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.HANDOFF_NOTE') }}
              <textarea
                v-model="selectedNode.data.note"
                rows="3"
                class="resize-y rounded-md border border-n-weak bg-n-surface-2 px-3 py-2 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                @change="updateNode"
              />
            </label>
            <p class="m-0 text-xs text-n-slate-11">
              {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.HANDOFF_HINT') }}
            </p>
          </template>

          <template v-else-if="selectedNode.type === 'audit_log'">
            <label class="grid gap-1 text-xs font-medium text-n-slate-11">
              {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.AUDIT_LOG_CONTENT') }}
              <textarea
                v-model="selectedNode.data.content"
                data-testid="kanban-workflow-audit-log-content"
                rows="3"
                class="resize-y rounded-md border border-n-weak bg-n-surface-2 px-3 py-2 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                @change="updateNode"
              />
            </label>
            <p class="m-0 text-xs text-n-slate-11">
              {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.AUDIT_LOG_HINT') }}
            </p>
          </template>

          <template v-else-if="selectedNode.type === 'message_eligibility'">
            <label class="grid gap-1 text-xs font-medium text-n-slate-11">
              {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.MESSAGE_CHANNEL') }}
              <select
                v-model="selectedNode.data.channel"
                class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                @change="updateNode"
              >
                <option value="whatsapp">
                  {{
                    t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.CHANNEL_WHATSAPP')
                  }}
                </option>
                <option value="email">
                  {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.CHANNEL_EMAIL') }}
                </option>
              </select>
            </label>
            <label class="grid gap-1 text-xs font-medium text-n-slate-11">
              {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.OPT_IN_ATTRIBUTE') }}
              <input
                v-model="selectedNode.data.opt_in_attribute_key"
                class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                @change="updateNode"
              />
            </label>
            <p class="m-0 text-xs text-n-slate-11">
              {{
                t(
                  'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.MESSAGE_ELIGIBILITY_HINT'
                )
              }}
            </p>
          </template>

          <template v-else-if="selectedNode.type === 'update_contact'">
            <label class="grid gap-1 text-xs font-medium text-n-slate-11">
              {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.CONTACT_ATTRIBUTE') }}
              <select
                :value="selectedContactAttributeOption"
                data-testid="kanban-workflow-contact-attribute-select"
                class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                @change="selectContactAttribute"
              >
                <option
                  v-for="attribute in contactAttributeOptions"
                  :key="attribute.value"
                  :value="attribute.value"
                >
                  {{ attribute.label }}
                </option>
                <option value="__custom__">
                  {{
                    t(
                      'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.CONTACT_ATTRIBUTES.CUSTOM'
                    )
                  }}
                </option>
              </select>
            </label>
            <label
              v-if="selectedContactAttributeOption === '__custom__'"
              class="grid gap-1 text-xs font-medium text-n-slate-11"
            >
              {{
                t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.CONTACT_ATTRIBUTE_KEY')
              }}
              <input
                v-model="selectedNode.data.action_params.attribute_key"
                data-testid="kanban-workflow-contact-attribute"
                class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                @change="updateNode"
              />
            </label>
            <label
              v-if="selectedContactAttributeIsBoolean"
              class="flex min-h-9 items-center gap-2 text-xs font-medium text-n-slate-11"
            >
              {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.CONTACT_VALUE') }}
              <input
                :checked="selectedContactBooleanValue"
                data-testid="kanban-workflow-contact-value-boolean"
                type="checkbox"
                class="size-4 rounded border-n-weak text-n-brand focus:ring-n-brand"
                @change="updateContactBooleanValue"
              />
              <span>
                {{
                  t(
                    'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.CONTACT_VALUE_ENABLED'
                  )
                }}
              </span>
            </label>
            <label
              v-else
              class="grid gap-1 text-xs font-medium text-n-slate-11"
            >
              {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.CONTACT_VALUE') }}
              <input
                v-model="selectedNode.data.action_params.value"
                data-testid="kanban-workflow-contact-value"
                :type="selectedContactAttributeIsDate ? 'date' : 'text'"
                class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                @change="updateNode"
              />
            </label>
            <p class="m-0 text-xs text-n-slate-11">
              {{
                t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.CONTACT_UPDATE_HINT')
              }}
            </p>
          </template>

          <template v-else-if="selectedNode.type === 'complete_next_action'">
            <p class="m-0 text-sm text-n-slate-11">
              {{
                t(
                  'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.COMPLETE_NEXT_ACTION_HINT'
                )
              }}
            </p>
            <label class="mt-3 grid gap-1 text-xs font-medium text-n-slate-11">
              {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.COMPLETION_NOTE') }}
              <textarea
                v-model="selectedNode.data.action_params.completion_note"
                data-testid="kanban-workflow-completion-note"
                rows="3"
                class="resize-y rounded-md border border-n-weak bg-n-surface-2 px-3 py-2 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                @change="updateNode"
              />
            </label>
            <label
              class="mt-3 flex items-center gap-2 text-xs font-medium text-n-slate-11"
            >
              <input
                v-model="selectedNode.data.action_params.schedule_next_action"
                data-testid="kanban-workflow-schedule-next-action"
                type="checkbox"
                class="size-4 rounded border-n-weak text-n-brand focus:ring-n-brand"
                @change="updateNode"
              />
              {{
                t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.SCHEDULE_NEXT_ACTION')
              }}
            </label>
            <div
              v-if="selectedNode.data.action_params.schedule_next_action"
              class="mt-3 grid gap-3 rounded-md border border-n-weak bg-n-surface-2 p-3"
            >
              <label class="grid gap-1 text-xs font-medium text-n-slate-11">
                {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.SELECT_NEXT_ACTION') }}
                <select
                  v-model="selectedNode.data.action_params.next_action_type"
                  data-testid="kanban-workflow-next-action-type"
                  class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                  @change="updateNode"
                >
                  <option value="">
                    {{
                      t('KANBAN.SETTINGS.AUTOMATIONS.RULES.SELECT_NEXT_ACTION')
                    }}
                  </option>
                  <option
                    v-for="type in nextActionTypes"
                    :key="type"
                    :value="type"
                  >
                    {{ type }}
                  </option>
                </select>
              </label>
              <label class="grid gap-1 text-xs font-medium text-n-slate-11">
                {{ t('KANBAN.SETTINGS.SALES.SYSTEM_FIELDS.NEXT_ACTION_AT') }}
                <input
                  v-model="selectedNode.data.action_params.next_action_at"
                  type="datetime-local"
                  class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                  @change="updateNode"
                />
              </label>
              <label class="grid gap-1 text-xs font-medium text-n-slate-11">
                {{ t('KANBAN.SETTINGS.SALES.SYSTEM_FIELDS.NEXT_ACTION_NOTE') }}
                <input
                  v-model="selectedNode.data.action_params.next_action_note"
                  type="text"
                  class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                  @change="updateNode"
                />
              </label>
            </div>
          </template>

          <template v-else-if="selectedNode.type === 'mark_won'">
            <p class="m-0 text-sm text-n-slate-11">
              {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.MARK_WON_HINT') }}
            </p>
          </template>

          <template v-else-if="selectedNode.type === 'mark_lost'">
            <label class="grid gap-1 text-xs font-medium text-n-slate-11">
              {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.LOST_REASON') }}
              <select
                v-model="selectedNode.data.action_params.lost_reason"
                data-testid="kanban-workflow-lost-reason"
                class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                @change="updateNode"
              >
                <option value="">
                  {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.LOST_REASON') }}
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
          </template>

          <template
            v-else-if="['action', 'set_field'].includes(selectedNode.type)"
          >
            <label
              v-if="selectedNode.type === 'action'"
              class="grid gap-1 text-xs font-medium text-n-slate-11"
            >
              {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.ACTION') }}
              <select
                v-model="selectedNode.data.action_name"
                class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                @change="updateNode"
              >
                <option
                  v-for="option in actionOptions"
                  :key="option.value"
                  :value="option.value"
                >
                  {{ option.label }}
                </option>
              </select>
            </label>
            <label
              v-if="selectedActionName === 'move_stage'"
              class="grid gap-1 text-xs font-medium text-n-slate-11"
            >
              {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.STAGE') }}
              <select
                v-model="selectedNode.data.action_params.stage_id"
                class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                @change="updateNode"
              >
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
              v-else-if="selectedActionName === 'assign_owner'"
              class="grid gap-1 text-xs font-medium text-n-slate-11"
            >
              {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.SELECT_OWNER') }}
              <select
                v-model="selectedNode.data.action_params.owner_id"
                class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                @change="updateNode"
              >
                <option value="">
                  {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.SELECT_OWNER') }}
                </option>
                <option
                  v-for="agent in agents"
                  :key="agent.value"
                  :value="agent.value"
                >
                  {{ agent.label }}
                </option>
              </select>
            </label>
            <label
              v-else-if="selectedActionName === 'assign_round_robin'"
              class="grid gap-1 text-xs font-medium text-n-slate-11"
            >
              {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.SELECT_OWNERS') }}
              <select
                v-model="selectedNode.data.action_params.owner_ids"
                multiple
                class="min-h-24 rounded-md border border-n-weak bg-n-surface-2 px-3 py-2 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                @change="updateNode"
              >
                <option
                  v-for="agent in agents"
                  :key="agent.value"
                  :value="agent.value"
                >
                  {{ agent.label }}
                </option>
              </select>
              <select
                v-model="selectedNode.data.action_params.availability_policy"
                data-testid="kanban-workflow-round-robin-availability"
                class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                @change="updateNode"
              >
                <option
                  v-for="policy in roundRobinAvailabilityOptions"
                  :key="policy.value"
                  :value="policy.value"
                >
                  {{ policy.label }}
                </option>
              </select>
            </label>
            <template v-else-if="selectedActionName === 'set_next_action'">
              <label class="grid gap-1 text-xs font-medium text-n-slate-11">
                {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.SELECT_NEXT_ACTION') }}
                <select
                  v-model="selectedNode.data.action_params.next_action_type"
                  class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                  @change="updateNode"
                >
                  <option value="">
                    {{
                      t('KANBAN.SETTINGS.AUTOMATIONS.RULES.SELECT_NEXT_ACTION')
                    }}
                  </option>
                  <option
                    v-for="type in nextActionTypes"
                    :key="type"
                    :value="type"
                  >
                    {{ type }}
                  </option>
                </select>
              </label>
              <label class="grid gap-1 text-xs font-medium text-n-slate-11">
                {{ t('KANBAN.SETTINGS.SALES.SYSTEM_FIELDS.NEXT_ACTION_AT') }}
                <input
                  v-model="selectedNode.data.action_params.next_action_at"
                  type="datetime-local"
                  class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                  @change="updateNode"
                />
              </label>
              <label class="grid gap-1 text-xs font-medium text-n-slate-11">
                {{ t('KANBAN.SETTINGS.SALES.SYSTEM_FIELDS.NEXT_ACTION_NOTE') }}
                <input
                  v-model="selectedNode.data.action_params.next_action_note"
                  type="text"
                  class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                  @change="updateNode"
                />
              </label>
            </template>
            <template
              v-else-if="
                ['set_field', 'increment_field', 'clear_field'].includes(
                  selectedActionName
                )
              "
            >
              <label class="grid gap-1 text-xs font-medium text-n-slate-11">
                {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.SELECT_FIELD') }}
                <select
                  v-model="selectedNode.data.action_params.field_key"
                  class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                  @change="updateNode"
                >
                  <option value="">
                    {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.SELECT_FIELD') }}
                  </option>
                  <option
                    v-for="field in selectedActionName === 'increment_field'
                      ? numericCustomFields
                      : customFields"
                    :key="field.key"
                    :value="field.key"
                  >
                    {{ field.label || field.key }}
                  </option>
                </select>
              </label>
              <label
                v-if="selectedActionName !== 'clear_field'"
                class="grid gap-1 text-xs font-medium text-n-slate-11"
              >
                {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.VALUE') }}
                <select
                  v-if="
                    selectedActionFieldOptions.length &&
                    selectedActionName === 'set_field'
                  "
                  v-model="selectedNode.data.action_params.value"
                  data-testid="kanban-workflow-action-field-value"
                  class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                  @change="updateNode"
                >
                  <option value="">
                    {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.VALUE') }}
                  </option>
                  <option
                    v-for="option in selectedActionFieldOptions"
                    :key="option"
                    :value="option"
                  >
                    {{ option }}
                  </option>
                </select>
                <input
                  v-else
                  v-model="
                    selectedNode.data.action_params[
                      selectedActionName === 'increment_field'
                        ? 'amount'
                        : 'value'
                    ]
                  "
                  :type="
                    selectedActionName === 'increment_field' ? 'number' : 'text'
                  "
                  :step="
                    selectedActionName === 'increment_field' ? 'any' : undefined
                  "
                  data-testid="kanban-workflow-action-field-value"
                  class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                  @change="updateNode"
                />
              </label>
            </template>
            <template
              v-else-if="
                ['add_label', 'remove_label'].includes(selectedActionName)
              "
            >
              <label class="grid gap-1 text-xs font-medium text-n-slate-11">
                {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.LABEL') }}
                <input
                  v-model="selectedNode.data.action_params.label"
                  type="text"
                  class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                  @change="updateNode"
                />
              </label>
            </template>
            <template v-else-if="selectedActionName === 'add_note'">
              <label class="grid gap-1 text-xs font-medium text-n-slate-11">
                {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NOTE_CONTENT') }}
                <textarea
                  v-model="selectedNode.data.action_params.content"
                  rows="3"
                  class="resize-y rounded-md border border-n-weak bg-n-surface-2 px-3 py-2 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                  @change="updateNode"
                />
              </label>
            </template>
          </template>

          <p v-else class="m-0 text-xs text-n-slate-11">
            {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODE_HINT') }}
          </p>
        </template>
        <template v-else-if="selectedEdge">
          <div
            class="flex items-center justify-between gap-3 border-b border-n-weak pb-4"
          >
            <div>
              <p class="m-0 text-xs font-medium uppercase text-n-slate-10">
                {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.CONNECTION') }}
              </p>
              <p
                id="kanban-workflow-connection-title"
                class="m-0 mt-1 text-base font-semibold text-n-slate-12"
              >
                <span data-testid="kanban-workflow-connection-summary">
                  {{ selectedEdgeSummary }}
                </span>
              </p>
            </div>
            <button
              type="button"
              class="flex size-8 items-center justify-center rounded-md text-n-slate-10 hover:bg-n-surface-2 hover:text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand"
              :aria-label="t('KANBAN.ACTIONS.CLOSE')"
              :title="t('KANBAN.ACTIONS.CLOSE')"
              @click="closeInspector"
            >
              <i class="i-lucide-x size-4" />
            </button>
          </div>
          <p class="m-0 text-sm text-n-slate-11">
            {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.CONNECTION_HINT') }}
          </p>
          <button
            type="button"
            class="flex h-9 w-fit items-center gap-2 rounded-md px-3 text-sm font-medium text-n-ruby-11 hover:bg-n-ruby-3 focus:outline-none focus:ring-2 focus:ring-n-brand"
            @click="removeSelectedEdge"
          >
            <i class="i-lucide-trash-2 size-4" />
            {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.DELETE_CONNECTION') }}
          </button>
        </template>
      </aside>
    </div>
  </section>
</template>
