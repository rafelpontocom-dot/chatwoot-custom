<script setup>
import { computed } from 'vue';

const props = defineProps({
  node: { type: Object, required: true },
  agents: { type: Array, default: () => [] },
  teams: { type: Array, default: () => [] },
  connections: { type: Array, default: () => [] },
  endOutcomes: { type: Array, default: () => [] },
  t: { type: Function, required: true },
});

const emit = defineEmits(['update']);
const data = computed(() => props.node.data);
const activeConnections = computed(() =>
  props.connections.filter(connection => connection.active)
);
const title = computed(() => {
  if (props.node.type === 'webhook') {
    return props.t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODES.WEBHOOK');
  }
  if (props.node.type === 'end') {
    return props.t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODES.END');
  }
  if (props.node.type === 'human_handoff') {
    return props.t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODES.HUMAN_HANDOFF');
  }
  if (props.node.type === 'notify_team') {
    return props.t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODES.NOTIFY_TEAM');
  }
  if (props.node.type === 'audit_log') {
    return props.t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODES.AUDIT_LOG');
  }

  return props.t(
    'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODES.MESSAGE_ELIGIBILITY'
  );
});

const notificationTeamSelected = teamId =>
  data.value.team_ids?.map(Number).includes(Number(teamId));

const toggleNotificationTeam = (teamId, selected) => {
  const teamIds = data.value.team_ids?.map(Number) || [];
  data.value.team_ids = selected
    ? [...new Set([...teamIds, Number(teamId)])]
    : teamIds.filter(id => id !== Number(teamId));
  emit('update');
};
</script>

