<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import RaevoField from 'dashboard/components-next/raevo/RaevoField.vue';
import SetupChips from '../shared/SetupChips.vue';
import SetupGroup from '../shared/SetupGroup.vue';
import SetupRow from '../shared/SetupRow.vue';
import SetupSwitch from '../shared/SetupSwitch.vue';
import { useProcedureDraft } from './procedureDraft';

const { t } = useI18n();
const { draft } = useProcedureDraft();

const DEADLINES = [0, 1, 2, 4, 6, 12, 24, 48, 72];

const cancelOptions = computed(() =>
  ['back_to_scheduling', 'mark_lost', 'none'].map(action => ({
    value: action,
    label: t(
      `CALENDAR_SETUP.PROCEDURE.CHANGES.ON_CANCEL_OPTIONS.${action.toUpperCase()}`
    ),
  }))
);

const deadlineLabel = hours =>
  hours === 0
    ? t('CALENDAR_SETUP.PROCEDURE.CHANGES.ANY_TIME')
    : t('CALENDAR_SETUP.PROCEDURE.CHANGES.HOURS_BEFORE', hours, {
        count: hours,
      });
</script>

<template>
  <SetupGroup
    :title="t('CALENDAR_SETUP.PROCEDURE.CHANGES.GROUP')"
    :hint="t('CALENDAR_SETUP.PROCEDURE.CHANGES.GROUP_HINT')"
    data-testid="calendar-procedure-tab-changes"
  >
    <SetupRow
      :title="t('CALENDAR_SETUP.PROCEDURE.CHANGES.RESCHEDULE')"
      :hint="t('CALENDAR_SETUP.PROCEDURE.CHANGES.RESCHEDULE_HINT')"
    >
      <SetupSwitch
        v-model="draft.reschedule_allowed"
        :label="t('CALENDAR_SETUP.PROCEDURE.CHANGES.RESCHEDULE')"
      />
    </SetupRow>
    <SetupRow :title="t('CALENDAR_SETUP.PROCEDURE.CHANGES.CANCEL')">
      <SetupSwitch
        v-model="draft.cancel_allowed"
        :label="t('CALENDAR_SETUP.PROCEDURE.CHANGES.CANCEL')"
      />
    </SetupRow>
    <div class="grid gap-3 md:grid-cols-2">
      <RaevoField
        compact
        variant="select"
        :label="t('CALENDAR_SETUP.PROCEDURE.CHANGES.DEADLINE')"
      >
        <template #default="{ controlClass, fieldId }">
          <select
            :id="fieldId"
            v-model.number="draft.change_deadline_hours"
            :class="controlClass"
          >
            <option v-for="hours in DEADLINES" :key="hours" :value="hours">
              {{ deadlineLabel(hours) }}
            </option>
          </select>
        </template>
      </RaevoField>
      <RaevoField
        compact
        variant="select"
        :label="t('CALENDAR_SETUP.PROCEDURE.CHANGES.REASON')"
      >
        <template #default="{ controlClass, fieldId }">
          <select
            :id="fieldId"
            v-model="draft.cancel_reason_required"
            :class="controlClass"
          >
            <option :value="true">
              {{ t('CALENDAR_SETUP.PROCEDURE.CHANGES.REASON_REQUIRED') }}
            </option>
            <option :value="false">
              {{ t('CALENDAR_SETUP.PROCEDURE.CHANGES.REASON_OPTIONAL') }}
            </option>
          </select>
        </template>
      </RaevoField>
    </div>
    <SetupRow
      :title="t('CALENDAR_SETUP.PROCEDURE.CHANGES.ON_CANCEL')"
      :hint="t('CALENDAR_SETUP.PROCEDURE.CHANGES.ON_CANCEL_HINT')"
    >
      <SetupChips
        v-model="draft.on_cancel_stage_action"
        :label="t('CALENDAR_SETUP.PROCEDURE.CHANGES.ON_CANCEL')"
        :options="cancelOptions"
      />
    </SetupRow>
  </SetupGroup>
</template>
