<script setup>
import { computed, onBeforeUnmount, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import BookingAside from './components/BookingAside.vue';
import BookingDone from './components/BookingDone.vue';
import BookingForm from './components/BookingForm.vue';
import BookingMonth from './components/BookingMonth.vue';
import BookingSteps from './components/BookingSteps.vue';
import BookingTimes from './components/BookingTimes.vue';
import { formatMoney, monthKey, request } from './bookingApi';

// Página pública de agendamento em três passos, igual ao mockup aprovado:
// escolher horário → seus dados → confirmado. Com `bookingToken` abre a
// consulta do paciente (adicionar ao calendário, remarcar, cancelar).
const props = defineProps({
  bookingPageUrl: { type: String, default: '' },
  initialProcedureSlug: { type: String, default: '' },
  isPrivateBooking: { type: Boolean, default: false },
  bookingToken: { type: String, default: '' },
});

const { t, locale } = useI18n();
const bcp47 = computed(() => locale.value.replace('_', '-'));
const visitorTimezone = Intl.DateTimeFormat().resolvedOptions().timeZone;

const page = ref(null);
const procedure = ref(null);
const booking = ref(null);
const step = ref(1);
const rescheduling = ref(false);
const professionalId = ref('');
const month = ref(new Date(new Date().getFullYear(), new Date().getMonth(), 1));
const availableDays = ref([]);
const selectedDay = ref('');
const slots = ref([]);
const timezone = ref(visitorTimezone);
const hold = ref(null);
const pickingStartsAt = ref('');
const isLoading = ref(true);
const isLoadingMonth = ref(false);
const isLoadingSlots = ref(false);
const isSaving = ref(false);
const notice = ref('');
const secondsLeft = ref(null);
let countdown = null;
let polling = null;

const manageUrl = token => `/agendar/reserva/${token}`;
const procedureUrl = computed(() =>
  rescheduling.value
    ? manageUrl(booking.value.token)
    : `${props.bookingPageUrl}/${procedure.value?.slug}`
);

const clinic = computed(
  () => page.value?.clinic || booking.value?.clinic || {}
);
const clinicTimezone = computed(
  () => procedure.value?.timezone || booking.value?.timezone || visitorTimezone
);
const timezones = computed(() => [
  ...new Set([
    visitorTimezone,
    clinicTimezone.value,
    'America/Sao_Paulo',
    'America/Recife',
    'America/Manaus',
    'Europe/Lisbon',
  ]),
]);
const today = new Date(new Date().getFullYear(), new Date().getMonth(), 1);
const canGoBack = computed(() => month.value > today);

const heldResource = type =>
  hold.value?.resources?.find(resource => resource.type === type)?.name || '';
const asideProfessional = computed(() => {
  if (hold.value) return heldResource('user');
  const chosen = procedure.value?.professionals?.find(
    item => String(item.id) === professionalId.value
  );
  return (
    chosen?.name ||
    (procedure.value?.professionals?.length === 1
      ? procedure.value.professionals[0].name
      : '')
  );
});

const holdNote = computed(() => {
  if (!hold.value) return '';
  if (secondsLeft.value !== null && secondsLeft.value <= 60)
    return t('PUBLIC_BOOKING.HOLD_ENDING', { seconds: secondsLeft.value });
  return t('PUBLIC_BOOKING.HOLD_NOTE', {
    minutes: procedure.value?.payment?.hold_minutes || 10,
  });
});

const errorText = error => {
  if (error.code === 'slot_taken') return t('PUBLIC_BOOKING.ERRORS.SLOT_TAKEN');
  if (error.code === 'hold_expired')
    return t('PUBLIC_BOOKING.ERRORS.HOLD_EXPIRED');
  if (error.status === 429) return t('PUBLIC_BOOKING.ERRORS.TOO_MANY');
  if (error.code === 'payment_failed')
    return t('PUBLIC_BOOKING.ERRORS.PAYMENT_FAILED');
  return error.message || t('PUBLIC_BOOKING.REQUEST_ERROR');
};

const loadSlots = async day => {
  selectedDay.value = day;
  slots.value = [];
  isLoadingSlots.value = true;
  try {
    const query = new URLSearchParams({ date: day });
    if (professionalId.value)
      query.set('professional_id', professionalId.value);
    const payload = await request(
      `${procedureUrl.value}/disponibilidade.json?${query}`
    );
    slots.value = payload.slots || [];
  } catch (error) {
    notice.value = errorText(error);
  } finally {
    isLoadingSlots.value = false;
  }
};

const loadMonth = async ({ pickFirst = true, tries = 2 } = {}) => {
  isLoadingMonth.value = true;
  try {
    const query = new URLSearchParams({ month: monthKey(month.value) });
    if (professionalId.value)
      query.set('professional_id', professionalId.value);
    const payload = await request(
      `${procedureUrl.value}/disponibilidade.json?${query}`
    );
    availableDays.value = payload.days || [];
    if (!availableDays.value.length && tries > 1) {
      month.value = new Date(
        month.value.getFullYear(),
        month.value.getMonth() + 1,
        1
      );
      await loadMonth({ pickFirst, tries: tries - 1 });
      return;
    }
    if (pickFirst && availableDays.value.length)
      await loadSlots(availableDays.value[0]);
    else if (!availableDays.value.includes(selectedDay.value)) {
      selectedDay.value = '';
      slots.value = [];
    }
  } catch (error) {
    notice.value = errorText(error);
  } finally {
    isLoadingMonth.value = false;
  }
};

const changeMonth = offset => {
  month.value = new Date(
    month.value.getFullYear(),
    month.value.getMonth() + offset,
    1
  );
  loadMonth({ pickFirst: false, tries: 1 });
};

const loadProcedure = async slug => {
  notice.value = '';
  procedure.value = await request(`${props.bookingPageUrl}/${slug}.json`);
  professionalId.value = '';
  month.value = new Date(today);
  await loadMonth();
};

const stopCountdown = () => {
  clearInterval(countdown);
  secondsLeft.value = null;
};

const startCountdown = () => {
  stopCountdown();
  countdown = setInterval(() => {
    const left = Math.round(
      (new Date(hold.value.expires_at) - new Date()) / 1000
    );
    secondsLeft.value = Math.max(left, 0);
    if (left <= 0) {
      stopCountdown();
      hold.value = null;
      step.value = 1;
      notice.value = t('PUBLIC_BOOKING.ERRORS.HOLD_EXPIRED');
      loadSlots(selectedDay.value);
    }
  }, 1000);
};

const startPolling = () => {
  clearInterval(polling);
  polling = setInterval(async () => {
    const payload = await request(
      `${manageUrl(booking.value.token)}.json`
    ).catch(() => null);
    if (!payload) return;
    booking.value = payload;
    if (payload.status !== 'awaiting_payment') clearInterval(polling);
  }, 5000);
};

const showBooking = payload => {
  booking.value = payload;
  step.value = 3;
  rescheduling.value = false;
  if (payload.status === 'awaiting_payment') startPolling();
};

const pick = async slot => {
  notice.value = '';
  pickingStartsAt.value = slot.starts_at;
  try {
    hold.value = await request(`${procedureUrl.value}/vaga.json`, {
      method: 'POST',
      body: {
        starts_at: slot.starts_at,
        timezone: timezone.value,
        professional_id: professionalId.value || undefined,
      },
    });
    if (rescheduling.value) {
      const payload = await request(
        `${manageUrl(booking.value.token)}/remarcar.json`,
        {
          method: 'POST',
          body: { hold_token: hold.value.token },
        }
      );
      hold.value = null;
      showBooking(payload);
      return;
    }
    step.value = 2;
    startCountdown();
  } catch (error) {
    notice.value = errorText(error);
    loadSlots(selectedDay.value);
  } finally {
    pickingStartsAt.value = '';
  }
};

const back = () => {
  stopCountdown();
  hold.value = null;
  step.value = 1;
  loadSlots(selectedDay.value);
};

const confirm = async form => {
  isSaving.value = true;
  notice.value = '';
  const { answers } = form;
  const phone = String(answers.whatsapp || '').replace(/\D/g, '');
  try {
    const payload = await request(
      `${procedureUrl.value}/vaga/${hold.value.token}/confirmar.json`,
      {
        method: 'POST',
        body: {
          booking: {
            name: answers.full_name,
            phone_number: phone ? `+55${phone}` : '',
            email: answers.email || '',
            cpf: answers.cpf || '',
            notes: answers.notes || '',
            custom_attributes: Object.fromEntries(
              Object.entries(answers).filter(
                ([key]) =>
                  !['full_name', 'whatsapp', 'email', 'notes'].includes(key)
              )
            ),
            timezone: timezone.value,
            payment_method: form.paymentMethod,
            consent: form.consent,
            website: form.website,
            captcha_token: form.captchaToken,
          },
        },
      }
    );
    stopCountdown();
    hold.value = null;
    showBooking(payload);
  } catch (error) {
    notice.value = errorText(error);
    if (['hold_expired', 'slot_taken'].includes(error.code)) back();
  } finally {
    isSaving.value = false;
  }
};

const startReschedule = async () => {
  rescheduling.value = true;
  step.value = 1;
  procedure.value = {
    title: booking.value.procedure.title,
    duration_minutes: booking.value.procedure.duration_minutes,
    location_type: booking.value.procedure.location_type,
    payment: { enabled: false },
    professionals: [],
    timezone: booking.value.timezone,
  };
  month.value = new Date(today);
  await loadMonth();
};

const cancelBooking = async reason => {
  isSaving.value = true;
  try {
    booking.value = await request(
      `${manageUrl(booking.value.token)}/cancelar.json`,
      { method: 'POST', body: { reason } }
    );
  } catch (error) {
    notice.value = errorText(error);
  } finally {
    isSaving.value = false;
  }
};

const chooseProfessional = id => {
  professionalId.value = id;
  loadMonth();
};

onMounted(async () => {
  try {
    if (props.bookingToken) {
      showBooking(await request(`${manageUrl(props.bookingToken)}.json`));
      return;
    }
    page.value = await request(`${props.bookingPageUrl}.json`);
    locale.value = page.value.locale === 'pt' ? 'pt' : 'pt_BR';
    if (props.isPrivateBooking && page.value.procedure) {
      procedure.value = page.value.procedure;
      await loadMonth();
      return;
    }
    const slug = props.initialProcedureSlug || page.value.procedures[0]?.slug;
    if (slug) await loadProcedure(slug);
  } catch (error) {
    notice.value = errorText(error);
  } finally {
    isLoading.value = false;
  }
});

onBeforeUnmount(() => {
  stopCountdown();
  clearInterval(polling);
});
</script>

<template>
  <div class="raevo-compact min-h-screen bg-n-background px-4 py-8 sm:px-5">
    <div class="mx-auto max-w-[1120px]">
      <section
        class="overflow-hidden rounded-2xl border border-solid border-n-strong bg-n-solid-1"
        :aria-busy="isLoading ? 'true' : 'false'"
      >
        <p
          v-if="isLoading"
          class="mb-0 p-8 text-center text-sm text-n-slate-11"
        >
          {{ t('PUBLIC_BOOKING.LOADING') }}
        </p>

        <section
          v-else-if="!procedure && !booking"
          data-testid="public-booking-empty-procedures"
          class="p-8 text-center"
        >
          <p class="mb-0 text-sm text-n-slate-11">
            {{ notice || t('PUBLIC_BOOKING.NO_PROCEDURES') }}
          </p>
        </section>

        <BookingDone
          v-else-if="step === 3 && booking"
          :booking="booking"
          :busy="isSaving"
          @reschedule="startReschedule"
          @cancel="cancelBooking"
        />

        <div
          v-else
          class="grid min-h-[520px]"
          :class="
            step === 1
              ? 'min-[900px]:grid-cols-[300px_minmax(0,1fr)_210px]'
              : 'min-[900px]:grid-cols-[300px_minmax(0,1fr)]'
          "
        >
          <BookingAside
            :clinic="clinic"
            :procedure="procedure"
            :professional-name="asideProfessional"
            :room-name="heldResource('room')"
            :starts-at="step === 2 ? hold?.starts_at : ''"
            :timezone="timezone"
            :note="
              holdNote ||
              (rescheduling ? t('PUBLIC_BOOKING.RESCHEDULE_NOTE') : '')
            "
          />

          <section class="grid min-w-0 content-start gap-3.5 p-5">
            <BookingSteps :current="step" />

            <p
              v-if="notice"
              class="mb-0 flex items-start gap-1.5 rounded-lg bg-n-ruby-3 px-3 py-2 text-ui text-n-ruby-11"
              role="alert"
              data-testid="public-booking-notice"
            >
              <i
                class="i-lucide-circle-alert mt-0.5 size-4 shrink-0"
                aria-hidden="true"
              />
              {{ notice }}
            </p>

            <template v-if="step === 1">
              <div
                v-if="!rescheduling && (page?.procedures?.length || 0) > 1"
                class="grid gap-2"
                role="group"
                :aria-label="t('PUBLIC_BOOKING.PROCEDURE')"
              >
                <button
                  v-for="item in page.procedures"
                  :key="item.slug"
                  type="button"
                  class="flex items-center justify-between gap-3 rounded-xl border border-solid px-[13px] py-[11px] text-left outline-none transition-colors focus-visible:ring-2 focus-visible:ring-n-brand/40"
                  :class="
                    procedure?.slug === item.slug
                      ? 'border-n-brand bg-n-brand/10'
                      : 'border-n-weak bg-n-solid-1 hover:border-n-strong'
                  "
                  :aria-pressed="
                    procedure?.slug === item.slug ? 'true' : 'false'
                  "
                  :data-testid="`public-booking-procedure-${item.slug}`"
                  @click="loadProcedure(item.slug)"
                >
                  <span class="grid">
                    <b class="text-sm font-semibold text-n-slate-12">{{
                      item.title
                    }}</b>
                    <small class="text-xs text-n-slate-10">
                      {{
                        t('PUBLIC_BOOKING.PROCEDURE_META', {
                          minutes: item.duration_minutes,
                          location: t(
                            `PUBLIC_BOOKING.LOCATIONS.${(item.location_type || 'in_person').toUpperCase()}`
                          ).toLowerCase(),
                        })
                      }}
                    </small>
                  </span>
                  <span
                    v-if="item.price_cents"
                    class="font-bold tabular-nums text-n-slate-12"
                  >
                    {{
                      formatMoney(item.price_cents, bcp47).replace(',00', '')
                    }}
                  </span>
                  <small v-else class="text-xs text-n-slate-10">{{
                    t('PUBLIC_BOOKING.FREE')
                  }}</small>
                </button>
              </div>

              <div
                v-if="(procedure?.professionals?.length || 0) > 1"
                class="flex flex-wrap items-center gap-1.5"
                role="group"
                :aria-label="t('PUBLIC_BOOKING.WITH_WHOM')"
              >
                <span class="mr-1 text-xs text-n-slate-11">{{
                  t('PUBLIC_BOOKING.WITH_WHOM')
                }}</span>
                <button
                  v-for="option in [
                    { id: '', name: t('PUBLIC_BOOKING.ANYONE') },
                    ...procedure.professionals,
                  ]"
                  :key="option.id"
                  type="button"
                  class="rounded-full border border-solid px-[11px] py-[5px] text-xs outline-none focus-visible:ring-2 focus-visible:ring-n-brand/40"
                  :class="
                    String(option.id) === professionalId
                      ? 'border-n-brand bg-n-brand/10 font-semibold text-n-brand'
                      : 'border-n-strong bg-n-solid-1 text-n-slate-11'
                  "
                  :aria-pressed="
                    String(option.id) === professionalId ? 'true' : 'false'
                  "
                  @click="chooseProfessional(String(option.id))"
                >
                  {{ option.name }}
                </button>
              </div>

              <BookingMonth
                :month="month"
                :available-days="availableDays"
                :selected-day="selectedDay"
                :loading="isLoadingMonth"
                :can-go-back="canGoBack"
                @select="loadSlots"
                @previous="changeMonth(-1)"
                @next="changeMonth(1)"
              />
            </template>

            <BookingForm
              v-else
              :questions="procedure.questions || []"
              :payment="procedure.payment || { enabled: false }"
              :procedure-title="procedure.title"
              :captcha-site-key="page?.captcha_site_key || ''"
              :saving="isSaving"
              @back="back"
              @submit="confirm"
            />
          </section>

          <BookingTimes
            v-if="step === 1"
            v-model:timezone="timezone"
            :day="selectedDay"
            :slots="slots"
            :timezones="timezones"
            :loading="isLoadingSlots"
            :busy-starts-at="pickingStartsAt"
            @pick="pick"
          />
        </div>
      </section>
    </div>
  </div>
</template>
