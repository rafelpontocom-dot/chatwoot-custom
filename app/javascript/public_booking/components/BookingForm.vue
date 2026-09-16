<script setup>
import { computed, onBeforeUnmount, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import RaevoField from 'dashboard/components-next/raevo/RaevoField.vue';
import { formatMoney } from '../bookingApi';

// Passo 2: as perguntas do procedimento, na ordem configurada, e a cobrança.
const props = defineProps({
  questions: { type: Array, default: () => [] },
  payment: { type: Object, default: () => ({ enabled: false }) },
  procedureTitle: { type: String, default: '' },
  saving: { type: Boolean, default: false },
  captchaSiteKey: { type: String, default: '' },
});

const emit = defineEmits(['back', 'submit']);
const { t, locale } = useI18n();
const bcp47 = computed(() => locale.value.replace('_', '-'));

const answers = ref(
  Object.fromEntries(props.questions.map(question => [question.key, '']))
);
const paymentMethod = ref(
  props.payment.enabled ? props.payment.methods[0] : 'on_site'
);
const consent = ref(false);
const website = ref('');
const captchaToken = ref('');
const tried = ref(false);
const turnstileContainer = ref(null);
let turnstileWidgetId = null;

const onlyDigits = value => String(value || '').replace(/\D/g, '');

const maskCpf = value => {
  const digits = onlyDigits(value).slice(0, 11);
  return digits
    .replace(/^(\d{3})(\d)/, '$1.$2')
    .replace(/^(\d{3})\.(\d{3})(\d)/, '$1.$2.$3')
    .replace(/\.(\d{3})(\d)/, '.$1-$2');
};

const maskPhone = value => {
  const digits = onlyDigits(value).slice(0, 11);
  if (digits.length <= 2) return digits ? `(${digits}` : '';
  if (digits.length <= 7) return `(${digits.slice(0, 2)}) ${digits.slice(2)}`;
  return `(${digits.slice(0, 2)}) ${digits.slice(2, digits.length - 4)}-${digits.slice(-4)}`;
};

const validCpf = value => {
  const digits = onlyDigits(value);
  if (digits.length !== 11 || /^(\d)\1+$/.test(digits)) return false;
  const check = length => {
    const sum = digits
      .slice(0, length)
      .split('')
      .reduce(
        (total, digit, index) => total + Number(digit) * (length + 1 - index),
        0
      );
    const rest = (sum * 10) % 11;
    return (rest === 10 ? 0 : rest) === Number(digits[length]);
  };
  return check(9) && check(10);
};

const onInput = (question, value) => {
  if (question.kind === 'cpf') answers.value[question.key] = maskCpf(value);
  else if (question.kind === 'phone')
    answers.value[question.key] = maskPhone(value);
  else answers.value[question.key] = value;
};

const errorFor = question => {
  if (!tried.value) return '';
  const value = String(answers.value[question.key] || '').trim();
  if (question.required && !value) return t('PUBLIC_BOOKING.ERRORS.REQUIRED');
  if (value && question.kind === 'cpf' && !validCpf(value))
    return t('PUBLIC_BOOKING.ERRORS.CPF');
  if (value && question.kind === 'phone' && onlyDigits(value).length < 10)
    return t('PUBLIC_BOOKING.ERRORS.PHONE');
  if (value && question.kind === 'email' && !/^\S+@\S+\.\S+$/.test(value))
    return t('PUBLIC_BOOKING.ERRORS.EMAIL');
  return '';
};

// Campos curtos lado a lado, dois a dois; texto livre ocupa a linha inteira.
const rows = computed(() => {
  const result = [];
  props.questions.forEach(question => {
    const last = result[result.length - 1];
    if (
      question.kind !== 'textarea' &&
      last &&
      last.length === 1 &&
      last[0].kind !== 'textarea'
    )
      last.push(question);
    else result.push([question]);
  });
  return result;
});

const variantOf = question =>
  ['textarea', 'select'].includes(question.kind) ? question.kind : 'input';

const online = computed(
  () => props.payment.enabled && paymentMethod.value !== 'on_site'
);
const submitLabel = computed(() =>
  online.value
    ? t('PUBLIC_BOOKING.PAY_AND_CONFIRM')
    : t('PUBLIC_BOOKING.CONFIRM')
);

const submit = () => {
  tried.value = true;
  const invalid = props.questions.some(question => errorFor(question));
  if (
    invalid ||
    !consent.value ||
    (props.captchaSiteKey && !captchaToken.value)
  )
    return;
  emit('submit', {
    answers: answers.value,
    paymentMethod: paymentMethod.value,
    consent: consent.value,
    website: website.value,
    captchaToken: captchaToken.value,
  });
};

const loadTurnstile = () =>
  window.turnstile
    ? Promise.resolve(window.turnstile)
    : new Promise((resolve, reject) => {
        const script = document.createElement('script');
        script.src =
          'https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit';
        script.async = true;
        script.addEventListener('load', () => resolve(window.turnstile), {
          once: true,
        });
        script.addEventListener('error', reject, { once: true });
        document.head.append(script);
      });

onMounted(async () => {
  if (!props.captchaSiteKey || !turnstileContainer.value) return;
  const turnstile = await loadTurnstile();
  turnstileWidgetId = turnstile.render(turnstileContainer.value, {
    sitekey: props.captchaSiteKey,
    callback: token => {
      captchaToken.value = token;
    },
    'expired-callback': () => {
      captchaToken.value = '';
    },
  });
});

onBeforeUnmount(() => {
  if (turnstileWidgetId !== null && window.turnstile)
    window.turnstile.remove(turnstileWidgetId);
});
</script>

<template>
  <form
    class="grid gap-3"
    novalidate
    data-testid="public-booking-form"
    @submit.prevent="submit"
  >
    <div
      v-for="(row, index) in rows"
      :key="index"
      class="grid gap-3"
      :class="row.length === 2 && 'sm:grid-cols-2'"
    >
      <RaevoField
        v-for="question in row"
        :key="question.key"
        compact
        :variant="variantOf(question)"
        :label="question.label"
        :required="question.required"
        :error="errorFor(question)"
      >
        <template #default="{ controlClass, fieldId, describedBy }">
          <textarea
            v-if="question.kind === 'textarea'"
            :id="fieldId"
            :value="answers[question.key]"
            rows="2"
            :class="controlClass"
            :aria-describedby="describedBy"
            :placeholder="question.required ? '' : t('PUBLIC_BOOKING.OPTIONAL')"
            :data-testid="`public-booking-answer-${question.key}`"
            @input="onInput(question, $event.target.value)"
          />
          <select
            v-else-if="question.kind === 'select'"
            :id="fieldId"
            :value="answers[question.key]"
            :class="controlClass"
            :aria-describedby="describedBy"
            @change="onInput(question, $event.target.value)"
          >
            <option value="" />
            <option
              v-for="option in question.options || []"
              :key="option"
              :value="option"
            >
              {{ option }}
            </option>
          </select>
          <input
            v-else
            :id="fieldId"
            :value="answers[question.key]"
            :type="
              { email: 'email', phone: 'tel', date: 'date' }[question.kind] ||
              'text'
            "
            :inputmode="
              ['cpf', 'phone'].includes(question.kind) ? 'numeric' : undefined
            "
            :autocomplete="
              { full_name: 'name', whatsapp: 'tel', email: 'email' }[
                question.key
              ]
            "
            :class="controlClass"
            :aria-describedby="describedBy"
            :aria-invalid="errorFor(question) ? 'true' : undefined"
            :placeholder="question.required ? '' : t('PUBLIC_BOOKING.OPTIONAL')"
            :data-testid="`public-booking-answer-${question.key}`"
            @input="onInput(question, $event.target.value)"
          />
        </template>
      </RaevoField>
    </div>

    <div
      v-if="payment.enabled"
      class="grid gap-2 rounded-xl border border-l-[3px] border-solid border-n-weak border-l-n-teal-9 bg-n-solid-1 p-3"
      data-testid="public-booking-payment"
    >
      <div class="flex justify-between gap-3 text-ui text-n-slate-12">
        <span>{{ procedureTitle }}</span>
        <span class="tabular-nums">{{
          formatMoney(payment.price_cents, bcp47, payment.currency)
        }}</span>
      </div>
      <span class="text-ui text-n-slate-12">{{
        t('PUBLIC_BOOKING.PAYMENT_METHOD')
      }}</span>
      <span
        class="flex flex-wrap gap-1.5"
        role="radiogroup"
        :aria-label="t('PUBLIC_BOOKING.PAYMENT_METHOD')"
      >
        <button
          v-for="method in payment.methods"
          :key="method"
          type="button"
          role="radio"
          class="rounded-full border border-solid px-2.5 py-[5px] text-xs outline-none focus-visible:ring-2 focus-visible:ring-n-brand/40"
          :class="
            paymentMethod === method
              ? 'border-n-brand bg-n-brand/10 font-semibold text-n-brand'
              : 'border-n-strong bg-n-solid-1 text-n-slate-11'
          "
          :aria-checked="paymentMethod === method ? 'true' : 'false'"
          :data-testid="`public-booking-method-${method}`"
          @click="paymentMethod = method"
        >
          {{ t(`PUBLIC_BOOKING.METHODS.${method.toUpperCase()}`) }}
        </button>
      </span>
      <div
        v-if="payment.mode === 'deposit' && paymentMethod !== 'on_site'"
        class="flex justify-between gap-3 text-ui text-n-slate-11"
      >
        <span>{{ t('PUBLIC_BOOKING.AT_CLINIC') }}</span>
        <span class="tabular-nums">{{
          formatMoney(
            payment.price_cents - payment.charge_cents,
            bcp47,
            payment.currency
          )
        }}</span>
      </div>
      <div
        class="flex justify-between gap-3 text-base font-bold tabular-nums text-n-slate-12"
      >
        <span>{{ t('PUBLIC_BOOKING.TOTAL') }}</span>
        <span>
          {{
            formatMoney(
              paymentMethod === 'on_site'
                ? payment.price_cents
                : payment.charge_cents,
              bcp47,
              payment.currency
            )
          }}
        </span>
      </div>
    </div>

    <input
      v-model="website"
      tabindex="-1"
      autocomplete="off"
      aria-hidden="true"
      class="hidden"
    />
    <div v-if="captchaSiteKey" ref="turnstileContainer" class="min-h-16" />
    <label class="flex items-start gap-2 text-xs text-n-slate-11">
      <input
        v-model="consent"
        type="checkbox"
        class="mb-0 mt-0.5 size-4"
        data-testid="public-booking-consent"
      />
      {{ t('PUBLIC_BOOKING.CONSENT') }}
    </label>
    <p
      v-if="tried && !consent"
      class="mb-0 text-xs text-n-ruby-11"
      role="alert"
    >
      {{ t('PUBLIC_BOOKING.ERRORS.CONSENT') }}
    </p>

    <div class="flex flex-wrap justify-end gap-2">
      <button
        type="button"
        class="rounded-full border border-solid border-n-strong bg-n-solid-1 px-4 py-[9px] text-ui font-semibold text-n-slate-11 outline-none hover:text-n-slate-12 focus-visible:ring-2 focus-visible:ring-n-brand/40"
        :disabled="saving"
        @click="emit('back')"
      >
        {{ t('PUBLIC_BOOKING.BACK') }}
      </button>
      <button
        type="submit"
        class="rounded-full border border-solid border-n-brand bg-n-brand px-4 py-[9px] text-ui font-semibold text-white outline-none hover:bg-n-brand/90 focus-visible:ring-2 focus-visible:ring-n-brand/40 disabled:opacity-60"
        :disabled="saving"
        data-testid="public-booking-submit"
      >
        {{ saving ? t('PUBLIC_BOOKING.CONFIRMING') : submitLabel }}
      </button>
    </div>
  </form>
</template>
