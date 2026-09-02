<script setup>
import { computed } from 'vue';

const props = defineProps({
  node: { type: Object, required: true },
  fields: { type: Array, default: () => [] },
  operators: { type: Array, default: () => [] },
  optionsFor: { type: Function, required: true },
  t: { type: Function, required: true },
});

const emit = defineEmits([
  'update',
  'add-condition',
  'remove-condition',
  'add-branch',
  'remove-branch',
  'move-branch',
  'drag-start-branch',
  'drop-branch',
]);

const data = computed(() => props.node.data);
const isRouter = () => props.node.type === 'condition';
const nodeLabel = computed(() =>
  isRouter()
    ? props.t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODES.CONDITION')
    : props.t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODES.FILTER')
);
const nodeHint = computed(() =>
  isRouter()
    ? props.t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.CONDITION_HINT')
    : props.t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.FILTER_HINT')
);
</script>

<template>
  <section class="grid gap-3">
    <div class="rounded-lg border border-n-weak bg-n-surface-2 p-3">
      <p class="m-0 text-sm font-semibold text-n-slate-12">
        {{ nodeLabel }}
      </p>
      <p class="m-0 mt-1 text-xs text-n-slate-11">
        {{ nodeHint }}
      </p>
    </div>

    <template v-if="isRouter()">
      <fieldset
        v-for="(branch, branchIndex) in data.branches"
        :key="branch.id"
        data-testid="kanban-workflow-condition-branch"
        class="grid gap-3 rounded-lg border border-n-weak bg-n-surface-2 p-3"
        @dragover.prevent
        @drop="emit('drop-branch', branchIndex)"
      >
        <legend class="px-1 text-xs font-semibold text-n-slate-11">
          {{ branch.label || t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.BRANCH') }}
        </legend>
        <div class="grid gap-2 sm:grid-cols-[2rem_minmax(0,1fr)_4.5rem]">
          <button
            type="button"
            draggable="true"
            class="hidden p-0 size-9 cursor-grab items-center justify-center rounded-md text-n-slate-10 hover:bg-n-surface-1 focus:outline-none focus:ring-2 focus:ring-n-brand active:cursor-grabbing sm:flex"
            :aria-label="t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.DRAG_BRANCH')"
            @dragstart="emit('drag-start-branch', branchIndex)"
          >
            <i class="i-lucide-grip-vertical size-4" aria-hidden="true" />
          </button>
          <input
            v-model="branch.label"
            type="text"
            :aria-label="t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.BRANCH')"
            class="h-9 min-w-0 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm font-medium text-n-slate-12 outline-none focus:border-n-brand"
            @change="emit('update')"
          />
          <div class="flex items-center justify-end gap-1">
            <button
              type="button"
              :data-testid="`kanban-workflow-move-branch-up-${branchIndex}`"
              class="flex p-0 size-9 items-center justify-center rounded-md text-n-slate-10 hover:bg-n-surface-1 hover:text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand disabled:cursor-not-allowed disabled:opacity-40"
              :aria-label="
                t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.MOVE_BRANCH_UP')
              "
              :disabled="branchIndex === 0"
              @click="emit('move-branch', branchIndex, -1)"
            >
              <i class="i-lucide-arrow-up size-4" aria-hidden="true" />
            </button>
            <button
              type="button"
              :data-testid="`kanban-workflow-move-branch-down-${branchIndex}`"
              class="flex p-0 size-9 items-center justify-center rounded-md text-n-slate-10 hover:bg-n-surface-1 hover:text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand disabled:cursor-not-allowed disabled:opacity-40"
              :aria-label="
                t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.MOVE_BRANCH_DOWN')
              "
              :disabled="branchIndex === data.branches.length - 1"
              @click="emit('move-branch', branchIndex, 1)"
            >
              <i class="i-lucide-arrow-down size-4" aria-hidden="true" />
            </button>
            <button
              type="button"
              class="flex p-0 size-9 items-center justify-center rounded-md text-n-ruby-11 hover:bg-n-ruby-3 focus:outline-none focus:ring-2 focus:ring-n-brand disabled:cursor-not-allowed disabled:opacity-40"
              :aria-label="
                t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.REMOVE_BRANCH')
              "
              :disabled="data.branches.length === 1"
              @click="emit('remove-branch', branchIndex)"
            >
              <i class="i-lucide-trash-2 size-4" aria-hidden="true" />
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
            @change="emit('update')"
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
            @change="emit('update')"
          >
            <option value="">
              {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.SELECT_FIELD') }}
            </option>
            <option v-for="field in fields" :key="field.key" :value="field.key">
              {{ field.label }}
            </option>
          </select>
          <select
            v-model="condition.operator"
            class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
            @change="emit('update')"
          >
            <option
              v-for="option in operators"
              :key="option.value"
              :value="option.value"
            >
              {{ option.label }}
            </option>
          </select>
          <select
            v-if="
              optionsFor(condition).length && condition.operator !== 'exists'
            "
            v-model="condition.value"
            data-testid="kanban-workflow-condition-value"
            class="h-9 min-w-0 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
            @change="emit('update')"
          >
            <option value="">
              {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.VALUE') }}
            </option>
            <option
              v-for="option in optionsFor(condition)"
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
            @change="emit('update')"
          />
          <span v-else />
          <button
            type="button"
            class="flex p-0 size-9 items-center justify-center self-end rounded-md text-n-ruby-11 hover:bg-n-ruby-3 focus:outline-none focus:ring-2 focus:ring-n-brand disabled:cursor-not-allowed disabled:opacity-40"
            :aria-label="
              t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.REMOVE_CONDITION')
            "
            :disabled="branch.conditions.length === 1"
            @click="emit('remove-condition', branch, index)"
          >
            <i class="i-lucide-trash-2 size-4" aria-hidden="true" />
          </button>
        </div>
        <button
          type="button"
          data-testid="kanban-workflow-add-condition"
          class="flex h-8 w-fit items-center gap-1 rounded-md border border-solid border-n-weak bg-n-surface-1 px-2 text-xs font-medium text-n-slate-12 hover:bg-n-surface-2 focus:outline-none focus:ring-2 focus:ring-n-brand"
          @click="emit('add-condition', branch)"
        >
          <i class="i-lucide-plus size-3.5" aria-hidden="true" />{{
            t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.ADD_CONDITION')
          }}
        </button>
      </fieldset>
      <button
        type="button"
        data-testid="kanban-workflow-add-branch"
        class="flex h-8 w-fit items-center gap-1 rounded-md border border-solid border-n-weak bg-n-surface-1 px-2 text-xs font-medium text-n-slate-12 hover:bg-n-surface-2 focus:outline-none focus:ring-2 focus:ring-n-brand"
        @click="emit('add-branch')"
      >
        <i class="i-lucide-plus size-3.5" aria-hidden="true" />{{
          t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.ADD_BRANCH')
        }}
      </button>
    </template>

    <fieldset
      v-else
      class="grid gap-3 rounded-lg border border-n-weak bg-n-surface-2 p-3"
    >
      <legend class="px-1 text-xs font-semibold text-n-slate-11">
        {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODES.FILTER') }}
      </legend>
      <select
        v-model="data.match_mode"
        data-testid="kanban-workflow-filter-match-mode"
        class="h-9 w-full rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
        @change="emit('update')"
      >
        <option value="all">
          {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.MATCH_ALL') }}
        </option>
        <option value="any">
          {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.MATCH_ANY') }}
        </option>
      </select>
      <div
        v-for="(condition, index) in data.conditions"
        :key="index"
        data-testid="kanban-workflow-filter-row"
        class="grid gap-2 sm:grid-cols-[minmax(0,1fr)_10rem_minmax(0,1fr)_2rem]"
      >
        <select
          v-model="condition.field_key"
          class="h-9 min-w-0 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
          @change="emit('update')"
        >
          <option value="">
            {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.SELECT_FIELD') }}
          </option>
          <option v-for="field in fields" :key="field.key" :value="field.key">
            {{ field.label }}
          </option>
        </select>
        <select
          v-model="condition.operator"
          class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
          @change="emit('update')"
        >
          <option
            v-for="option in operators"
            :key="option.value"
            :value="option.value"
          >
            {{ option.label }}
          </option>
        </select>
        <select
          v-if="optionsFor(condition).length && condition.operator !== 'exists'"
          v-model="condition.value"
          data-testid="kanban-workflow-filter-condition-value"
          class="h-9 min-w-0 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
          @change="emit('update')"
        >
          <option value="">
            {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.VALUE') }}
          </option>
          <option
            v-for="option in optionsFor(condition)"
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
          @change="emit('update')"
        />
        <span v-else />
        <button
          type="button"
          class="flex p-0 size-9 items-center justify-center self-end rounded-md text-n-ruby-11 hover:bg-n-ruby-3 focus:outline-none focus:ring-2 focus:ring-n-brand disabled:cursor-not-allowed disabled:opacity-40"
          :aria-label="
            t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.REMOVE_CONDITION')
          "
          :disabled="data.conditions.length === 1"
          @click="emit('remove-condition', data, index)"
        >
          <i class="i-lucide-trash-2 size-4" aria-hidden="true" />
        </button>
      </div>
      <button
        type="button"
        data-testid="kanban-workflow-add-filter-condition"
        class="flex h-8 w-fit items-center gap-1 rounded-md border border-solid border-n-weak bg-n-surface-1 px-2 text-xs font-medium text-n-slate-12 hover:bg-n-surface-2 focus:outline-none focus:ring-2 focus:ring-n-brand"
        @click="emit('add-condition', data)"
      >
        <i class="i-lucide-plus size-3.5" aria-hidden="true" />{{
          t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.ADD_CONDITION')
        }}
      </button>
    </fieldset>
  </section>
</template>
