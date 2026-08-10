<script setup>
import {
  computed,
  nextTick,
  onMounted,
  onBeforeUnmount,
  ref,
  watch,
} from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  bookingPageUrl: { type: String, required: true },
  initialProcedureSlug: { type: String, default: '' },
  isPrivateBooking: { type: Boolean, default: false },
});
const { locale, t } = useI18n();

const page = ref(null);
const procedure = ref(null);
const selectedResourceId = ref('');
const selectedDate = ref('');
const slots = ref([]);
const selectedSlot = ref('');
const isLoading = ref(true);
const isLoadingSlots = ref(false);
const isSaving = ref(false);
const isComplete = ref(false);
const error = ref('');
const turnstileContainer = ref(null);
let turnstileWidgetId = null;
const form = ref({
  name: '',
  email: '',
  phoneNumber: '',
  consent: false,
  website: '',
  captchaToken: '',
  customAttributes: {},
});

const procedureUrl = computed(() =>
  procedure.value ? `${props.bookingPageUrl}/${procedure.value.slug}` : ''
);
const canSubmit = computed(
  () =>
    form.value.name.trim() &&
    (form.value.email.trim() || form.value.phoneNumber.trim()) &&
    selectedResourceId.value &&
    selectedSlot.value &&
    form.value.consent &&
    (!page.value?.captcha_site_key || form.value.captchaToken) &&
    !isSaving.value
);

const loadTurnstile = () => {
  if (window.turnstile) return Promise.resolve(window.turnstile);

  return new Promise((resolve, reject) => {
    const existing = document.querySelector('[data-raevo-turnstile]');
    if (existing) {
      existing.addEventListener('load', () => resolve(window.turnstile), {
        once: true,
      });
      existing.addEventListener('error', reject, { once: true });
      return;
    }

    const script = document.createElement('script');
    script.src =
      'https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit';
    script.async = true;
    script.defer = true;
    script.dataset.raevoTurnstile = 'true';
    script.addEventListener('load', () => resolve(window.turnstile), {
      once: true,
    });
    script.addEventListener('error', reject, { once: true });
    document.head.append(script);
  });
};

const renderCaptcha = async () => {
  if (!page.value?.captcha_site_key || !turnstileContainer.value) return;

  try {
    const turnstile = await loadTurnstile();
    turnstileWidgetId = turnstile.render(turnstileContainer.value, {
      sitekey: page.value.captcha_site_key,
      callback: token => {
        form.value.captchaToken = token;
      },
      'expired-callback': () => {
        form.value.captchaToken = '';
      },
    });
  } catch (captchaError) {
    error.value = captchaError.message;
  }
};
const formatTime = value =>
  new Intl.DateTimeFormat(locale.value.replace('_', '-'), {
    hour: '2-digit',
    minute: '2-digit',
  }).format(new Date(value));

const request = async (url, options = {}) => {
  const response = await fetch(url, {
    headers: { Accept: 'application/json', ...options.headers },
    ...options,
  });
  const payload = await response.json();
  if (!response.ok) {
    throw new Error(payload.message || t('PUBLIC_BOOKING.REQUEST_ERROR'));
  }

  return payload;
};

const loadProcedure = async slug => {
  error.value = '';
  isLoading.value = true;
  try {
    procedure.value = await request(`${props.bookingPageUrl}/${slug}.json`);
    selectedResourceId.value = String(procedure.value.resources[0]?.id || '');
    selectedSlot.value = '';
    slots.value = [];
  } catch (loadError) {
    error.value = loadError.message;
  } finally {
    isLoading.value = false;
  }
};

const loadPage = async () => {
  try {
    page.value = await request(`${props.bookingPageUrl}.json`);
    locale.value = page.value.locale === 'pt' ? 'pt' : 'pt_BR';
    if (props.isPrivateBooking && page.value.procedure) {
      procedure.value = page.value.procedure;
      selectedResourceId.value = String(procedure.value.resources[0]?.id || '');
      isLoading.value = false;
      await nextTick();
      renderCaptcha();
      return;
    }
    const initialSlug =
      props.initialProcedureSlug || page.value.procedures[0]?.slug;
    if (initialSlug) await loadProcedure(initialSlug);
    else isLoading.value = false;
    await nextTick();
    renderCaptcha();
  } catch (loadError) {
    error.value = loadError.message;
    isLoading.value = false;
  }
};

const loadSlots = async () => {
  selectedSlot.value = '';
  slots.value = [];
  if (!selectedDate.value || !selectedResourceId.value || !procedure.value)
    return;

  isLoadingSlots.value = true;
  error.value = '';
  try {
    const query = new URLSearchParams({
      date: selectedDate.value,
      resource_id: selectedResourceId.value,
    });
    const payload = await request(
      `${procedureUrl.value}/disponibilidade.json?${query}`
    );
    slots.value = payload.slots || [];
  } catch (loadError) {
    error.value = loadError.message;
  } finally {
    isLoadingSlots.value = false;
  }
};