<template>
  <section class="grid gap-3">
    <div class="rounded-lg border border-n-weak bg-n-surface-2 p-3">
      <p class="m-0 text-sm font-semibold text-n-slate-12">{{ title }}</p>
      <p class="m-0 mt-1 text-xs text-n-slate-11">
        <template v-if="node.type === 'webhook'">
          {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.WEBHOOK_HINT') }}
        </template>
        <template v-else-if="node.type === 'human_handoff'">
          {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.HANDOFF_HINT') }}
        </template>
        <template v-else-if="node.type === 'notify_team'">
          {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NOTIFY_TEAM_HINT') }}
        </template>
        <template v-else-if="node.type === 'audit_log'">
          {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.AUDIT_LOG_HINT') }}
        </template>
        <template v-else-if="node.type === 'message_eligibility'">
          {{
            t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.MESSAGE_ELIGIBILITY_HINT')
          }}
        </template>
        <template v-else>
          {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODE_HINT') }}
        </template>
      </p>
    </div>

    <template v-if="node.type === 'webhook'">
      <label class="grid gap-1 text-xs font-medium text-n-slate-11">
        {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.WEBHOOK_CONNECTION') }}
        <select
          v-model="data.connection_id"
          class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
          @change="emit('update')"
        >
          <option value="">
            {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.WEBHOOK_CONNECTION') }}
          </option>
          <option
            v-for="connection in activeConnections"
            :key="connection.id"
            :value="connection.id"
          >
            {{ connection.name }}
          </option>
        </select>
      </label>
      <details class="rounded-md border border-n-weak bg-n-surface-2 p-3">
        <summary class="cursor-pointer text-xs font-medium text-n-slate-12">
          {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.ADVANCED') }}
        </summary>
        <label class="mt-3 grid gap-1 text-xs font-medium text-n-slate-11">
          {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.WEBHOOK_FAILURE_POLICY') }}
          <select
            v-model="data.failure_mode"
            class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
            @change="emit('update')"
          >
            <option value="stop">
              {{
                t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.WEBHOOK_FAILURE_STOP')
              }}
            </option>
            <option value="route">
              {{
                t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.WEBHOOK_FAILURE_ROUTE')
              }}
            </option>
          </select>
        </label>
      </details>
    </template>

    <label
      v-else-if="node.type === 'end'"
      class="grid gap-1 text-xs font-medium text-n-slate-11"
    >
      {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.END_OUTCOME') }}
      <select
        v-model="data.outcome"
        class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
        @change="emit('update')"
      >
        <option
          v-for="outcome in endOutcomes"
          :key="outcome.value"
          :value="outcome.value"
        >
          {{ outcome.label }}
        </option>
      </select>
    </label>

    <template v-else-if="node.type === 'human_handoff'">
      <div class="grid gap-3 sm:grid-cols-2">
        <label class="grid gap-1 text-xs font-medium text-n-slate-11">
          {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.HANDOFF_TEAM') }}
          <select
            v-model="data.team_id"
            data-testid="kanban-workflow-handoff-team"
            class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
            @change="emit('update')"
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
            v-model="data.owner_id"
            data-testid="kanban-workflow-handoff-owner"
            class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
            @change="emit('update')"
          >
            <option value="">
              {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.SELECT_AGENT') }}
            </option>
            <option v-for="agent in agents" :key="agent.id" :value="agent.id">
              {{ agent.name }}
            </option>
          </select>
        </label>
      </div>
      <label class="grid gap-1 text-xs font-medium text-n-slate-11">
        {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.HANDOFF_NOTE') }}
        <textarea
          v-model="data.note"
          rows="3"
          class="resize-y rounded-md border border-n-weak bg-n-surface-2 px-3 py-2 text-sm text-n-slate-12 outline-none focus:border-n-brand"
          @change="emit('update')"
        />
      </label>
    </template>

    <template v-else-if="node.type === 'notify_team'">
      <fieldset class="grid gap-2">
        <legend class="text-xs font-medium text-n-slate-11">
          {{
            t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NOTIFY_TEAM_DESTINATIONS')
          }}
        </legend>
        <label
          v-for="team in teams"
          :key="team.id"
          class="flex items-center gap-2 rounded-md border border-n-weak bg-n-surface-2 px-3 py-2 text-sm text-n-slate-12"
        >
          <input
            :data-testid="`kanban-workflow-notify-team-${team.id}`"
            type="checkbox"
            class="size-4 rounded border-n-weak text-n-brand focus:ring-n-brand"
            :checked="notificationTeamSelected(team.id)"
            @change="toggleNotificationTeam(team.id, $event.target.checked)"
          />
          {{ team.name }}
        </label>
      </fieldset>
      <label class="grid gap-1 text-xs font-medium text-n-slate-11">
        {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NOTIFY_TEAM_CONTENT') }}
        <textarea
          v-model="data.content"
          data-testid="kanban-workflow-notify-team-content"
          rows="3"
          class="resize-y rounded-md border border-n-weak bg-n-surface-2 px-3 py-2 text-sm text-n-slate-12 outline-none focus:border-n-brand"
          @change="emit('update')"
        />
      </label>
    </template>

    <template v-else-if="node.type === 'audit_log'">
      <label class="grid gap-1 text-xs font-medium text-n-slate-11">
        {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.AUDIT_LOG_CONTENT') }}
        <textarea
          v-model="data.content"
          data-testid="kanban-workflow-audit-log-content"
          rows="3"
          class="resize-y rounded-md border border-n-weak bg-n-surface-2 px-3 py-2 text-sm text-n-slate-12 outline-none focus:border-n-brand"
          @change="emit('update')"
        />
      </label>
    </template>

    <template v-else-if="node.type === 'message_eligibility'">
      <label class="grid gap-1 text-xs font-medium text-n-slate-11">
        {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.MESSAGE_CHANNEL') }}
        <select
          v-model="data.channel"
          class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
          @change="emit('update')"
        >
          <option value="whatsapp">
            {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.CHANNEL_WHATSAPP') }}
          </option>
          <option value="email">
            {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.CHANNEL_EMAIL') }}
          </option>
        </select>
      </label>
      <label class="grid gap-1 text-xs font-medium text-n-slate-11">
        {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.OPT_IN_ATTRIBUTE') }}
        <input
          v-model="data.opt_in_attribute_key"
          class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
          @change="emit('update')"
        />
      </label>
    </template>
  </section>
</template>
