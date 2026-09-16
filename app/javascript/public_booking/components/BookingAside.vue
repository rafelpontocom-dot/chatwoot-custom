<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { formatMoney, formatShortMoment, timezoneLabel } from '../bookingApi';

// Quem a clínica é e o que se está a marcar — a coluna da esquerda do mockup.
const props = defineProps({
  clinic: { type: Object, default: () => ({}) },
  procedure: { type: Object, default: null },
  professionalName: { type: String, default: '' },
  roomName: { type: String, default: '' },
  startsAt: { type: String, default: '' },
  timezone: { type: String, default: '' },
  note: { type: String, default: '' },
});

const { t, locale } = useI18n();
const bcp47 = computed(() => locale.value.replace('_', '-'));

const showPrice = computed(() => props.procedure?.payment?.enabled);
const place = computed(() =>
  [
    t(
      `PUBLIC_BOOKING.LOCATIONS.${(props.procedure?.location_type || 'in_person').toUpperCase()}`
    ),
    props.roomName,
  ]
    .filter(Boolean)
    .join(' · ')
);
</script>

<template>
  <aside
    class="grid content-start gap-3.5 border-b border-solid border-n-weak bg-n-slate-2 p-5 min-[900px]:border-b-0 min-[900px]:border-r"
    data-testid="public-booking-aside"
  >
    <div class="flex items-center gap-2.5">
      <span
        class="grid size-10 shrink-0 place-items-center rounded-xl bg-n-brand text-sm font-bold text-white"
        aria-hidden="true"
      >
        {{ clinic.initials }}
      </span>
      <span class="grid min-w-0">
        <strong class="text-sm font-semibold text-n-slate-12">{{
          clinic.name
        }}</strong>
        <span v-if="clinic.address" class="text-xs text-n-slate-10">{{
          clinic.address
        }}</span>
      </span>
    </div>

    <h2
      v-if="procedure"
      class="mb-0 text-xl font-semibold tracking-tight text-n-slate-12"
    >
      {{ procedure.title }}
    </h2>

    <div v-if="procedure" class="grid gap-[7px] text-ui text-n-slate-11">
      <div class="flex items-start gap-2">
        <i
          class="i-lucide-clock mt-px size-4 shrink-0 text-n-slate-10"
          aria-hidden="true"
        />
        <span>{{
          t('PUBLIC_BOOKING.DURATION', { count: procedure.duration_minutes })
        }}</span>
      </div>
      <div v-if="startsAt" class="flex items-start gap-2">
        <i
          class="i-lucide-calendar mt-px size-4 shrink-0 text-n-slate-10"
          aria-hidden="true"
        />
        <span>
          <strong class="font-semibold text-n-slate-12">{{
            formatShortMoment(startsAt, timezone, bcp47)
          }}</strong>
          <br />
          <small class="text-xs">{{ timezoneLabel(timezone, bcp47) }}</small>
        </span>
      </div>
      <div v-if="professionalName" class="flex items-start gap-2">
        <i
          class="i-lucide-user-round mt-px size-4 shrink-0 text-n-slate-10"
          aria-hidden="true"
        />
        <span>{{
          startsAt && roomName
            ? `${professionalName} · ${roomName}`
            : professionalName
        }}</span>
      </div>
      <div v-if="!startsAt || !roomName" class="flex items-start gap-2">
        <i
          class="i-lucide-map-pin mt-px size-4 shrink-0 text-n-slate-10"
          aria-hidden="true"
        />
        <span>{{ place }}</span>
      </div>
      <div v-if="showPrice" class="flex items-start gap-2">
        <i
          class="i-lucide-credit-card mt-px size-4 shrink-0 text-n-slate-10"
          aria-hidden="true"
        />
        <span class="font-bold tabular-nums text-n-slate-12">
          {{
            formatMoney(
              procedure.payment.price_cents,
              bcp47,
              procedure.payment.currency
            )
          }}
        </span>
      </div>
    </div>

    <p
      v-if="note || procedure?.description"
      class="mb-0 border-t border-solid border-n-weak pt-3 text-xs leading-relaxed text-n-slate-10"
    >
      {{ note || procedure.description }}
    </p>
  </aside>
</template>
