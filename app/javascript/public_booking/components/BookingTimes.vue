<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { formatLongDay, formatTime, timezoneLabel } from '../bookingApi';

// Horários do dia e o fuso de quem marca — a coluna da direita do mockup.
defineProps({
  day: { type: String, default: '' },
  slots: { type: Array, default: () => [] },
  timezone: { type: String, required: true },
  timezones: { type: Array, required: true },
  loading: { type: Boolean, default: false },
  busyStartsAt: { type: String, default: '' },
});

const emit = defineEmits(['pick', 'update:timezone']);
const { t, locale } = useI18n();
const bcp47 = computed(() => locale.value.replace('_', '-'));
</script>

<template>
  <aside
    class="grid content-start gap-2 border-t border-solid border-n-weak px-4 py-5 min-[900px]:border-l min-[900px]:border-t-0"
    data-testid="public-booking-times"
  >
    <h3 class="mb-0 text-ui font-semibold text-n-slate-12">
      {{ day ? formatLongDay(day, bcp47) : t('PUBLIC_BOOKING.PICK_DAY') }}
    </h3>
    <p v-if="day" class="mb-1 text-xs text-n-slate-10" aria-live="polite">
      {{
        loading
          ? t('PUBLIC_BOOKING.LOADING_SLOTS')
          : t('PUBLIC_BOOKING.FREE_TIMES', slots.length, {
              count: slots.length,
            })
      }}
    </p>
    <button
      v-for="slot in slots"
      :key="slot.starts_at"
      type="button"
      class="block w-full rounded-lg border border-solid border-n-strong bg-n-solid-1 px-2.5 py-[9px] text-ui font-semibold tabular-nums text-n-slate-12 outline-none transition-colors hover:border-n-brand hover:text-n-brand focus-visible:ring-2 focus-visible:ring-n-brand/40 disabled:opacity-60"
      :class="
        busyStartsAt === slot.starts_at &&
        'border-n-brand bg-n-brand text-white hover:text-white'
      "
      :aria-pressed="busyStartsAt === slot.starts_at ? 'true' : 'false'"
      :disabled="Boolean(busyStartsAt)"
      data-testid="public-booking-slot"
      @click="emit('pick', slot)"
    >
      {{ formatTime(slot.starts_at, timezone, bcp47) }}
    </button>
    <label class="mt-1 flex items-center gap-1.5 text-xs text-n-slate-10">
      <i class="i-lucide-globe size-3.5 shrink-0" aria-hidden="true" />
      <select
        :value="timezone"
        :aria-label="t('PUBLIC_BOOKING.TIMEZONE')"
        class="reset-base mb-0 h-7 min-w-0 flex-1 appearance-none rounded-md border border-solid border-n-weak bg-n-solid-1 bg-none px-1.5 py-0 text-xs text-n-slate-11"
        data-testid="public-booking-timezone"
        @change="emit('update:timezone', $event.target.value)"
      >
        <option v-for="zone in timezones" :key="zone" :value="zone">
          {{ timezoneLabel(zone, bcp47) }}
        </option>
      </select>
    </label>
  </aside>
</template>
