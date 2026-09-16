<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import CalendarAPI from 'dashboard/api/calendar';
import RaevoField from 'dashboard/components-next/raevo/RaevoField.vue';
import SetupGroup from '../shared/SetupGroup.vue';
import { useProcedureDraft } from './procedureDraft';

const { t } = useI18n();
const { draft } = useProcedureDraft();

const page = ref(null);

const NOTICE_MINUTES = [0, 60, 120, 240, 720, 1440, 2880, 4320, 10080];
const MAX_DAYS = [7, 14, 30, 60, 90, 180, 365];
const INTERVALS = [5, 10, 15, 20, 30, 60];
const BUFFERS = [0, 5, 10, 15, 20, 30, 45, 60];
const DAILY = [1, 2, 3, 4, 5, 6, 8, 10, 12, 15, 20];

const noticeLabel = minutes => {
  if (minutes === 0) return t('CALENDAR_SETUP.PROCEDURE.LIMITS.NO_NOTICE');
  if (minutes % 1440 === 0)
    return t('CALENDAR_SETUP.COMMON.DAYS', minutes / 1440, {
      count: minutes / 1440,
    });
  if (minutes % 60 === 0)
    return t('CALENDAR_SETUP.COMMON.HOURS', minutes / 60, {
      count: minutes / 60,
    });
  return t('CALENDAR_SETUP.COMMON.MINUTES', { count: minutes });
};

const daysAhead = days =>
  t('CALENDAR_SETUP.PROCEDURE.LIMITS.DAYS_AHEAD', { count: days });
const minutes = value => t('CALENDAR_SETUP.COMMON.MINUTES', { count: value });

const accountDefault = computed(() => ({
  notice: noticeLabel(page.value?.minimum_notice_minutes ?? 0),
  days: daysAhead(page.value?.maximum_notice_days ?? 60),
  interval: minutes(page.value?.slot_interval_minutes ?? 15),
}));

const withCurrent = (list, current) =>
  current === null || current === undefined || list.includes(current)
    ? list
    : [...list, current].sort((a, b) => a - b);

onMounted(async () => {
  try {
    const { data } = await CalendarAPI.getBookingPage();
    page.value = data;
  } catch {
    page.value = {};
  }
});
</script>

<template>
  <SetupGroup
    :title="t('CALENDAR_SETUP.PROCEDURE.LIMITS.GROUP')"
    :hint="t('CALENDAR_SETUP.PROCEDURE.LIMITS.GROUP_HINT')"
    data-testid="calendar-procedure-tab-limits"
  >
    <div class="grid gap-3 md:grid-cols-3">
      <RaevoField
        compact
        variant="select"
        :label="t('CALENDAR_SETUP.PROCEDURE.LIMITS.MIN_NOTICE')"
        :hint="t('CALENDAR_SETUP.PROCEDURE.LIMITS.MIN_NOTICE_HINT')"
      >
        <template #default="{ controlClass, fieldId, describedBy }">
          <select
            :id="fieldId"
            v-model="draft.minimum_notice_minutes"
            :class="controlClass"
            :aria-describedby="describedBy"
            data-testid="calendar-procedure-min-notice"
          >
            <option :value="null">
              {{
                t('CALENDAR_SETUP.COMMON.ACCOUNT_DEFAULT', {
                  value: accountDefault.notice,
                })
              }}
            </option>
            <option
              v-for="value in withCurrent(
                NOTICE_MINUTES,
                draft.minimum_notice_minutes
              )"
              :key="value"
              :value="value"
            >
              {{ noticeLabel(value) }}
            </option>
          </select>
        </template>
      </RaevoField>
      <RaevoField
        compact
        variant="select"
        :label="t('CALENDAR_SETUP.PROCEDURE.LIMITS.MAX_NOTICE')"
      >
        <template #default="{ controlClass, fieldId }">
          <select
            :id="fieldId"
            v-model="draft.maximum_notice_days"
            :class="controlClass"
          >
            <option :value="null">
              {{
                t('CALENDAR_SETUP.COMMON.ACCOUNT_DEFAULT', {
                  value: accountDefault.days,
                })
              }}
            </option>
            <option
              v-for="value in withCurrent(MAX_DAYS, draft.maximum_notice_days)"
              :key="value"
              :value="value"
            >
              {{ daysAhead(value) }}
            </option>
          </select>
        </template>
      </RaevoField>
      <RaevoField
        compact
        variant="select"
        :label="t('CALENDAR_SETUP.PROCEDURE.LIMITS.INTERVAL')"
      >
        <template #default="{ controlClass, fieldId }">
          <select
            :id="fieldId"
            v-model="draft.slot_interval_minutes"
            :class="controlClass"
            data-testid="calendar-procedure-interval"
          >
            <option :value="null">
              {{
                t('CALENDAR_SETUP.COMMON.ACCOUNT_DEFAULT', {
                  value: accountDefault.interval,
                })
              }}
            </option>
            <option v-for="value in INTERVALS" :key="value" :value="value">
              {{ minutes(value) }}
            </option>
          </select>
        </template>
      </RaevoField>
    </div>
    <div class="grid gap-3 md:grid-cols-3">
      <RaevoField
        compact
        variant="select"
        :label="t('CALENDAR_SETUP.PROCEDURE.LIMITS.BUFFER_BEFORE')"
      >
        <template #default="{ controlClass, fieldId }">
          <select
            :id="fieldId"
            v-model.number="draft.buffer_before_minutes"
            :class="controlClass"
          >
            <option
              v-for="value in withCurrent(BUFFERS, draft.buffer_before_minutes)"
              :key="value"
              :value="value"
            >
              {{ minutes(value) }}
            </option>
          </select>
        </template>
      </RaevoField>
      <RaevoField
        compact
        variant="select"
        :label="t('CALENDAR_SETUP.PROCEDURE.LIMITS.BUFFER_AFTER')"
      >
        <template #default="{ controlClass, fieldId }">
          <select
            :id="fieldId"
            v-model.number="draft.buffer_after_minutes"
            :class="controlClass"
          >
            <option
              v-for="value in withCurrent(BUFFERS, draft.buffer_after_minutes)"
              :key="value"
              :value="value"
            >
              {{ minutes(value) }}
            </option>
          </select>
        </template>
      </RaevoField>
      <RaevoField
        compact
        variant="select"
        :label="t('CALENDAR_SETUP.PROCEDURE.LIMITS.DAILY')"
      >
        <template #default="{ controlClass, fieldId }">
          <select
            :id="fieldId"
            v-model="draft.daily_limit"
            :class="controlClass"
            data-testid="calendar-procedure-daily"
          >
            <option :value="null">
              {{ t('CALENDAR_SETUP.PROCEDURE.LIMITS.NO_LIMIT') }}
            </option>
            <option
              v-for="value in withCurrent(DAILY, draft.daily_limit)"
              :key="value"
              :value="value"
            >
              {{
                t('CALENDAR_SETUP.PROCEDURE.LIMITS.PER_DAY', value, {
                  count: value,
                })
              }}
            </option>
          </select>
        </template>
      </RaevoField>
    </div>
  </SetupGroup>
</template>
