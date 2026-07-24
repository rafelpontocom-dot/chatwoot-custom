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
import { addEdge, VueFlow } from '@vue-flow/core';
import { vOnClickOutside } from '@vueuse/components';
import { DirectUpload } from 'activestorage';
import '@vue-flow/controls/dist/style.css';
import '@vue-flow/core/dist/style.css';
import { useI18n } from 'vue-i18n';

import KanbanWorkflowNode from './KanbanWorkflowNode.vue';

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
  customFields: {
    type: Array,
    default: () => [],
  },
  nextActionTypes: {
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
});

const emit = defineEmits([
  'update:modelValue',
  'update:triggerValue',
  'clearValidation',
]);
const { t } = useI18n();
const nodes = ref([]);
const edges = ref([]);
const selectedNodeId = ref(null);
const selectedEdgeId = ref(null);
const showNodeMenu = ref(false);
const insertAfterNodeId = ref(null);
const inspector = ref(null);
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
  wait_for_business_hours: markRaw(KanbanWorkflowNode),
  send_message: markRaw(KanbanWorkflowNode),
  action: markRaw(KanbanWorkflowNode),
  set_field: markRaw(KanbanWorkflowNode),
  condition: markRaw(KanbanWorkflowNode),
  webhook: markRaw(KanbanWorkflowNode),
  end: markRaw(KanbanWorkflowNode),
};

const nodeLabels = computed(() => ({
  trigger: t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODES.TRIGGER'),
  delay: t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODES.DELAY'),
  wait_until_field: t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODES.DATE_WAIT'),
  wait_for_response: t(
    'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODES.RESPONSE_WAIT'
  ),
  wait_for_business_hours: t(
    'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODES.BUSINESS_HOURS'
  ),
  send_message: t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODES.MESSAGE'),
  action: t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODES.ACTION'),
  set_field: t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODES.SET_FIELD'),
  condition: t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODES.CONDITION'),
  webhook: t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODES.WEBHOOK'),
  end: t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODES.END'),
}));

const addableNodeTypes = computed(() => [
  'delay',
  'wait_until_field',
  'wait_for_response',
  'wait_for_business_hours',
  'condition',
  'send_message',
  'action',
  'set_field',
  'webhook',
]);

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

const selectedNode = computed(() =>
  nodes.value.find(node => node.id === selectedNodeId.value)
);
const selectedEdge = computed(() =>
  edges.value.find(edge => edge.id === selectedEdgeId.value)
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
const conditionOptionsFor = condition =>
  props.conditionFields.find(field => field.key === condition.field_key)
    ?.conditionOptions || [];
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
  if (type === 'wait_until_field') return { field_key: '', offset_hours: -24 };
  if (type === 'wait_for_response') return { timeout_hours: 24 };
  if (type === 'wait_for_business_hours') {
    return {
      weekdays: [1, 2, 3, 4, 5],
      start_time: '09:00',
      end_time: '18:00',
      timezone: 'America/Sao_Paulo',
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
    };
  }
  if (type === 'action') {
    return {
      action_name: 'set_next_action',
      action_params: { next_action_type: '', next_action_note: '' },
    };
  }
  if (type === 'set_field') {
    return { action_params: { field_key: '', value: '' } };
  }
  if (type === 'condition') {
    return {
      match_mode: 'all',
      conditions: [{ field_key: '', operator: 'equals', value: '' }],
    };
  }
  if (type === 'webhook') return { connection_id: '' };
  return {};
};

const nodeSummary = node => {
  const data = node.data || {};
  if (node.type === 'delay')
    return t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.HOURS', {
      hours: data.delay_hours || 0,
    });
  if (node.type === 'wait_until_field') {
    const field = props.dateFields.find(item => item.key === data.field_key);
    return field
      ? t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.DATE_OFFSET', {
          field: field.label,
          hours: data.offset_hours || 0,
        })
      : '';
  }
  if (node.type === 'wait_for_response') {
    return t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.RESPONSE_TIMEOUT', {
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
  if (node.type === 'condition') {
    const fieldKey = data.conditions?.[0]?.field_key || data.field_key;
    return props.conditionFields.find(field => field.key === fieldKey)?.label;
  }
  if (node.type === 'webhook') {
    return props.connections.find(
      item => item.id === Number(data.connection_id)
    )?.name;
  }
  return '';
};

