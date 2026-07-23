<script setup>
import { computed, markRaw, ref, watch } from 'vue';
import { Background } from '@vue-flow/background';
import { Controls } from '@vue-flow/controls';
import { addEdge, VueFlow } from '@vue-flow/core';
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
});

const emit = defineEmits(['update:modelValue']);
const { t } = useI18n();
const nodes = ref([]);
const edges = ref([]);
const selectedNodeId = ref(null);
const nodeTypes = {
  trigger: markRaw(KanbanWorkflowNode),
  delay: markRaw(KanbanWorkflowNode),
  wait_until_field: markRaw(KanbanWorkflowNode),
  send_message: markRaw(KanbanWorkflowNode),
  action: markRaw(KanbanWorkflowNode),
  condition: markRaw(KanbanWorkflowNode),
  end: markRaw(KanbanWorkflowNode),
};

const nodeLabels = computed(() => ({
  trigger: t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODES.TRIGGER'),
  delay: t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODES.DELAY'),
  wait_until_field: t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODES.DATE_WAIT'),
  send_message: t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODES.MESSAGE'),
  action: t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODES.ACTION'),
  condition: t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODES.CONDITION'),
  end: t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODES.END'),
}));

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

const selectedNode = computed(() =>
  nodes.value.find(node => node.id === selectedNodeId.value)
);
const selectedConditionField = computed(() =>
  props.conditionFields.find(
    field => field.key === selectedNode.value?.data?.field_key
  )
);
const selectedConditionOptions = computed(
  () => selectedConditionField.value?.conditionOptions || []
);

const defaultData = type => {
  if (type === 'delay') return { delay_hours: 24 };
  if (type === 'wait_until_field') return { field_key: '', offset_hours: -24 };
  if (type === 'send_message') {
    return {
      channel: 'whatsapp',
      opt_in_attribute_key: 'marketing_messages_opt_in',
      content: '',
    };
  }
  if (type === 'action') {
    return {
      action_name: 'set_next_action',
      action_params: { next_action_type: '', next_action_note: '' },
    };
  }
  if (type === 'condition') {
    return { field_key: '', operator: 'equals', value: '' };
  }
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
  if (node.type === 'condition') {
    return props.conditionFields.find(field => field.key === data.field_key)
      ?.label;
  }
  return '';
};

const decorateNode = node => ({
  ...node,
  data: {
    ...defaultData(node.type),
    ...(node.data || {}),
    kind: node.type,
    label: nodeLabels.value[node.type] || node.type,
    summary: nodeSummary(node),
    yesLabel: t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.YES'),
    noLabel: t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NO'),
  },
});

const defaultFlow = () => ({
  nodes: [
    { id: 'trigger', type: 'trigger', position: { x: 32, y: 180 }, data: {} },
    {
      id: 'message',
      type: 'send_message',
      position: { x: 300, y: 180 },
      data: defaultData('send_message'),
    },
    { id: 'end', type: 'end', position: { x: 568, y: 180 }, data: {} },
  ],
  edges: [
    { id: 'trigger-message', source: 'trigger', target: 'message' },
    { id: 'message-end', source: 'message', target: 'end' },
  ],
});

const applyFlow = flow => {
  const source = flow?.nodes?.length ? flow : defaultFlow();
  nodes.value = source.nodes.map(decorateNode);
  edges.value = source.edges || [];
  selectedNodeId.value = nodes.value[0]?.id || null;
};

