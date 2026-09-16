<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import {
  formatLongDay,
  formatMoney,
  formatTime,
  gmtOffset,
} from '../bookingApi';

// Passo 3 e a página da consulta do paciente: o resumo, o estado do pagamento
// e o que ele ainda pode fazer sozinho.
const props = defineProps({
  booking: { type: Object, required: true },
  busy: { type: Boolean, default: false },
});

const emit = defineEmits(['reschedule', 'cancel']);
const { t, locale } = useI18n();
const bcp47 = computed(() => locale.value.replace('_', '-'));

const cancelling = ref(false);
const reason = ref('');
const reasonError = ref(false);

const zone = computed(() => props.booking.timezone);
const day = computed(() =>
  new Intl.DateTimeFormat('en-CA', { timeZone: zone.value }).format(
    new Date(props.booking.starts_at)
  )
);
const professional = computed(
  () => props.booking.resources.find(resource => resource.type === 'user')?.name
);
const room = computed(
  () => props.booking.resources.find(resource => resource.type === 'room')?.name
);

const headline = computed(() => {
  const when = t('PUBLIC_BOOKING.DONE.WHEN', {
    day: formatLongDay(day.value, bcp47.value),
    time: formatTime(props.booking.starts_at, zone.value, bcp47.value),
  });
  const withWho = [
    professional.value &&
      t('PUBLIC_BOOKING.DONE.WITH', { name: professional.value }),
    room.value && t('PUBLIC_BOOKING.DONE.IN', { room: room.value }),
  ]
    .filter(Boolean)
    .join(', ');
  return withWho ? `${when}, ${withWho}.` : `${when}.`;
});

const paymentLine = computed(() => {
  const payment = props.booking.payment;
  if (!payment) return '';
  if (payment.method === 'on_site')
    return t('PUBLIC_BOOKING.DONE.PAY_AT_CLINIC');
  const amount = formatMoney(
    payment.amount_cents,
    bcp47.value,
    payment.currency
  );
  if (props.booking.status === 'awaiting_payment')
    return t('PUBLIC_BOOKING.DONE.PAYMENT_PENDING', { amount });
  return t('PUBLIC_BOOKING.DONE.PAID', {
    method: t(`PUBLIC_BOOKING.METHODS.${payment.method.toUpperCase()}`),
    amount,
  });
});

const icsUrl = computed(
  () => `/agendar/reserva/${props.booking.token}/calendario`
);

const confirmCancel = () => {
  reasonError.value =
    props.booking.cancel_reason_required && !reason.value.trim();
  if (!reasonError.value) emit('cancel', reason.value.trim());
};
</script>

