<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import CalendarAPI from 'dashboard/api/calendar';
import RaevoField from 'dashboard/components-next/raevo/RaevoField.vue';
import SetupButton from './shared/SetupButton.vue';
import SetupChips from './shared/SetupChips.vue';
import SetupGroup from './shared/SetupGroup.vue';
import SetupHead from './shared/SetupHead.vue';
import SetupPill from './shared/SetupPill.vue';
import SetupRow from './shared/SetupRow.vue';
import { apiErrorMessage } from './setupHelpers';
import { useCalendarSetup } from './useCalendarSetup';

const { t } = useI18n();
const { teams, resources, loadTeams, loadResources, loadProcedures } =
  useCalendarSetup();

const editingId = ref(null);
const draft = ref(null);
const isSaving = ref(false);
const error = ref('');

const STRATEGIES = ['first_available', 'round_robin', 'collective'];

const strategyOptions = computed(() =>
  STRATEGIES.map(strategy => ({
    value: strategy,
    label: t(`CALENDAR_SETUP.TEAMS.STRATEGIES.${strategy.toUpperCase()}`),
  }))
);

const professionalOptions = computed(() =>
  resources.value
    .filter(resource => resource.active && resource.resource_type === 'user')
    .map(resource => ({ value: resource.id, label: resource.name }))
);

const summary = team =>
  `${t('CALENDAR_SETUP.TEAMS.MEMBERS_COUNT', team.members.length, { count: team.members.length })} · ${t(
    'CALENDAR_SETUP.TEAMS.PROCEDURES_COUNT',
    team.procedures_count,
    { count: team.procedures_count }
  )}`;

const startEdit = team => {
  error.value = '';
  editingId.value = team?.id || 'new';
  draft.value = {
    name: team?.name || '',
    assignment_strategy: team?.assignment_strategy || 'first_available',
    member_ids: (team?.members || []).map(member => member.id),
  };
};

const save = async () => {
  if (!draft.value.name.trim()) {
    error.value = t('CALENDAR_SETUP.TEAMS.NAME_REQUIRED');
    return;
  }
  isSaving.value = true;
  error.value = '';
  const payload = {
    team: {
      name: draft.value.name.trim(),
      assignment_strategy: draft.value.assignment_strategy,
    },
    member_ids: draft.value.member_ids,
  };
  try {
    if (editingId.value === 'new') await CalendarAPI.createTeam(payload);
    else await CalendarAPI.updateTeam(editingId.value, payload);
    await Promise.all([loadTeams(), loadProcedures()]);
    editingId.value = null;
  } catch (saveError) {
    error.value = apiErrorMessage(
      saveError,
      t('CALENDAR_SETUP.COMMON.SAVE_ERROR')
    );
  } finally {
    isSaving.value = false;
  }
};

// A regra muda sem abrir a edição: é a decisão que mais se ajusta.
const changeStrategy = async (team, strategy) => {
  try {
    await CalendarAPI.updateTeam(team.id, {
      team: { assignment_strategy: strategy },
    });
    await loadTeams();
  } catch (saveError) {
    error.value = apiErrorMessage(
      saveError,
      t('CALENDAR_SETUP.COMMON.SAVE_ERROR')
    );
  }
};

const remove = async team => {
  // eslint-disable-next-line no-alert
  if (
    !window.confirm(
      t('CALENDAR_SETUP.TEAMS.DELETE_CONFIRM', { name: team.name })
    )
  )
    return;
  await CalendarAPI.deleteTeam(team.id);
  await Promise.all([loadTeams(), loadProcedures()]);
};

onMounted(async () => {
  await Promise.all([
    teams.value.length ? null : loadTeams(),
    resources.value.length ? null : loadResources(),
  ]);
});
</script>

