<script setup>
import { Handle, Position } from '@vue-flow/core';

const props = defineProps({
  data: {
    type: Object,
    required: true,
  },
});

const selectNode = event => {
  event.preventDefault();
  props.data.select?.(props.data.id);
};

const categoryTone = category =>
  ({
    TRIGGER: 'border-n-teal-5',
    TIME: 'border-n-amber-5',
    DECISION: 'border-n-violet-4',
    OPERATION: 'border-n-cyan-5',
    CUSTOMER: 'border-n-blue-5',
    OPPORTUNITY: 'border-n-iris-4',
    INTEGRATION: 'border-n-slate-7',
    CONTROL: 'border-n-green-5',
  })[category] || 'border-n-weak';

const categorySurface = category =>
  ({
    TRIGGER: 'bg-n-teal-3 text-n-teal-11',
    TIME: 'bg-n-amber-3 text-n-amber-11',
    DECISION: 'bg-n-violet-3 text-n-violet-11',
    OPERATION: 'bg-n-cyan-3 text-n-cyan-11',
    CUSTOMER: 'bg-n-blue-3 text-n-blue-11',
    OPPORTUNITY: 'bg-n-iris-3 text-n-iris-11',
    INTEGRATION: 'bg-n-slate-3 text-n-slate-11',
    CONTROL: 'bg-n-green-3 text-n-green-11',
  })[category] || 'bg-n-surface-2 text-n-slate-11';

const stateTone = state =>
  ({
    draft: 'bg-n-slate-3 text-n-slate-11',
    valid: 'bg-n-green-3 text-n-green-11',
    invalid: 'bg-n-ruby-3 text-n-ruby-11',
    waiting: 'bg-n-amber-3 text-n-amber-11',
    completed: 'bg-n-green-3 text-n-green-11',
    skipped: 'bg-n-slate-3 text-n-slate-11',
    failed: 'bg-n-ruby-3 text-n-ruby-11',
  })[state] || 'bg-n-slate-3 text-n-slate-11';
</script>

