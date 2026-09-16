<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import RaevoField from 'dashboard/components-next/raevo/RaevoField.vue';
import SetupChips from '../shared/SetupChips.vue';
import SetupGroup from '../shared/SetupGroup.vue';
import SetupRow from '../shared/SetupRow.vue';
import { useCalendarSetup } from '../useCalendarSetup';
import { useProcedureDraft } from './procedureDraft';

const { t } = useI18n();
const { draft, goToSection } = useProcedureDraft();
const { resources, teams } = useCalendarSetup();

const TYPES = ['user', 'room', 'equipment', 'generic'];
const TEAM_STRATEGIES = ['first_available', 'round_robin', 'collective'];

const groups = computed(() =>
  TYPES.map(type => ({
    type,
    options: resources.value
      .filter(resource => resource.active && resource.resource_type === type)
      .map(resource => ({ value: resource.id, label: resource.name })),
  })).filter(group => group.options.length)
);

const selectedOf = type =>
  draft.value.resource_ids.filter(id =>
    resources.value.some(
      resource => resource.id === id && resource.resource_type === type
    )
  );

const setSelected = (type, ids) => {
  const others = draft.value.resource_ids.filter(
    id =>
      !resources.value.some(
        resource => resource.id === id && resource.resource_type === type
      )
  );
  draft.value.resource_ids = [...others, ...ids];
};

const hintFor = type => {
  const count = selectedOf(type).length;
  return count
    ? t('CALENDAR_SETUP.PROCEDURE.RESOURCES.REQUIRED_COUNT', count, { count })
    : t('CALENDAR_SETUP.PROCEDURE.RESOURCES.NOT_USED');
};

const showStrategy = computed(
  () =>
    selectedOf('user').length > 1 ||
    TEAM_STRATEGIES.includes(draft.value.assignment_strategy)
);

const strategyOptions = computed(() =>
  ['patient_choice', 'first_available', 'round_robin', 'collective'].map(
    strategy => ({
      value: strategy,
      label: t(
        `CALENDAR_SETUP.PROCEDURE.RESOURCES.STRATEGIES.${strategy.toUpperCase()}`
      ),
    })
  )
);

const needsTeam = computed(() =>
  TEAM_STRATEGIES.includes(draft.value.assignment_strategy)
);
</script>

<template>
  <SetupGroup
    :title="t('CALENDAR_SETUP.PROCEDURE.RESOURCES.GROUP')"
    :hint="t('CALENDAR_SETUP.PROCEDURE.RESOURCES.GROUP_HINT')"
    flush
    data-testid="calendar-procedure-tab-resources"
  >
    <p v-if="!groups.length" class="mb-0 py-2.5 text-ui text-n-slate-10">
      {{ t('CALENDAR_SETUP.PROCEDURE.RESOURCES.NO_RESOURCES') }}
    </p>
    <SetupRow
      v-for="group in groups"
      :key="group.type"
      :title="t(`CALENDAR_SETUP.RESOURCES.TYPES.${group.type.toUpperCase()}`)"
      :hint="hintFor(group.type)"
      :data-testid="`calendar-procedure-resources-${group.type}`"
    >
      <SetupChips
        :model-value="selectedOf(group.type)"
        multiple
        :label="t(`CALENDAR_SETUP.RESOURCES.TYPES.${group.type.toUpperCase()}`)"
        :options="group.options"
        @update:model-value="ids => setSelected(group.type, ids)"
      />
    </SetupRow>
    <SetupRow
      v-if="showStrategy"
      :title="t('CALENDAR_SETUP.PROCEDURE.RESOURCES.STRATEGY')"
      :hint="t('CALENDAR_SETUP.PROCEDURE.RESOURCES.STRATEGY_HINT')"
    >
      <SetupChips
        v-model="draft.assignment_strategy"
        :label="t('CALENDAR_SETUP.PROCEDURE.RESOURCES.STRATEGY')"
        :options="strategyOptions"
        data-testid="calendar-procedure-strategy"
      />
    </SetupRow>
    <div v-if="needsTeam" class="grid gap-2 py-2.5">
      <RaevoField
        v-if="teams.length"
        compact
        variant="select"
        :label="t('CALENDAR_SETUP.PROCEDURE.RESOURCES.TEAM')"
        :hint="t('CALENDAR_SETUP.PROCEDURE.RESOURCES.TEAM_HINT')"
      >
        <template #default="{ controlClass, fieldId, describedBy }">
          <select
            :id="fieldId"
            v-model="draft.team_id"
            :class="controlClass"
            :aria-describedby="describedBy"
            data-testid="calendar-procedure-team"
          >
            <option :value="null" disabled>
              {{ t('CALENDAR_SETUP.PROCEDURE.RESOURCES.PICK_TEAM') }}
            </option>
            <option v-for="team in teams" :key="team.id" :value="team.id">
              {{ team.name }}
            </option>
          </select>
        </template>
      </RaevoField>
      <p
        v-else
        class="mb-0 flex flex-wrap items-center gap-1.5 text-ui text-n-amber-11"
        role="status"
      >
        <i class="i-lucide-triangle-alert size-4" aria-hidden="true" />
        {{ t('CALENDAR_SETUP.PROCEDURE.RESOURCES.TEAM_NEEDED') }}
        <button
          type="button"
          class="font-semibold text-n-brand underline outline-none focus-visible:ring-2 focus-visible:ring-n-brand/40"
          @click="goToSection('teams')"
        >
          {{ t('CALENDAR_SETUP.PROCEDURE.RESOURCES.GO_TO_TEAMS') }}
        </button>
      </p>
    </div>
  </SetupGroup>
</template>