const submit = async () => {
  if (!canSubmit.value) return;

  isSaving.value = true;
  error.value = '';
  try {
    await request(`${procedureUrl.value}/reservas.json`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        booking: {
          name: form.value.name.trim(),
          email: form.value.email.trim(),
          phone_number: form.value.phoneNumber.trim(),
          custom_attributes: form.value.customAttributes,
          resource_ids: [Number(selectedResourceId.value)],
          starts_at: selectedSlot.value,
          timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
          consent: form.value.consent,
          website: form.value.website,
          captcha_token: form.value.captchaToken,
        },
      }),
    });
    isComplete.value = true;
  } catch (saveError) {
    error.value = saveError.message;
  } finally {
    isSaving.value = false;
  }
};

watch([selectedDate, selectedResourceId], loadSlots);
onMounted(loadPage);
onBeforeUnmount(() => {
  if (turnstileWidgetId !== null && window.turnstile) {
    window.turnstile.remove(turnstileWidgetId);
  }
});
</script>

<template>
  <main class="mx-auto min-h-screen max-w-3xl px-4 py-10 sm:px-6 sm:py-16">
    <section
      class="grid gap-8 rounded-xl border border-n-weak bg-n-surface-1 p-5 shadow-sm sm:p-8"
    >
      <header class="grid gap-2 border-b border-n-weak pb-6">
        <p
          class="mb-0 text-xs font-semibold uppercase tracking-wide text-n-brand"
        >
          {{ $t('PUBLIC_BOOKING.EYEBROW') }}
        </p>
        <h1 class="m-0 text-2xl font-semibold text-n-slate-12 sm:text-3xl">
          {{ page?.title || $t('PUBLIC_BOOKING.DEFAULT_TITLE') }}
        </h1>
        <p v-if="page?.description" class="mb-0 text-sm text-n-slate-11">
          {{ page.description }}
        </p>
      </header>

      <p v-if="isLoading" class="mb-0 text-sm text-n-slate-11">
        {{ $t('PUBLIC_BOOKING.LOADING') }}
      </p>
      <p
        v-else-if="error"
        class="mb-0 rounded-md bg-n-ruby-3 px-3 py-2 text-sm text-n-ruby-11"
        role="alert"
      >
        {{ error }}
      </p>

      <template v-else-if="isComplete">
        <section class="grid gap-2 rounded-lg bg-n-teal-3 p-5 text-center">
          <h2 class="m-0 text-lg font-semibold text-n-slate-12">
            {{ $t('PUBLIC_BOOKING.CONFIRMED') }}
          </h2>
          <p class="mb-0 text-sm text-n-slate-11">
            {{ $t('PUBLIC_BOOKING.CONFIRMED_DESCRIPTION') }}
          </p>
        </section>
      </template>

      <section
        v-else-if="!procedure"
        data-testid="public-booking-empty-procedures"
        class="rounded-lg border border-n-weak bg-n-surface-2 p-5 text-center"
      >
        <p class="mb-0 text-sm text-n-slate-11">
          {{ $t('PUBLIC_BOOKING.NO_PROCEDURES') }}
        </p>
      </section>

      <form v-else class="grid gap-6" @submit.prevent="submit">
        <fieldset class="grid gap-3">
          <legend class="text-sm font-semibold text-n-slate-12">
            {{ $t('PUBLIC_BOOKING.PROCEDURE') }}
          </legend>
          <div class="grid gap-2 sm:grid-cols-2">
            <button
              v-for="item in page?.procedures || []"
              :key="item.slug"
              type="button"
              class="grid gap-1 rounded-lg border p-3 text-left outline-none focus:ring-2 focus:ring-n-brand/40"
              :class="
                procedure?.slug === item.slug
                  ? 'border-n-brand bg-n-brand/5'
                  : 'border-n-weak bg-n-surface-2'
              "
              @click="loadProcedure(item.slug)"
            >
              <span class="text-sm font-semibold text-n-slate-12">{{
                item.title
              }}</span>
              <span class="text-xs text-n-slate-11">
                {{
                  $t('PUBLIC_BOOKING.MINUTES', { value: item.duration_minutes })
                }}
              </span>
            </button>
          </div>
        </fieldset>

        <fieldset v-if="procedure" class="grid gap-3">
          <legend class="text-sm font-semibold text-n-slate-12">
            {{ $t('PUBLIC_BOOKING.TIME') }}
          </legend>
          <div class="grid gap-3 sm:grid-cols-2">
            <label class="grid gap-1.5 text-sm font-medium text-n-slate-12">
              {{ $t('PUBLIC_BOOKING.RESOURCE') }}
              <select
                v-model="selectedResourceId"
                class="h-10 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm outline-none focus:border-n-brand focus:ring-2 focus:ring-n-brand/20"
              >
                <option
                  v-for="resource in procedure.resources"
                  :key="resource.id"
                  :value="String(resource.id)"
                >
                  {{ resource.name }}
                </option>
              </select>
            </label>
            <label class="grid gap-1.5 text-sm font-medium text-n-slate-12">
              {{ $t('PUBLIC_BOOKING.DATE') }}
              <input
                v-model="selectedDate"
                type="date"
                class="h-10 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm outline-none focus:border-n-brand focus:ring-2 focus:ring-n-brand/20"
              />
            </label>
          </div>
          <div
            v-for="field in page?.public_form_fields || []"
            :key="field.key"
            class="grid gap-1.5 text-sm font-medium text-n-slate-12"
          >
            <label :for="`public-field-${field.key}`">{{ field.label }}</label>
            <select
              v-if="field.kind === 'select'"
              :id="`public-field-${field.key}`"
              v-model="form.customAttributes[field.key]"
              :required="field.required"
              class="h-10 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm outline-none focus:border-n-brand focus:ring-2 focus:ring-n-brand/20"
            >
              <option value="" />
              <option
                v-for="option in field.options || []"
                :key="option"
                :value="option"
              >
                {{ option }}
              </option>
            </select>
            <input
              v-else
              :id="`public-field-${field.key}`"
              v-model="form.customAttributes[field.key]"
              :required="field.required"
              :type="field.kind === 'date' ? 'date' : 'text'"
              class="h-10 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm outline-none focus:border-n-brand focus:ring-2 focus:ring-n-brand/20"
            />
          </div>
          <p v-if="isLoadingSlots" class="mb-0 text-sm text-n-slate-11">
            {{ $t('PUBLIC_BOOKING.LOADING_SLOTS') }}
          </p>
          <div v-else-if="selectedDate" class="flex flex-wrap gap-2">
            <button
              v-for="slot in slots"
              :key="slot"
              type="button"
              class="rounded-md border px-3 py-2 text-sm font-medium outline-none focus:ring-2 focus:ring-n-brand/40"
              :class="
                selectedSlot === slot
                  ? 'border-n-brand bg-n-brand text-white'
                  : 'border-n-weak bg-n-surface-1 text-n-slate-12'
              "
              @click="selectedSlot = slot"
            >
              {{ formatTime(slot) }}
            </button>
            <p v-if="!slots.length" class="mb-0 text-sm text-n-slate-11">
              {{ $t('PUBLIC_BOOKING.NO_SLOTS') }}
            </p>
          </div>
        </fieldset>

        <fieldset class="grid gap-3">
          <legend class="text-sm font-semibold text-n-slate-12">
            {{ $t('PUBLIC_BOOKING.CONTACT') }}
          </legend>
          <div class="grid gap-3 sm:grid-cols-2">
            <label class="grid gap-1.5 text-sm font-medium text-n-slate-12">
              {{ $t('PUBLIC_BOOKING.NAME') }}
              <input
                v-model="form.name"
                required
                type="text"
                class="h-10 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm outline-none focus:border-n-brand focus:ring-2 focus:ring-n-brand/20"
              />
            </label>
            <label class="grid gap-1.5 text-sm font-medium text-n-slate-12">
              {{ $t('PUBLIC_BOOKING.PHONE') }}
              <input
                v-model="form.phoneNumber"
                type="tel"
                class="h-10 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm outline-none focus:border-n-brand focus:ring-2 focus:ring-n-brand/20"
              />
            </label>
            <label
              class="grid gap-1.5 text-sm font-medium text-n-slate-12 sm:col-span-2"
            >
              {{ $t('PUBLIC_BOOKING.EMAIL') }}
              <input
                v-model="form.email"
                type="email"
                class="h-10 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm outline-none focus:border-n-brand focus:ring-2 focus:ring-n-brand/20"
              />
            </label>
          </div>
          <input
            v-model="form.website"
            tabindex="-1"
            autocomplete="off"
            aria-hidden="true"
            class="hidden"
          />
          <div
            v-if="page?.captcha_site_key"
            ref="turnstileContainer"
            class="min-h-16"
          />
          <label class="flex items-start gap-2 text-sm text-n-slate-11">
            <input
              v-model="form.consent"
              type="checkbox"
              class="mt-0.5 size-4 rounded border-n-weak text-n-brand focus:ring-n-brand"
            />
            {{ $t('PUBLIC_BOOKING.CONSENT') }}
          </label>
        </fieldset>

        <button
          type="submit"
          :disabled="!canSubmit"
          class="h-11 rounded-md bg-n-brand px-4 text-sm font-semibold text-white outline-none transition hover:opacity-90 focus:ring-2 focus:ring-n-brand/40 disabled:cursor-not-allowed disabled:opacity-50"
        >
          {{
            isSaving
              ? $t('PUBLIC_BOOKING.CONFIRMING')
              : $t('PUBLIC_BOOKING.CONFIRM')
          }}
        </button>
      </form>
    </section>
  </main>
</template>
