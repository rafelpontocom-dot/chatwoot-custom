<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import RaevoField from 'dashboard/components-next/raevo/RaevoField.vue';
import SetupButton from './SetupButton.vue';
import SetupChips from './SetupChips.vue';
import SetupRow from './SetupRow.vue';

// Exceções de data: um dia fechado inteiro ou com outro horário. Não mexem na
// semana — é por isso que existem.
const props = defineProps({
  modelValue: { type: Array, default: () => [] },
  disabled: { type: Boolean, default: false },
});

const emit = defineEmits(['update:modelValue']);
const { t, locale } = useI18n();

const isAdding = ref(false);
const draft = ref({
  date: '',
  closed: true,
  from: '09:00',
  to: '11:00',
  note: '',
});

const formatDate = iso =>
  new Date(`${iso}T12:00:00`).toLocaleDateString(
    locale.value.replace('_', '-'),
    {
      day: 'numeric',
      month: 'long',
    }
  );

const describe = override => {
  if (override.closed) {
    return override.note
      ? t('CALENDAR_SETUP.SCHEDULES.EXCEPTION_CLOSED_NOTE', {
          note: override.note,
        })
      : t('CALENDAR_SETUP.SCHEDULES.EXCEPTION_CLOSED');
  }
  const ranges = (override.ranges || [])
    .map(range => `${range.from}–${range.to}`)
    .join(', ');
  const text = t('CALENDAR_SETUP.SCHEDULES.EXCEPTION_RANGES', { ranges });
  return override.note ? `${override.note} — ${text}` : text;
};

const remove = date =>
  emit(
    'update:modelValue',
    props.modelValue.filter(override => override.date !== date)
  );

const add = () => {
  if (!draft.value.date) return;
  const { date, closed, from, to, note } = draft.value;
  const entry = closed
    ? { date, closed: true, note: note || null }
    : { date, closed: false, note: note || null, ranges: [{ from, to }] };
  emit(
    'update:modelValue',
    [
      ...props.modelValue.filter(override => override.date !== date),
      entry,
    ].sort((a, b) => a.date.localeCompare(b.date))
  );
  isAdding.value = false;
  draft.value = {
    date: '',
    closed: true,
    from: '09:00',
    to: '11:00',
    note: '',
  };
};
</script>

<template>
  <div class="grid" data-testid="calendar-exceptions-editor">
    <SetupRow
      v-for="override in modelValue"
      :key="override.date"
      :title="formatDate(override.date)"
      :hint="describe(override)"
    >
      <SetupButton
        size="sm"
        :label="t('CALENDAR_SETUP.COMMON.REMOVE')"
        :disabled="disabled"
        @click="remove(override.date)"
      />
    </SetupRow>

    <div
      v-if="isAdding"
      class="mt-2.5 grid gap-3 rounded-lg border border-solid border-n-weak bg-n-surface-2 p-3"
      data-testid="calendar-exception-form"
    >
      <div class="grid gap-3 md:grid-cols-2">
        <RaevoField
          compact
          :label="t('CALENDAR_SETUP.SCHEDULES.EXCEPTION_DATE')"
        >
          <template #default="{ controlClass, fieldId }">
            <input
              :id="fieldId"
              v-model="draft.date"
              type="date"
              :class="controlClass"
              data-testid="calendar-exception-date"
            />
          </template>
        </RaevoField>
        <RaevoField
          compact
          :label="t('CALENDAR_SETUP.SCHEDULES.EXCEPTION_NOTE')"
        >
          <template #default="{ controlClass, fieldId }">
            <input
              :id="fieldId"
              v-model="draft.note"
              type="text"
              :class="controlClass"
              :placeholder="
                t('CALENDAR_SETUP.SCHEDULES.EXCEPTION_NOTE_PLACEHOLDER')
              "
            />
          </template>
        </RaevoField>
      </div>
      <SetupChips
        v-model="draft.closed"
        :label="t('CALENDAR_SETUP.SCHEDULES.EXCEPTION_KIND')"
        :options="[
          {
            value: true,
            label: t('CALENDAR_SETUP.SCHEDULES.EXCEPTION_KIND_CLOSED'),
          },
          {
            value: false,
            label: t('CALENDAR_SETUP.SCHEDULES.EXCEPTION_KIND_RANGE'),
          },
        ]"
      />
      <div v-if="!draft.closed" class="grid gap-3 md:grid-cols-2">
        <RaevoField compact :label="t('CALENDAR_SETUP.SCHEDULES.FROM')">
          <template #default="{ controlClass, fieldId }">
            <input
              :id="fieldId"
              v-model="draft.from"
              type="text"
              inputmode="numeric"
              maxlength="5"
              :class="controlClass"
            />
          </template>
        </RaevoField>
        <RaevoField compact :label="t('CALENDAR_SETUP.SCHEDULES.TO')">
          <template #default="{ controlClass, fieldId }">
            <input
              :id="fieldId"
              v-model="draft.to"
              type="text"
              inputmode="numeric"
              maxlength="5"
              :class="controlClass"
            />
          </template>
        </RaevoField>
      </div>
      <div class="flex justify-end gap-2">
        <SetupButton
          size="sm"
          :label="t('CALENDAR_SETUP.COMMON.CANCEL')"
          @click="isAdding = false"
        />
        <SetupButton
          size="sm"
          variant="primary"
          :label="t('CALENDAR_SETUP.SCHEDULES.ADD_EXCEPTION_CONFIRM')"
          :disabled="!draft.date"
          data-testid="calendar-exception-add"
          @click="add"
        />
      </div>
    </div>

    <div v-else class="mt-2.5">
      <SetupButton
        variant="dashed"
        :label="t('CALENDAR_SETUP.SCHEDULES.ADD_EXCEPTION')"
        :disabled="disabled"
        data-testid="calendar-exception-open"
        @click="isAdding = true"
      />
    </div>
  </div>
</template>
