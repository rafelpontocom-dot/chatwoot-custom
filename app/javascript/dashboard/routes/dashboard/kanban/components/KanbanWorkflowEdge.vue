<script setup>
import { computed } from 'vue';
import { BaseEdge, EdgeLabelRenderer, getBezierPath } from '@vue-flow/core';

const props = defineProps({
  id: { type: String, required: true },
  source: { type: String, required: true },
  target: { type: String, required: true },
  sourceHandleId: { type: String, default: null },
  sourceNode: { type: Object, default: () => ({}) },
  sourceX: { type: Number, required: true },
  sourceY: { type: Number, required: true },
  targetX: { type: Number, required: true },
  targetY: { type: Number, required: true },
  sourcePosition: { type: String, required: true },
  targetPosition: { type: String, required: true },
  markerEnd: { type: String, default: '' },
  selected: { type: Boolean, default: false },
  data: { type: Object, default: () => ({}) },
});

const edgePath = computed(() =>
  getBezierPath({
    sourceX: props.sourceX,
    sourceY: props.sourceY,
    sourcePosition: props.sourcePosition,
    targetX: props.targetX,
    targetY: props.targetY,
    targetPosition: props.targetPosition,
  })
);

const outputLabel = computed(() => {
  const data = props.sourceNode?.data || {};
  const handleId = props.sourceHandleId;
  if (!handleId) return '';

  if (data.kind === 'condition') {
    if (handleId === data.fallbackId) return data.fallbackLabel;
    return data.branches?.find(branch => branch.id === handleId)?.label || '';
  }

  if (data.kind === 'round_robin') {
    return data.options?.find(option => option.id === handleId)?.label || '';
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
    ].includes(data.kind)
  ) {
    return data.outputs?.find(output => output.id === handleId)?.label || '';
  }

  return '';
});

const insertAfter = () => {
  const handler =
    props.sourceNode?.data?.addAfterOption || props.sourceNode?.data?.addAfter;
  handler?.(props.source, props.sourceHandleId);
};

const removeEdge = () => {
  props.data.remove?.();
};
</script>

<template>
  <BaseEdge
    :id="id"
    :path="edgePath[0]"
    :marker-end="markerEnd"
    :class="
      selected || data.active
        ? 'stroke-n-brand stroke-[2.5]'
        : 'stroke-n-slate-8 stroke-[1.5] hover:stroke-n-brand'
    "
  />
  <EdgeLabelRenderer>
    <div
      :data-edge-target="target"
      class="nodrag nopan pointer-events-all absolute flex -translate-x-1/2 -translate-y-1/2 items-center gap-1 rounded bg-n-surface-1 px-1 shadow-sm"
      :style="{
        transform: `translate(-50%, -50%) translate(${edgePath[1]}px, ${edgePath[2]}px)`,
      }"
    >
      <span
        v-if="outputLabel"
        class="max-w-28 truncate text-xs text-n-slate-10"
      >
        {{ outputLabel }}
      </span>
      <button
        type="button"
        data-testid="kanban-workflow-edge-insert"
        class="flex p-0 size-6 items-center justify-center rounded border border-solid border-n-weak bg-n-surface-1 text-n-brand hover:bg-n-brand hover:text-white focus:outline-none focus:ring-2 focus:ring-n-brand"
        :aria-label="sourceNode?.data?.addAfterLabel"
        :title="sourceNode?.data?.addAfterLabel"
        @click.stop="insertAfter"
      >
        <i class="i-lucide-plus size-3" aria-hidden="true" />
      </button>
      <button
        v-if="data.remove"
        type="button"
        data-testid="kanban-workflow-edge-remove"
        class="flex p-0 size-6 items-center justify-center rounded border border-transparent text-n-slate-10 hover:border-n-ruby-6 hover:bg-n-ruby-2 hover:text-n-ruby-11 focus:outline-none focus:ring-2 focus:ring-n-brand"
        :aria-label="data.removeLabel"
        :title="data.removeLabel"
        @click.stop="removeEdge"
      >
        <i class="i-lucide-trash-2 size-3" aria-hidden="true" />
      </button>
    </div>
  </EdgeLabelRenderer>
</template>