<template>
  <Handle
    v-if="data.kind !== 'trigger'"
    type="target"
    :position="Position.Left"
    class="!size-3 !border-2 !border-n-surface-1 !bg-n-slate-9"
  />
  <div
    data-testid="kanban-workflow-node-card"
    :data-category="data.category"
    :aria-label="data.label"
    role="group"
    tabindex="0"
    class="w-[9.5rem] rounded-lg border border-n-weak border-t-4 bg-n-surface-1 px-3 py-2 shadow-sm transition-[box-shadow,border-color] hover:shadow-md focus:outline-none focus:ring-2 focus:ring-n-brand"
    :class="
      data.invalid
        ? 'border-n-ruby-9 ring-2 ring-n-ruby-9/20'
        : categoryTone(data.category)
    "
    @keydown.enter="selectNode"
    @keydown.space="selectNode"
  >
    <div class="flex items-start justify-between gap-2">
      <div class="flex min-w-0 items-center gap-2">
        <span
          class="flex size-7 shrink-0 items-center justify-center rounded-md"
          :class="categorySurface(data.category)"
        >
          <i
            v-if="data.icon"
            data-testid="kanban-workflow-node-icon"
            class="size-3.5"
            :class="data.icon"
            aria-hidden="true"
          />
        </span>
        <div class="min-w-0">
          <p
            data-testid="kanban-workflow-node-category"
            class="m-0 break-words text-2xs font-semibold uppercase tracking-wide text-n-slate-10"
          >
            {{ data.categoryLabel || data.category }}
          </p>
          <p
            class="m-0 line-clamp-2 break-words text-xs font-semibold text-n-slate-12"
          >
            {{ data.label }}
          </p>
        </div>
      </div>
      <i
        v-if="data.invalid"
        class="i-lucide-circle-alert size-3.5 shrink-0 text-n-ruby-11"
        aria-hidden="true"
      />
    </div>
    <p
      v-if="data.summary"
      class="m-0 mt-1 line-clamp-2 break-words text-xs text-n-slate-10"
    >
      {{ data.summary }}
    </p>
    <span
      v-if="data.stateLabel"
      data-testid="kanban-workflow-node-state"
      class="mt-1.5 inline-flex rounded-full px-1.5 py-0.5 text-2xs font-medium"
      :class="stateTone(data.state)"
    >
      {{ data.stateLabel }}
    </span>
    <div
      v-if="data.chips?.length"
      data-testid="kanban-workflow-node-chips"
      class="mt-1.5 flex max-w-full gap-1 overflow-hidden border-t border-n-weak pt-1.5"
    >
      <span
        v-for="chip in data.chips"
        :key="chip"
        data-testid="kanban-workflow-node-chip"
        class="max-w-full shrink-0 truncate rounded bg-n-surface-2 px-1.5 py-0.5 text-2xs text-n-slate-11"
      >
        {{ chip }}
      </span>
    </div>
  </div>
  <template v-if="data.kind === 'condition'">
    <div
      v-for="branch in data.branches"
      :key="branch.id"
      class="nodrag nopan relative -mt-px flex w-[9.5rem] items-center gap-2 border border-n-weak bg-n-surface-1 px-3 py-1.5 text-xs text-n-slate-11 first:mt-1"
    >
      <span class="min-w-0 flex-1 break-words">{{ branch.label }}</span>
      <button
        type="button"
        class="flex p-0 size-5 items-center justify-center rounded text-n-brand hover:bg-n-surface-2 focus:outline-none focus:ring-2 focus:ring-n-brand"
        :aria-label="data.addAfterLabel"
        @click.stop="data.addAfterOption(data.id, branch.id)"
      >
        <i class="i-lucide-plus size-3" />
      </button>
      <Handle
        :id="branch.id"
        type="source"
        :position="Position.Right"
        class="!static !size-3 !border-2 !border-n-surface-1 !bg-n-brand"
      />
    </div>
    <div
      class="nodrag nopan relative -mt-px flex w-[9.5rem] items-center gap-2 border border-n-weak bg-n-surface-2 px-3 py-1.5 text-xs font-medium text-n-slate-11"
    >
      <span class="min-w-0 flex-1 break-words">{{ data.fallbackLabel }}</span>
      <button
        type="button"
        class="flex p-0 size-5 items-center justify-center rounded text-n-brand hover:bg-n-surface-1 focus:outline-none focus:ring-2 focus:ring-n-brand"
        :aria-label="data.addAfterLabel"
        @click.stop="data.addAfterOption(data.id, data.fallbackId)"
      >
        <i class="i-lucide-plus size-3" />
      </button>
      <Handle
        :id="data.fallbackId"
        type="source"
        :position="Position.Right"
        class="!static !size-3 !border-2 !border-n-surface-1 !bg-n-ruby-9"
      />
    </div>
  </template>
  <template v-else-if="data.kind === 'round_robin'">
    <div
      v-for="option in data.options"
      :key="option.id"
      class="nodrag nopan relative -mt-px flex w-[9.5rem] items-center gap-2 border border-n-weak bg-n-surface-1 px-3 py-1.5 text-xs text-n-slate-11 first:mt-1"
    >
      <span class="min-w-0 flex-1 truncate">{{ option.label }}</span>
      <button
        type="button"
        class="flex p-0 size-5 items-center justify-center rounded text-n-brand hover:bg-n-surface-2 focus:outline-none focus:ring-2 focus:ring-n-brand"
        :aria-label="data.addAfterLabel"
        @click.stop="data.addAfterOption(data.id, option.id)"
      >
        <i class="i-lucide-plus size-3" />
      </button>
      <Handle
        :id="option.id"
        type="source"
        :position="Position.Right"
        class="!static !size-3 !border-2 !border-n-surface-1 !bg-n-brand"
      />
    </div>
  </template>
  <template
    v-else-if="
      [
        'message_eligibility',
        'duplicate_check',
        'send_message',
        'wait_until_field',
        'wait_for_response',
        'wait_for_inactivity',
        'wait_for_business_hours',
        'webhook',
      ].includes(data.kind) && data.outputs
    "
  >
    <div
      v-for="output in data.outputs"
      :key="output.id"
      class="nodrag nopan relative -mt-px flex w-[9.5rem] items-center gap-2 border border-n-weak bg-n-surface-1 px-3 py-1.5 text-xs text-n-slate-11 first:mt-1"
    >
      <span class="min-w-0 flex-1 truncate">{{ output.label }}</span>
      <button
        type="button"
        class="flex p-0 size-5 items-center justify-center rounded text-n-brand hover:bg-n-surface-2 focus:outline-none focus:ring-2 focus:ring-n-brand"
        :aria-label="data.addAfterLabel"
        @click.stop="data.addAfterOption(data.id, output.id)"
      >
        <i class="i-lucide-plus size-3" />
      </button>
      <Handle
        :id="output.id"
        type="source"
        :position="Position.Right"
        class="!static !size-3 !border-2 !border-n-surface-1 !bg-n-brand"
      />
    </div>
  </template>
  <button
    v-else-if="data.canAddAfter"
    type="button"
    class="nodrag nopan absolute -right-3 top-full z-10 flex p-0 size-6 -translate-y-1/2 items-center justify-center rounded-full border border-solid border-n-brand bg-n-surface-1 text-n-brand shadow-sm hover:bg-n-brand hover:text-white focus:outline-none focus:ring-2 focus:ring-n-brand"
    :aria-label="data.addAfterLabel"
    @click.stop="data.addAfter(data.id)"
  >
    <i class="i-lucide-plus size-3" />
  </button>
  <Handle
    v-if="
      !data.terminal &&
      data.kind !== 'end' &&
      ![
        'condition',
        'duplicate_check',
        'round_robin',
        'message_eligibility',
        'send_message',
        'wait_for_response',
        'wait_for_inactivity',
        'wait_for_business_hours',
        'webhook',
      ].includes(data.kind) &&
      !(data.kind === 'wait_until_field' && data.outputs)
    "
    type="source"
    :position="Position.Right"
    class="!size-3 !border-2 !border-n-surface-1 !bg-n-brand"
  />
</template>
