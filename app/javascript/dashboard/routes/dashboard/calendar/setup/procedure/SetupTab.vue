<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import RaevoField from 'dashboard/components-next/raevo/RaevoField.vue';
import { RAEVO_PICKER_COLORS } from 'dashboard/constants/raevoPalette';
import SetupGroup from '../shared/SetupGroup.vue';
import SetupRow from '../shared/SetupRow.vue';
import SetupSwitch from '../shared/SetupSwitch.vue';
import { toSlug } from '../setupHelpers';
import { useProcedureDraft } from './procedureDraft';

const { t } = useI18n();
const { draft, bookingPageUrl, errors } = useProcedureDraft();

const DURATIONS = [10, 15, 20, 30, 40, 45, 50, 60, 75, 90, 120, 150, 180, 240];
const LOCATIONS = ['in_person', 'video', 'phone', 'other'];
const COLOR_NAMES = [
  'BLUE',
  'TEAL',
  'AMBER',
  'MAGENTA',
  'GREEN',
  'RED',
  'NAVY',
  'GRAY',
];

const linkPrefix = computed(() => {
  const base = bookingPageUrl.value || `${window.location.origin}/agendar/…`;
  return `${base.replace(/^https?:\/\//, '')}/`;
});

const slugPlaceholder = computed(() => toSlug(draft.value.name));

const durationOptions = computed(() => {
  const values = new Set([...DURATIONS, Number(draft.value.duration_minutes)]);
  return [...values].sort((a, b) => a - b);
});
</script>

<template>
  <SetupGroup
    :title="t('CALENDAR_SETUP.PROCEDURE.SETUP.GROUP')"
    :hint="t('CALENDAR_SETUP.PROCEDURE.SETUP.GROUP_HINT')"
    data-testid="calendar-procedure-tab-setup"
  >
    <div class="grid gap-3 md:grid-cols-2">
      <RaevoField
        compact
        :label="t('CALENDAR_SETUP.PROCEDURE.SETUP.NAME')"
        :error="errors.name"
      >
        <template #default="{ controlClass, fieldId }">
          <input
            :id="fieldId"
            v-model="draft.name"
            type="text"
            :class="controlClass"
            data-testid="calendar-procedure-name"
          />
        </template>
      </RaevoField>
      <RaevoField
        compact
        :label="t('CALENDAR_SETUP.PROCEDURE.SETUP.LINK')"
        :error="errors.public_slug"
      >
        <template #default="{ fieldId }">
          <div
            class="flex h-9 items-center overflow-hidden rounded-lg border border-solid border-n-strong bg-n-solid-1 pl-3 text-ui focus-within:border-n-brand focus-within:ring-2 focus-within:ring-n-brand/20"
          >
            <span class="min-w-0 truncate text-n-slate-10" :title="linkPrefix">
              {{ linkPrefix }}
            </span>
            <input
              :id="fieldId"
              v-model="draft.public_slug"
              type="text"
              :placeholder="slugPlaceholder"
              class="reset-base mb-0 h-full w-[45%] min-w-[8rem] shrink-0 border-0 bg-transparent pr-3 text-ui font-semibold text-n-slate-12 outline-none"
              data-testid="calendar-procedure-slug"
            />
          </div>
        </template>
      </RaevoField>
    </div>

    <RaevoField
      compact
      variant="textarea"
      :label="t('CALENDAR_SETUP.PROCEDURE.SETUP.DESCRIPTION')"
    >
      <template #default="{ controlClass, fieldId }">
        <textarea
          :id="fieldId"
          v-model="draft.public_description"
          rows="2"
          :class="controlClass"
        />
      </template>
    </RaevoField>

    <div class="grid gap-3 md:grid-cols-3">
      <RaevoField
        compact
        variant="select"
        :label="t('CALENDAR_SETUP.PROCEDURE.SETUP.DURATION')"
      >
        <template #default="{ controlClass, fieldId }">
          <select
            :id="fieldId"
            v-model.number="draft.duration_minutes"
            :class="controlClass"
            data-testid="calendar-procedure-duration"
          >
            <option
              v-for="minutes in durationOptions"
              :key="minutes"
              :value="minutes"
            >
              {{ t('CALENDAR_SETUP.COMMON.MINUTES', { count: minutes }) }}
            </option>
          </select>
        </template>
      </RaevoField>
      <RaevoField
        compact
        variant="select"
        :label="t('CALENDAR_SETUP.PROCEDURE.SETUP.LOCATION')"
      >
        <template #default="{ controlClass, fieldId }">
          <select
            :id="fieldId"
            v-model="draft.location_type"
            :class="controlClass"
          >
            <option
              v-for="location in LOCATIONS"
              :key="location"
              :value="location"
            >
              {{
                t(
                  `CALENDAR_SETUP.PROCEDURE.LOCATIONS.${location.toUpperCase()}`
                )
              }}
            </option>
          </select>
        </template>
      </RaevoField>
      <RaevoField
        compact
        variant="select"
        :label="t('CALENDAR_SETUP.PROCEDURE.SETUP.COLOR')"
      >
        <template #default="{ controlClass, fieldId }">
          <select
            :id="fieldId"
            v-model="draft.color"
            :class="controlClass"
            class="pl-8"
          >
            <option
              v-for="(color, index) in RAEVO_PICKER_COLORS"
              :key="color"
              :value="color"
            >
              {{ t(`CALENDAR_SETUP.PROCEDURE.COLORS.${COLOR_NAMES[index]}`) }}
            </option>
          </select>
          <span
            class="pointer-events-none absolute left-3 top-1/2 size-3 -translate-y-1/2 rounded-sm"
            :style="{ backgroundColor: draft.color }"
            aria-hidden="true"
          />
        </template>
      </RaevoField>
    </div>

    <SetupRow
      :title="t('CALENDAR_SETUP.PROCEDURE.SETUP.RECURRENCE')"
      :hint="t('CALENDAR_SETUP.PROCEDURE.SETUP.RECURRENCE_HINT')"
    >
      <input
        v-if="draft.recurrence_allowed"
        v-model.number="draft.max_sessions"
        type="number"
        min="1"
        max="100"
        class="reset-base mb-0 h-8 w-20 rounded-lg border border-solid border-n-strong bg-n-solid-1 px-2 text-ui text-n-slate-12"
        :aria-label="t('CALENDAR_SETUP.PROCEDURE.SETUP.MAX_SESSIONS')"
      />
      <SetupSwitch
        v-model="draft.recurrence_allowed"
        :label="t('CALENDAR_SETUP.PROCEDURE.SETUP.RECURRENCE')"
      />
    </SetupRow>
  </SetupGroup>
</template>