const emitFlow = () => {
  const flow = {
    nodes: nodes.value.map(({ id, type, position, data }) => ({
      id,
      type,
      position,
      data: Object.fromEntries(
        Object.entries(data).filter(
          ([key]) =>
            !['kind', 'label', 'summary', 'yesLabel', 'noLabel'].includes(key)
        )
      ),
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
watch([nodes, edges], emitFlow, { deep: true });

const addNodeOfType = type => {
  const id = `${type}-${Date.now()}`;
  const node = decorateNode({
    id,
    type,
    position: {
      x: 220 + nodes.value.length * 36,
      y: 80 + nodes.value.length * 28,
    },
    data: defaultData(type),
  });
  nodes.value.push(node);
  selectedNodeId.value = id;
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

const updateNode = () => {
  const node = selectedNode.value;
  if (!node) return;

  node.data = decorateNode(node).data;
};

const removeSelectedNode = () => {
  const node = selectedNode.value;
  if (!node || ['trigger', 'end'].includes(node.type)) return;
  nodes.value = nodes.value.filter(item => item.id !== node.id);
  edges.value = edges.value.filter(
    edge => edge.source !== node.id && edge.target !== node.id
  );
  selectedNodeId.value = nodes.value[0]?.id || null;
};
</script>

<template>
  <section
    data-testid="kanban-workflow-builder"
    class="grid gap-3 rounded-md border border-n-weak bg-n-surface-2 p-3"
  >
    <div class="flex flex-wrap items-center justify-between gap-2">
      <div>
        <h4 class="m-0 text-sm font-medium text-n-slate-12">
          {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.TITLE') }}
        </h4>
        <p class="m-0 mt-1 text-xs text-n-slate-11">
          {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.DESCRIPTION') }}
        </p>
      </div>
      <div class="flex flex-wrap gap-2">
        <button
          v-for="type in [
            'delay',
            'wait_until_field',
            'condition',
            'send_message',
            'action',
          ]"
          :key="type"
          type="button"
          class="h-8 rounded-md border border-n-weak bg-n-surface-1 px-3 text-xs font-medium text-n-slate-12 hover:bg-n-surface-2 focus:outline-none focus:ring-2 focus:ring-n-brand"
          @click="addNodeOfType(type)"
        >
          {{
            t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.ADD', {
              node: nodeLabels[type],
            })
          }}
        </button>
      </div>
    </div>

    <div class="grid min-h-[30rem] gap-3 lg:grid-cols-[minmax(0,1fr)_18rem]">
      <div
        class="min-h-96 overflow-hidden rounded-md border border-n-weak bg-n-surface-1"
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
          @node-click="({ node }) => (selectedNodeId = node.id)"
        >
          <Background pattern-color="var(--color-n-slate-5)" :gap="16" />
          <Controls :show-interactive="false" />
        </VueFlow>
      </div>

      <aside
        class="grid content-start gap-3 rounded-md border border-n-weak bg-n-surface-1 p-3"
      >
        <template v-if="selectedNode">
          <div class="flex items-center justify-between gap-2">
            <p class="m-0 text-sm font-medium text-n-slate-12">
              {{ selectedNode.data.label }}
            </p>
            <button
              v-if="!['trigger', 'end'].includes(selectedNode.type)"
              type="button"
              class="text-xs font-medium text-n-ruby-11 focus:outline-none focus:ring-2 focus:ring-n-brand"
              @click="removeSelectedNode"
            >
              {{ t('KANBAN.ACTIONS.DELETE') }}
            </button>
          </div>

          <template v-if="selectedNode.type === 'delay'">
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

          <template v-else-if="selectedNode.type === 'condition'">
            <label class="grid gap-1 text-xs font-medium text-n-slate-11">
              {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.SELECT_FIELD') }}
              <select
                v-model="selectedNode.data.field_key"
                class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
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
            </label>
            <label class="grid gap-1 text-xs font-medium text-n-slate-11">
              {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.OPERATOR') }}
              <select
                v-model="selectedNode.data.operator"
                class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
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
            </label>
            <label
              v-if="selectedNode.data.operator !== 'exists'"
              class="grid gap-1 text-xs font-medium text-n-slate-11"
            >
              {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.VALUE') }}
              <select
                v-if="selectedConditionOptions.length"
                v-model="selectedNode.data.value"
                class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                @change="updateNode"
              >
                <option value="">
                  {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.VALUE') }}
                </option>
                <option
                  v-for="option in selectedConditionOptions"
                  :key="option.value"
                  :value="option.value"
                >
                  {{ option.label }}
                </option>
              </select>
              <input
                v-else
                v-model="selectedNode.data.value"
                type="text"
                class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                @change="updateNode"
              />
            </label>
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
              <textarea
                v-model="selectedNode.data.content"
                rows="4"
                class="resize-y rounded-md border border-n-weak bg-n-surface-2 px-3 py-2 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                @change="updateNode"
              />
            </label>
          </template>

          <template v-else-if="selectedNode.type === 'action'">
            <label class="grid gap-1 text-xs font-medium text-n-slate-11">
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
              v-if="selectedNode.data.action_name === 'move_stage'"
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
              v-else-if="selectedNode.data.action_name === 'assign_owner'"
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
            <template
              v-else-if="selectedNode.data.action_name === 'set_next_action'"
            >
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
            <template v-else-if="selectedNode.data.action_name === 'set_field'">
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
                    v-for="field in customFields"
                    :key="field.key"
                    :value="field.key"
                  >
                    {{ field.label || field.key }}
                  </option>
                </select>
              </label>
              <label class="grid gap-1 text-xs font-medium text-n-slate-11">
                {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.VALUE') }}
                <input
                  v-model="selectedNode.data.action_params.value"
                  type="text"
                  class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                  @change="updateNode"
                />
              </label>
            </template>
          </template>

          <p v-else class="m-0 text-xs text-n-slate-11">
            {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODE_HINT') }}
          </p>
        </template>
      </aside>
    </div>
  </section>
</template>