<template>
  <div
    class="grid place-items-center gap-2.5 px-5 py-12 text-center"
    data-testid="public-booking-done"
  >
    <span
      class="grid size-[46px] place-items-center rounded-full"
      :class="{
        'bg-n-teal-3 text-n-teal-11': booking.status === 'confirmed',
        'bg-n-amber-3 text-n-amber-11': booking.status === 'awaiting_payment',
        'bg-n-slate-3 text-n-slate-11': booking.status === 'canceled',
      }"
      aria-hidden="true"
    >
      <i
        :class="{
          'i-lucide-check': booking.status === 'confirmed',
          'i-lucide-hourglass': booking.status === 'awaiting_payment',
          'i-lucide-calendar-x': booking.status === 'canceled',
        }"
        class="size-6"
      />
    </span>
    <h2
      class="mb-0 text-xl font-semibold text-n-slate-12"
      data-testid="public-booking-done-title"
    >
      {{ t(`PUBLIC_BOOKING.DONE.TITLES.${booking.status.toUpperCase()}`) }}
    </h2>
    <p class="mb-0 max-w-[46ch] text-sm text-n-slate-11">
      {{ headline }}
      <template v-if="booking.status === 'confirmed'">
        {{ t('PUBLIC_BOOKING.DONE.WHATSAPP_SENT') }}
      </template>
      <template v-if="booking.status === 'awaiting_payment'">
        {{ t('PUBLIC_BOOKING.DONE.AWAITING') }}
      </template>
    </p>

    <div
      class="grid w-full max-w-[420px] gap-1.5 rounded-xl border border-solid border-n-weak bg-n-surface-2 p-3 text-left text-ui text-n-slate-12"
    >
      <div class="flex gap-2">
        <i
          class="i-lucide-calendar mt-0.5 size-4 shrink-0 text-n-slate-10"
          aria-hidden="true"
        />
        <span>
          {{ formatLongDay(day, bcp47) }} ·
          {{ formatTime(booking.starts_at, zone, bcp47) }} —
          {{ formatTime(booking.ends_at, zone, bcp47) }} ({{
            gmtOffset(zone, bcp47)
          }})
        </span>
      </div>
      <div class="flex gap-2">
        <i
          class="i-lucide-map-pin mt-0.5 size-4 shrink-0 text-n-slate-10"
          aria-hidden="true"
        />
        <span>{{
          [booking.clinic.name, booking.clinic.address]
            .filter(Boolean)
            .join(' · ')
        }}</span>
      </div>
      <div v-if="paymentLine" class="flex gap-2">
        <i
          class="i-lucide-credit-card mt-0.5 size-4 shrink-0 text-n-slate-10"
          aria-hidden="true"
        />
        <span>{{ paymentLine }}</span>
      </div>
    </div>

    <div
      v-if="!cancelling || booking.status === 'canceled'"
      class="flex flex-wrap justify-center gap-2"
    >
      <a
        v-if="
          booking.status === 'awaiting_payment' && booking.payment?.invoice_url
        "
        :href="booking.payment.invoice_url"
        target="_blank"
        rel="noopener noreferrer"
        class="rounded-full border border-solid border-n-brand bg-n-brand px-4 py-[9px] text-ui font-semibold text-white no-underline outline-none focus-visible:ring-2 focus-visible:ring-n-brand/40"
        data-testid="public-booking-open-payment"
      >
        {{ t('PUBLIC_BOOKING.DONE.OPEN_PAYMENT') }}
      </a>
      <a
        v-if="booking.status !== 'canceled'"
        :href="icsUrl"
        class="rounded-full border border-solid border-n-strong bg-n-solid-1 px-4 py-[9px] text-ui font-semibold text-n-slate-11 no-underline outline-none hover:text-n-slate-12 focus-visible:ring-2 focus-visible:ring-n-brand/40"
        data-testid="public-booking-ics"
      >
        {{ t('PUBLIC_BOOKING.DONE.ADD_TO_CALENDAR') }}
      </a>
      <button
        v-if="booking.can_reschedule"
        type="button"
        class="rounded-full border border-solid border-n-strong bg-n-solid-1 px-4 py-[9px] text-ui font-semibold text-n-slate-11 outline-none hover:text-n-slate-12 focus-visible:ring-2 focus-visible:ring-n-brand/40"
        :disabled="busy"
        data-testid="public-booking-reschedule"
        @click="emit('reschedule')"
      >
        {{ t('PUBLIC_BOOKING.DONE.RESCHEDULE') }}
      </button>
      <button
        v-if="booking.can_cancel"
        type="button"
        class="rounded-full border border-solid border-transparent bg-transparent px-4 py-[9px] text-ui font-semibold text-n-ruby-11 outline-none hover:underline focus-visible:ring-2 focus-visible:ring-n-brand/40"
        :disabled="busy"
        data-testid="public-booking-cancel"
        @click="cancelling = true"
      >
        {{ t('PUBLIC_BOOKING.DONE.CANCEL') }}
      </button>
    </div>

    <div
      v-else
      class="grid w-full max-w-[420px] gap-2 text-left"
      data-testid="public-booking-cancel-form"
    >
      <label class="grid gap-1.5 text-xs font-medium text-n-slate-11">
        {{
          booking.cancel_reason_required
            ? t('PUBLIC_BOOKING.DONE.REASON_REQUIRED')
            : t('PUBLIC_BOOKING.DONE.REASON_OPTIONAL')
        }}
        <textarea
          v-model="reason"
          rows="2"
          class="reset-base mb-0 min-h-16 rounded-lg border border-solid border-n-strong bg-n-solid-1 px-3 py-2 text-ui text-n-slate-12 outline-none focus:border-n-brand focus:ring-2 focus:ring-n-brand/20"
          :aria-invalid="reasonError ? 'true' : undefined"
          data-testid="public-booking-cancel-reason"
        />
      </label>
      <p v-if="reasonError" class="mb-0 text-xs text-n-ruby-11" role="alert">
        {{ t('PUBLIC_BOOKING.ERRORS.REASON') }}
      </p>
      <div class="flex justify-end gap-2">
        <button
          type="button"
          class="rounded-full border border-solid border-n-strong bg-n-solid-1 px-4 py-[9px] text-ui font-semibold text-n-slate-11 outline-none focus-visible:ring-2 focus-visible:ring-n-brand/40"
          @click="cancelling = false"
        >
          {{ t('PUBLIC_BOOKING.BACK') }}
        </button>
        <button
          type="button"
          class="rounded-full border border-solid border-n-ruby-9 bg-n-ruby-9 px-4 py-[9px] text-ui font-semibold text-white outline-none focus-visible:ring-2 focus-visible:ring-n-brand/40 disabled:opacity-60"
          :disabled="busy"
          data-testid="public-booking-cancel-confirm"
          @click="confirmCancel"
        >
          {{ t('PUBLIC_BOOKING.DONE.CONFIRM_CANCEL') }}
        </button>
      </div>
    </div>
  </div>
</template>
