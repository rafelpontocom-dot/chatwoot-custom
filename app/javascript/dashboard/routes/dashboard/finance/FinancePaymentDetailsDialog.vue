<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';

import FinanceAPI from 'dashboard/api/finance';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';

const props = defineProps({
  canManage: { type: Boolean, default: true },
  canRefund: { type: Boolean, default: true },
});
const emit = defineEmits(['canceled', 'received', 'refundRequested']);

const { t } = useI18n();
const dialog = ref(null);
const payment = ref(null);
const isLoading = ref(false);
const isCanceling = ref(false);
const isConfirmingCancel = ref(false);
const isMarkingReceived = ref(false);
const isConfirmingReceived = ref(false);
const isRequestingRefund = ref(false);
const isConfirmingRefund = ref(false);
const error = ref('');

const eventTypeTranslationKeys = {
  PAYMENT_CREATED: 'FINANCE.PAYMENTS.DETAIL.EVENT_TYPES.PAYMENT_CREATED',
  PAYMENT_OVERDUE: 'FINANCE.PAYMENTS.DETAIL.EVENT_TYPES.PAYMENT_OVERDUE',
  PAYMENT_CONFIRMED: 'FINANCE.PAYMENTS.DETAIL.EVENT_TYPES.PAYMENT_CONFIRMED',
  PAYMENT_RECEIVED: 'FINANCE.PAYMENTS.DETAIL.EVENT_TYPES.PAYMENT_RECEIVED',
  PAYMENT_DELETED: 'FINANCE.PAYMENTS.DETAIL.EVENT_TYPES.PAYMENT_DELETED',
  PAYMENT_REFUNDED: 'FINANCE.PAYMENTS.DETAIL.EVENT_TYPES.PAYMENT_REFUNDED',
  PAYMENT_PARTIALLY_REFUNDED:
    'FINANCE.PAYMENTS.DETAIL.EVENT_TYPES.PAYMENT_PARTIALLY_REFUNDED',
  PAYMENT_CHARGEBACK_REQUESTED:
    'FINANCE.PAYMENTS.DETAIL.EVENT_TYPES.PAYMENT_CHARGEBACK_REQUESTED',
  PAYMENT_REFUND_REQUESTED:
    'FINANCE.PAYMENTS.DETAIL.EVENT_TYPES.PAYMENT_REFUND_REQUESTED',
};

const isCancellable = computed(
  () =>
    props.canManage && ['pending', 'overdue'].includes(payment.value?.status)
);
const isManualPayment = computed(() => payment.value?.provider === 'manual');
const isReceivable = computed(
  () =>
    props.canManage &&
    isManualPayment.value &&
    ['pending', 'confirmed', 'overdue'].includes(payment.value?.status)
);
const isRefundable = computed(
  () =>
    props.canRefund &&
    payment.value?.provider === 'asaas' &&
    ['pix', 'credit_card'].includes(payment.value?.billing_type) &&
    ['confirmed', 'received'].includes(payment.value?.status) &&
    !payment.value?.events?.some(
      event => event.event_type === 'PAYMENT_REFUND_REQUESTED'
    )
);

const open = async paymentId => {
  payment.value = null;
  error.value = '';
  isLoading.value = true;
  dialog.value?.open();

  try {
    const { data } = await FinanceAPI.getPayment(paymentId);
    payment.value = data;
  } catch (requestError) {
    error.value =
      requestError.response?.data?.message ||
      t('FINANCE.PAYMENTS.DETAIL.LOAD_ERROR');
  } finally {
    isLoading.value = false;
  }
};