function openNodeMenuAfter(nodeId) {
  insertAfterNodeId.value = nodeId;
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

function insertNodeAfter(node) {
  const sourceId = insertAfterNodeId.value;
  if (!sourceId) return;

  const outgoing = edges.value.filter(
    edge => edge.source === sourceId && !edge.sourceHandle
  );
  const sourceEdge = outgoing[0];
  if (!sourceEdge) return;

  edges.value = [
    ...edges.value.filter(edge => edge.id !== sourceEdge.id),
    { id: `${sourceId}-${node.id}`, source: sourceId, target: node.id },
    {
      id: `${node.id}-${sourceEdge.target}`,
      source: node.id,
      target: sourceEdge.target,
    },
  ];
}

const decorateNode = node => {
  const data = {
    ...defaultData(node.type),
    ...(node.data || {}),
  };
  if (node.type === 'condition' && !Array.isArray(node.data?.conditions)) {
    data.conditions = [
      {
        field_key: node.data?.field_key || '',
        operator: node.data?.operator || 'equals',
        value: node.data?.value || '',
      },
    ];
  }

  return {
    ...node,
    data: {
      ...data,
      kind: node.type,
      label: nodeLabels.value[node.type] || node.type,
      summary: nodeSummary({ ...node, data }),
      invalid: props.invalidNodeIds.includes(node.id),
      yesLabel: t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.YES'),
      noLabel: t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NO'),
      canAddAfter: !['condition', 'end'].includes(node.type),
      addAfterLabel: t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.ADD_AFTER'),
      addAfter: openNodeMenuAfter,
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
  edges.value = source.edges || [];
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
          'label',
          'summary',
          'yesLabel',
          'noLabel',
          'canAddAfter',
          'addAfterLabel',
          'addAfter',
          'invalid',
        ].includes(key)
    )
  );
  const quietHours = persisted.quiet_hours || {};

  if (!quietHours.start && !quietHours.end) delete persisted.quiet_hours;

  return persisted;
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
watch([nodes, edges], emitFlow, { deep: true });

const addNodeOfType = type => {
  const id = `${type}-${Date.now()}`;
  const node = decorateNode({
    id,
    type,
    position: nodePosition(type),
    data: defaultData(type),
  });
  nodes.value.push(node);
  insertNodeAfter(node);
  selectedNodeId.value = id;
  showNodeMenu.value = false;
  insertAfterNodeId.value = null;
};

const onConnect = connection => {
  edges.value = addEdge(
    {
      ...connection,
      id: `${connection.source}-${connection.sourceHandle || 'default'}-${connection.target}`,
    },
    edges.value
  );
};

const onEdgeClick = ({ edge }) => {
  selectedNodeId.value = null;
  selectedEdgeId.value = edge.id;
  nextTick(() => inspector.value?.focus());
};

const selectNode = node => {
  selectedNodeId.value = node.id;
  selectedEdgeId.value = null;
  nextTick(() => inspector.value?.focus());
};

const closeInspector = () => {
  selectedNodeId.value = null;
  selectedEdgeId.value = null;
  showEmojiPicker.value = false;
  showMessageVariableMenu.value = false;
  messageVariableQuery.value = '';
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
  edges.value = edges.value.filter(edge => edge.id !== selectedEdgeId.value);
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

const addCondition = () => {
  if (selectedNode.value?.type !== 'condition') return;

  selectedNode.value.data.conditions.push({
    field_key: '',
    operator: 'equals',
    value: '',
  });
  updateNode();
};

const removeCondition = index => {
  if (
    selectedNode.value?.type !== 'condition' ||
    selectedNode.value.data.conditions.length === 1
  ) {
    return;
  }

  selectedNode.value.data.conditions.splice(index, 1);
  updateNode();
};

const removeSelectedNode = () => {
  const node = selectedNode.value;
  if (!node || ['trigger', 'end'].includes(node.type)) return;
  nodes.value = nodes.value.filter(item => item.id !== node.id);
  edges.value = edges.value.filter(
    edge => edge.source !== node.id && edge.target !== node.id
  );
  closeInspector();
};
</script>

<template>
  <section
    data-testid="kanban-workflow-builder"
    class="relative flex h-full min-h-[34rem] min-w-0 flex-1 flex-col overflow-hidden rounded-md border border-n-weak bg-n-surface-2"
  >
    <div
      data-testid="kanban-workflow-canvas"
      class="relative h-full min-h-[34rem] flex-1"
    >
      <div class="absolute right-3 top-3 z-20">
        <button
          type="button"
          data-testid="kanban-workflow-add-node"
          class="flex size-8 items-center justify-center rounded-md bg-n-brand text-white hover:bg-n-brand/90 focus:outline-none focus:ring-2 focus:ring-n-brand"
          :aria-label="t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.ADD_NODE')"
          :aria-expanded="showNodeMenu"
          @click="showNodeMenu = !showNodeMenu"
        >
          <i class="i-lucide-plus size-4" />
        </button>
        <div
          v-if="showNodeMenu"
          data-testid="kanban-workflow-node-menu"
          class="absolute right-0 top-10 grid min-w-48 gap-1 rounded-md border border-n-weak bg-n-surface-1 p-1 shadow-lg"
        >
          <button
            v-for="type in addableNodeTypes"
            :key="type"
            type="button"
            class="flex h-9 items-center rounded px-2 text-left text-sm font-medium text-n-slate-12 hover:bg-n-surface-2 focus:outline-none focus:ring-2 focus:ring-n-brand"
            @click="addNodeOfType(type)"
          >
            {{ nodeLabels[type] }}
          </button>
        </div>
      </div>
      <div
        class="h-full min-h-[34rem] overflow-hidden bg-n-surface-1"
        :aria-label="t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.CANVAS_LABEL')"
      >
        <VueFlow
          v-model:nodes="nodes"
          v-model:edges="edges"
          :node-types="nodeTypes"
          :min-zoom="0.4"
          :max-zoom="1.8"
          fit-view-on-init
          @connect="onConnect"
          @edge-click="onEdgeClick"
          @node-click="({ node }) => selectNode(node)"
        >
          <Background pattern-color="var(--color-n-slate-5)" :gap="16" />
          <Controls :show-interactive="false" />
        </VueFlow>
      </div>

      <div
        v-if="selectedNode || selectedEdge"
        class="fixed inset-0 z-40 bg-n-slate-12/30 backdrop-blur-[1px]"
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
        class="fixed inset-x-4 top-1/2 z-50 grid max-h-[calc(100vh-2rem)] w-auto max-w-3xl -translate-y-1/2 content-start gap-4 overflow-y-auto rounded-lg border border-n-weak bg-n-surface-1 p-5 shadow-2xl outline-none sm:inset-x-auto sm:right-1/2 sm:w-[min(46rem,calc(100vw-2rem))] sm:translate-x-1/2"
        role="dialog"
        aria-modal="true"
        tabindex="-1"
        @keydown="handleInspectorKeydown"
      >
        <template v-if="selectedNode">
          <div
            class="flex items-center justify-between gap-3 border-b border-n-weak pb-4"
          >
            <div class="min-w-0">
              <p class="m-0 text-xs font-medium uppercase text-n-slate-10">
                {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODE_SETTINGS') }}
              </p>
              <p
                class="m-0 mt-1 truncate text-base font-semibold text-n-slate-12"
              >
                {{ selectedNode.data.label }}
              </p>
            </div>
            <div class="flex items-center gap-1">
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

          <template
            v-if="selectedNode.type === 'trigger' && triggerOptions.length"
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
          </template>

          <template v-else-if="selectedNode.type === 'wait_for_response'">
            <label class="grid gap-1 text-xs font-medium text-n-slate-11">
              {{
                t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.RESPONSE_TIMEOUT_HOURS')
              }}
              <input
                v-model.number="selectedNode.data.timeout_hours"
                min="1"
                type="number"
                class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                @change="updateNode"
              />
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
          </template>

          <template v-else-if="selectedNode.type === 'condition'">
            <label class="grid gap-1 text-xs font-medium text-n-slate-11">
              {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.OPERATOR') }}
              <select
                v-model="selectedNode.data.match_mode"
                data-testid="kanban-workflow-condition-match-mode"
                class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                @change="updateNode"
              >
                <option value="all">
                  {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.MATCH_ALL') }}
                </option>
                <option value="any">
                  {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.MATCH_ANY') }}
                </option>
              </select>
            </label>
            <div
              v-for="(condition, index) in selectedNode.data.conditions"
              :key="`${index}-${condition.field_key}`"
              data-testid="kanban-workflow-condition-row"
              class="grid gap-2 rounded-md border border-n-weak bg-n-surface-2 p-3 sm:grid-cols-[minmax(0,1fr)_10rem_minmax(0,1fr)_2rem]"
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
                  v-for="field in conditionFields"
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
                :title="
                  t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.REMOVE_CONDITION')
                "
                :disabled="selectedNode.data.conditions.length === 1"
                @click="removeCondition(index)"
              >
                <i class="i-lucide-trash-2 size-4" />
              </button>
            </div>
            <div>
              <button
                type="button"
                data-testid="kanban-workflow-add-condition"
                class="flex h-8 items-center gap-1 rounded-md border border-n-weak bg-n-surface-1 px-2 text-xs font-medium text-n-slate-12 hover:bg-n-surface-2 focus:outline-none focus:ring-2 focus:ring-n-brand"
                @click="addCondition"
              >
                <i class="i-lucide-plus size-3.5" />
                {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.ADD_CONDITION') }}
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
            <p class="m-0 text-xs text-n-slate-11">
              {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.WEBHOOK_HINT') }}
            </p>
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
                ['set_field', 'increment_field'].includes(selectedActionName)
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
              <label class="grid gap-1 text-xs font-medium text-n-slate-11">
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
              <p class="m-0 mt-1 text-base font-semibold text-n-slate-12">
                {{
                  t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.CONNECTION_SELECTED')
                }}
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
