<!-- eslint-disable vue/html-closing-bracket-newline -->
<script setup>
import { computed } from 'vue';

const props = defineProps({
  node: { type: Object, required: true },
  dateFields: { type: Array, default: () => [] },
  timezones: { type: Array, default: () => [] },
  businessDays: { type: Array, default: () => [] },
  timeoutLabel: { type: String, required: true },
  t: { type: Function, required: true },
});

const emit = defineEmits(['update']);
const data = computed(() => props.node.data);
</script>

<template>
  <!-- eslint-disable vue/html-closing-bracket-newline -->
  <template v-if="node.type === 'delay'">
    <label class="grid gap-1 text-xs font-medium text-n-slate-11">
      {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.DELAY_HOURS') }}
      <input
        v-model.number="data.delay_hours"
        min="1"
        type="number"
        class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
        @change="emit('update')"
      />
    </label>
  </template>
  <template v-else-if="node.type === 'random_delay'">
    <div class="grid grid-cols-2 gap-2">
      <label class="grid gap-1 text-xs font-medium text-n-slate-11">
        {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.RANDOM_DELAY_MINUTES_MIN') }}
        <input
          v-model.number="data.min_minutes"
          min="1"
          type="number"
          class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
          @change="emit('update')"
        />
      </label>
      <label class="grid gap-1 text-xs font-medium text-n-slate-11">
        {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.RANDOM_DELAY_MINUTES_MAX') }}
        <input
          v-model.number="data.max_minutes"
          min="1"
          type="number"
          class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
          @change="emit('update')"
        />
      </label>
    </div>
    <p class="m-0 text-xs text-n-slate-10">
      {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.RANDOM_DELAY_HINT') }}
    </p>
  </template>
  <template v-else-if="node.type === 'wait_until_field'">
    <label class="grid gap-1 text-xs font-medium text-n-slate-11">
      {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.DATE_FIELD') }}
      <select
        v-model="data.field_key"
        class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
        @change="emit('update')"
      >
        <option value="">
          {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.DATE_FIELD') }}
        </option>
        <option v-for="field in dateFields" :key="field.key" :value="field.key">
          {{ field.label }}
        </option>
      </select>
    </label>
    <label class="grid gap-1 text-xs font-medium text-n-slate-11">
      {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.DATE_OFFSET_HOURS') }}
      <input
        v-model.number="data.offset_hours"
        type="number"
        class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
        @change="emit('update')"
      />
    </label>
    <details class="rounded-md border border-n-weak bg-n-surface-2 p-2">
      <summary
        class="cursor-pointer text-xs font-medium text-n-slate-11 focus:outline-none focus:ring-2 focus:ring-n-brand"
      >
        {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.ADVANCED') }}
      </summary>
      <div class="mt-2 grid gap-2">
        <label class="grid gap-1 text-xs font-medium text-n-slate-11">
          {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.DATE_TIMEZONE') }}
          <select
            v-model="data.timezone"
            class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
            @change="emit('update')"
          >
            <option
              v-for="timezone in timezones"
              :key="timezone.value"
              :value="timezone.value"
            >
              {{ timezone.label }}
            </option>
          </select>
        </label>
        <label class="grid gap-1 text-xs font-medium text-n-slate-11">
          {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.DATE_FAILURE_POLICY') }}
          <select
            v-model="data.failure_mode"
            data-testid="kanban-workflow-date-failure-mode"
            class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
            @change="emit('update')"
          >
            <option value="stop">
              {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.DATE_FAILURE_STOP') }}
            </option>
            <option value="route">
              {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.DATE_FAILURE_ROUTE') }}
            </option>
          </select>
        </label>
      </div>
    </details>
  </template>
  <template
    v-else-if="
      node.type === 'wait_for_response' || node.type === 'wait_for_inactivity'
    "
  >
    <label class="grid gap-1 text-xs font-medium text-n-slate-11">
      {{ timeoutLabel }}
      <input
        v-model.number="data.timeout_hours"
        min="1"
        type="number"
        class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
        @change="emit('update')"
      />
    </label>
    <details class="rounded-md border border-n-weak bg-n-surface-2 p-2">
      <summary
        class="cursor-pointer text-xs font-medium text-n-slate-11 focus:outline-none focus:ring-2 focus:ring-n-brand"
      >
        {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.ADVANCED') }}
      </summary>
      <label class="mt-2 grid gap-1 text-xs font-medium text-n-slate-11">
        {{
          node.type === 'wait_for_response'
            ? t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.RESPONSE_TIMEOUT_POLICY')
            : t(
                'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.INACTIVITY_INTERRUPTION_POLICY'
              )
        }}
        <select
          v-model="
            data[
              node.type === 'wait_for_response'
                ? 'timeout_mode'
                : 'interruption_mode'
            ]
          "
          :data-testid="
            node.type === 'wait_for_response'
              ? 'kanban-workflow-response-timeout-mode'
              : 'kanban-workflow-inactivity-interruption-mode'
          "
          class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
          @change="emit('update')"
        >
          <option
            :value="node.type === 'wait_for_response' ? 'continue' : 'stop'"
          >
            {{
              node.type === 'wait_for_response'
                ? t(
                    'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.RESPONSE_TIMEOUT_CONTINUE'
                  )
                : t(
                    'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.INACTIVITY_INTERRUPTION_STOP'
                  )
            }}
          </option>
          <option value="route">
            {{
              node.type === 'wait_for_response'
                ? t(
                    'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.RESPONSE_TIMEOUT_ROUTE'
                  )
                : t(
                    'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.INACTIVITY_INTERRUPTION_ROUTE'
                  )
            }}
          </option>
        </select>
      </label>
    </details>
  </template>
  <template v-else-if="node.type === 'wait_for_business_hours'">
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
          ><input
            v-model="data.weekdays"
            :value="day.value"
            type="checkbox"
            class="size-3 rounded border-n-weak text-n-brand focus:ring-n-brand"
            @change="emit('update')"
          />{{ day.label }}</label
        >
      </div>
    </fieldset>
    <div class="grid grid-cols-2 gap-2">
      <label class="grid gap-1 text-xs font-medium text-n-slate-11"
        >{{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.BUSINESS_START')
        }}<input
          v-model="data.start_time"
          type="time"
          class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
          @change="emit('update')" /></label
      ><label class="grid gap-1 text-xs font-medium text-n-slate-11"
        >{{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.BUSINESS_END')
        }}<input
          v-model="data.end_time"
          type="time"
          class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
          @change="emit('update')"
      /></label>
    </div>
    <details class="rounded-md border border-n-weak bg-n-surface-2 p-2">
      <summary
        class="cursor-pointer text-xs font-medium text-n-slate-11 focus:outline-none focus:ring-2 focus:ring-n-brand"
      >
        {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.ADVANCED') }}
      </summary>
      <div class="mt-2 grid gap-2">
        <label class="grid gap-1 text-xs font-medium text-n-slate-11"
          >{{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.QUIET_TIMEZONE')
          }}<select
            v-model="data.timezone"
            class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
            @change="emit('update')"
          >
            <option
              v-for="timezone in timezones"
              :key="timezone.value"
              :value="timezone.value"
            >
              {{ timezone.label }}
            </option>
          </select></label
        ><label class="grid gap-1 text-xs font-medium text-n-slate-11"
          >{{
            t(
              'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.BUSINESS_HOURS_FAILURE_POLICY'
            )
          }}<select
            v-model="data.failure_mode"
            data-testid="kanban-workflow-business-hours-failure-mode"
            class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
            @change="emit('update')"
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
          </select></label
        >
      </div>
    </details>
  </template>
</template>