const formatOccurredAt = value => {
  if (!value) return t('FINANCE.PAYMENTS.DETAIL.NO_DATE');

  return new Intl.DateTimeFormat(undefined, {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(new Date(value));
};

const eventTypeLabel = eventType =>
  t(
    eventTypeTranslationKeys[eventType] ||
      'FINANCE.PAYMENTS.DETAIL.EVENT_TYPES.UNKNOWN'
  );

const formatAmount = ({ amount_cents: amountCents = 0, currency = 'BRL' }) =>
  new Intl.NumberFormat(undefined, {
    style: 'currency',
    currency,
  }).format(Number(amountCents) / 100);

const formatDueOn = dueOn => {
  if (!dueOn) return t('FINANCE.PAYMENTS.NO_DUE_DATE');

  return new Intl.DateTimeFormat(undefined, { dateStyle: 'medium' }).format(
    new Date(`${dueOn}T12:00:00`)
  );
};

const billingTypeLabel = billingType =>
  t(`FINANCE.PAYMENTS.TYPES.${(billingType || 'other').toUpperCase()}`);

const cancelPayment = async () => {
  if (!payment.value) return;

  if (!isConfirmingCancel.value) {
    isConfirmingCancel.value = true;
    return;
  }

  isCanceling.value = true;
  error.value = '';

  try {
    const { data } = await FinanceAPI.cancelPayment(payment.value.id);
    payment.value = data;
    isConfirmingCancel.value = false;
    emit('canceled', data);
  } catch (requestError) {
    error.value =
      requestError.response?.data?.message ||
      t('FINANCE.PAYMENTS.DETAIL.CANCEL_ERROR');
  } finally {
    isCanceling.value = false;
  }
};

const markPaymentReceived = async () => {
  if (!payment.value) return;

  if (!isConfirmingReceived.value) {
    isConfirmingReceived.value = true;
    return;
  }

  isMarkingReceived.value = true;
  error.value = '';

  try {
    const { data } = await FinanceAPI.markPaymentReceived(payment.value.id);
    payment.value = data;
    isConfirmingReceived.value = false;
    emit('received', data);
  } catch (requestError) {
    error.value =
      requestError.response?.data?.message ||
      t('FINANCE.PAYMENTS.DETAIL.RECEIVE_ERROR');
  } finally {
    isMarkingReceived.value = false;
  }
};

const requestRefund = async () => {
  if (!payment.value) return;

  if (!isConfirmingRefund.value) {
    isConfirmingRefund.value = true;
    return;
  }

  isRequestingRefund.value = true;
  error.value = '';

  try {
    const { data } = await FinanceAPI.requestPaymentRefund(
      payment.value.id,
      ''
    );
    payment.value = data;
    isConfirmingRefund.value = false;
    emit('refundRequested', data);
  } catch (requestError) {
    error.value =
      requestError.response?.data?.message ||
      t('FINANCE.PAYMENTS.DETAIL.REFUND_ERROR');
  } finally {
    isRequestingRefund.value = false;
  }
};

defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialog"
    width="md"
    overflow-y-auto
    :title="t('FINANCE.PAYMENTS.DETAIL.TITLE')"
    :description="t('FINANCE.PAYMENTS.DETAIL.DESCRIPTION')"
    :show-confirm-button="false"
  >
    <p v-if="isLoading" class="mb-0 text-sm text-n-slate-11">
      {{ t('FINANCE.PAYMENTS.DETAIL.LOADING') }}
    </p>
    <p v-else-if="error" class="mb-0 text-sm text-n-ruby-11" role="alert">
      {{ error }}
    </p>
    <div v-else-if="payment" class="grid gap-5">
      <div class="rounded-md bg-n-alpha-2 px-3 py-2.5">
        <p class="mb-0 text-sm font-medium text-n-slate-12">
          {{ payment.description || t('FINANCE.PAYMENTS.TITLE') }}
        </p>
        <p class="mb-0 mt-1 text-xs text-n-slate-11">
          {{ t(`FINANCE.PAYMENTS.STATUS.${payment.status?.toUpperCase()}`) }}
        </p>
      </div>

      <dl class="grid gap-3 sm:grid-cols-3">
        <div class="min-w-0">
          <dt class="text-xs font-medium text-n-slate-10">
            {{ t('FINANCE.PAYMENTS.DETAIL.AMOUNT') }}
          </dt>
          <dd
            data-testid="finance-payment-detail-amount"
            class="mb-0 mt-1 text-sm font-semibold text-n-slate-12"
          >
            {{ formatAmount(payment) }}
          </dd>
        </div>
        <div class="min-w-0">
          <dt class="text-xs font-medium text-n-slate-10">
            {{ t('FINANCE.PAYMENTS.DETAIL.METHOD') }}
          </dt>
          <dd
            data-testid="finance-payment-detail-method"
            class="mb-0 mt-1 truncate text-sm text-n-slate-12"
          >
            {{ billingTypeLabel(payment.billing_type) }}
          </dd>
        </div>
        <div class="min-w-0">
          <dt class="text-xs font-medium text-n-slate-10">
            {{ t('FINANCE.PAYMENTS.DETAIL.DUE_ON') }}
          </dt>
          <dd class="mb-0 mt-1 truncate text-sm text-n-slate-12">
            {{ formatDueOn(payment.due_on) }}
          </dd>
        </div>
      </dl>

      <a
        v-if="payment.invoice_url"
        :href="payment.invoice_url"
        target="_blank"
        rel="noopener noreferrer"
        data-testid="finance-payment-detail-link"
        class="w-fit text-sm font-medium text-n-brand outline-none hover:underline focus:ring-2 focus:ring-n-brand/40"
      >
        {{ t('FINANCE.PAYMENTS.DETAIL.OPEN_LINK') }}
      </a>

      <div
        v-if="isCancellable || isReceivable || isRefundable"
        class="flex flex-wrap justify-end gap-2"
      >
        <Button
          v-if="isReceivable"
          :label="
            isConfirmingReceived
              ? t('FINANCE.PAYMENTS.DETAIL.CONFIRM_RECEIVED')
              : t('FINANCE.PAYMENTS.DETAIL.MARK_RECEIVED')
          "
          color="teal"
          variant="outline"
          :is-loading="isMarkingReceived"
          type="button"
          data-testid="finance-payment-mark-received"
          @click="markPaymentReceived"
        />
        <Button
          v-if="isRefundable"
          :label="
            isConfirmingRefund
              ? t('FINANCE.PAYMENTS.DETAIL.CONFIRM_REFUND')
              : t('FINANCE.PAYMENTS.DETAIL.REQUEST_REFUND')
          "
          color="ruby"
          variant="outline"
          :is-loading="isRequestingRefund"
          type="button"
          data-testid="finance-payment-refund"
          @click="requestRefund"
        />
        <Button
          v-if="isCancellable"
          :label="
            isConfirmingCancel
              ? t('FINANCE.PAYMENTS.DETAIL.CONFIRM_CANCEL')
              : t('FINANCE.PAYMENTS.DETAIL.CANCEL')
          "
          color="ruby"
          variant="outline"
          :is-loading="isCanceling"
          type="button"
          data-testid="finance-payment-cancel"
          @click="cancelPayment"
        />
      </div>

      <section>
        <h3 class="mb-3 text-sm font-semibold text-n-slate-12">
          {{ t('FINANCE.PAYMENTS.DETAIL.EVENTS') }}
        </h3>
        <p
          v-if="payment.events?.length === 0"
          class="mb-0 text-sm text-n-slate-11"
        >
          {{ t('FINANCE.PAYMENTS.DETAIL.EVENTS_EMPTY') }}
        </p>
        <ol v-else class="m-0 grid list-none gap-3 p-0">
          <li
            v-for="event in payment.events"
            :key="event.id"
            class="grid gap-1 border-l-2 border-n-brand pl-3"
          >
            <p class="mb-0 text-sm font-medium text-n-slate-12">
              {{ eventTypeLabel(event.event_type) }}
            </p>
            <p class="mb-0 text-xs text-n-slate-11">
              {{ formatOccurredAt(event.occurred_at) }}
            </p>
            <p v-if="event.error_message" class="mb-0 text-xs text-n-ruby-11">
              {{ event.error_message }}
            </p>
          </li>
        </ol>
      </section>
    </div>
  </Dialog>
</template>