<template>
  <section
    class="grid content-start gap-4 px-5 py-[18px]"
    data-testid="calendar-setup-teams"
  >
    <SetupHead
      :title="t('CALENDAR_SETUP.TEAMS.TITLE')"
      :description="t('CALENDAR_SETUP.TEAMS.DESCRIPTION')"
    >
      <SetupButton
        variant="primary"
        :label="t('CALENDAR_SETUP.TEAMS.NEW')"
        data-testid="calendar-team-new"
        @click="startEdit(null)"
      />
    </SetupHead>

    <p
      v-if="!teams.length && editingId !== 'new'"
      class="mb-0 text-ui text-n-slate-10"
    >
      {{ t('CALENDAR_SETUP.TEAMS.EMPTY') }}
    </p>

    <template
      v-for="team in [
        ...teams,
        ...(editingId === 'new'
          ? [{ id: 'new', members: [], procedures_count: 0 }]
          : []),
      ]"
      :key="team.id"
    >
      <SetupGroup
        v-if="editingId === team.id"
        :title="team.name || t('CALENDAR_SETUP.TEAMS.NEW_TITLE')"
        :data-testid="`calendar-team-form-${team.id}`"
      >
        <RaevoField compact :label="t('CALENDAR_SETUP.TEAMS.NAME')">
          <template #default="{ controlClass, fieldId }">
            <input
              :id="fieldId"
              v-model="draft.name"
              type="text"
              :class="controlClass"
              :placeholder="t('CALENDAR_SETUP.TEAMS.NAME_PLACEHOLDER')"
              data-testid="calendar-team-name"
            />
          </template>
        </RaevoField>
        <div class="grid gap-1.5">
          <span class="text-xs font-medium text-n-slate-11">{{
            t('CALENDAR_SETUP.TEAMS.MEMBERS')
          }}</span>
          <SetupChips
            v-model="draft.member_ids"
            multiple
            :label="t('CALENDAR_SETUP.TEAMS.MEMBERS')"
            :options="professionalOptions"
          />
        </div>
        <SetupRow
          :title="t('CALENDAR_SETUP.TEAMS.DISTRIBUTE')"
          :hint="t('CALENDAR_SETUP.TEAMS.DISTRIBUTE_HINT')"
        >
          <SetupChips
            v-model="draft.assignment_strategy"
            :label="t('CALENDAR_SETUP.TEAMS.DISTRIBUTE')"
            :options="strategyOptions"
          />
        </SetupRow>
        <p v-if="error" class="mb-0 text-ui text-n-ruby-11" role="alert">
          {{ error }}
        </p>
        <div class="flex justify-end gap-2">
          <SetupButton
            :label="t('CALENDAR_SETUP.COMMON.CANCEL')"
            @click="editingId = null"
          />
          <SetupButton
            variant="primary"
            :label="t('CALENDAR_SETUP.COMMON.SAVE')"
            :loading="isSaving"
            data-testid="calendar-team-save"
            @click="save"
          />
        </div>
      </SetupGroup>

      <SetupGroup
        v-else
        :title="team.name"
        :data-testid="`calendar-team-${team.id}`"
      >
        <template #aside>
          <span class="flex items-center gap-2">
            <small class="text-xs text-n-slate-10">{{ summary(team) }}</small>
            <SetupButton
              size="sm"
              :label="t('CALENDAR_SETUP.COMMON.EDIT')"
              @click="startEdit(team)"
            />
          </span>
        </template>
        <div class="grid">
          <SetupRow
            v-for="member in team.members"
            :key="member.id"
            :title="member.name"
            :hint="
              member.schedule_name || t('CALENDAR_SETUP.RESOURCES.OWN_HOURS')
            "
          >
            <SetupPill
              :tone="member.active ? 'on' : 'neutral'"
              :label="
                member.active
                  ? t('CALENDAR_SETUP.TEAMS.ACTIVE')
                  : t('CALENDAR_SETUP.TEAMS.INACTIVE')
              "
            />
          </SetupRow>
          <SetupRow
            :title="t('CALENDAR_SETUP.TEAMS.DISTRIBUTE')"
            :hint="t('CALENDAR_SETUP.TEAMS.DISTRIBUTE_HINT')"
          >
            <SetupChips
              :model-value="team.assignment_strategy"
              :label="t('CALENDAR_SETUP.TEAMS.DISTRIBUTE')"
              :options="strategyOptions"
              @update:model-value="strategy => changeStrategy(team, strategy)"
            />
          </SetupRow>
        </div>
        <p class="mb-0 text-xs leading-relaxed text-n-slate-10">
          <strong>{{
            t('CALENDAR_SETUP.TEAMS.STRATEGIES.FIRST_AVAILABLE')
          }}</strong>
          {{ t('CALENDAR_SETUP.TEAMS.EXPLAIN_FIRST') }}
          <strong>{{
            t('CALENDAR_SETUP.TEAMS.STRATEGIES.ROUND_ROBIN')
          }}</strong>
          {{ t('CALENDAR_SETUP.TEAMS.EXPLAIN_ROUND') }}
          <strong>{{ t('CALENDAR_SETUP.TEAMS.STRATEGIES.COLLECTIVE') }}</strong>
          {{ t('CALENDAR_SETUP.TEAMS.EXPLAIN_COLLECTIVE') }}
        </p>
        <div class="flex justify-end">
          <SetupButton
            size="sm"
            :label="t('CALENDAR_SETUP.TEAMS.DELETE')"
            @click="remove(team)"
          />
        </div>
      </SetupGroup>
    </template>
  </section>
</template>
