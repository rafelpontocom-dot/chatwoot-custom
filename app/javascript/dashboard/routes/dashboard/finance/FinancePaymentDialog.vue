<script setup>
import { computed, onUnmounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import camelcaseKeys from 'camelcase-keys';
import { debounce } from '@chatwoot/utils';

import FinanceAPI from 'dashboard/api/finance';
import ContactAPI from 'dashboard/api/contacts';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';

const props = defineProps({
  connections: { type: Array, default: () => [] },
  contact: { type: Object, default: null },
  kanbanCardId: { type: [Number, String], default: null },
  market: { type: String, default: 'BR' },
});

const emit = defineEmits(['created']);

const { t } = useI18n();
const dialog = ref(null);
const connectionId = ref('');
const contactSearchQuery = ref('');
const contactResults = ref([]);
const selectedContact = ref(null);
const isSearchingContacts = ref(false);
const contactSearchController = ref(null);
const amount = ref('');
const billingType = ref('pix');
const dueOn = ref('');
const cpfCnpj = ref('');
const description = ref('');
const isSaving = ref(false);
const error = ref('');

const activeConnections = computed(() =>
  props.connections.filter(connection => connection.status === 'connected')
);
const selectedConnection = computed(() =>
  activeConnections.value.find(
    connection => String(connection.id) === connectionId.value
  )
);
const isManualConnection = computed(
  () => selectedConnection.value?.provider === 'manual'
);
const requiresTaxIdentifier = computed(
  () => selectedConnection.value?.provider === 'asaas'
);
const billingTypeOptions = computed(() =>
  isManualConnection.value
    ? [{ value: 'other', label: t('FINANCE.PAYMENTS.TYPES.OTHER') }]
    : [
        { value: 'pix', label: t('FINANCE.PAYMENTS.TYPES.PIX') },
        {
          value: 'credit_card',
          label: t('FINANCE.PAYMENTS.TYPES.CREDIT_CARD'),
        },
        { value: 'boleto', label: t('FINANCE.PAYMENTS.TYPES.BOLETO') },
      ]
);
const paymentContact = computed(() => props.contact || selectedContact.value);
const normalizedAmount = computed(() =>
  Number(amount.value.replace(',', '.').replace(/[^\d.]/g, ''))
);
const amountCents = computed(() => Math.round(normalizedAmount.value * 100));
const isBelowAsaasMinimum = computed(
  () =>
    requiresTaxIdentifier.value &&
    amount.value.trim().length > 0 &&
    amountCents.value < 500
);
const canSave = computed(
  () =>
    !!connectionId.value &&
    !!paymentContact.value &&
    amountCents.value > 0 &&
    !isBelowAsaasMinimum.value &&
    !!billingType.value &&
    !!dueOn.value &&
    (!requiresTaxIdentifier.value ||
      cpfCnpj.value.replace(/\D/g, '').length >= 11) &&
    !isSaving.value
);

const resetForm = () => {
  connectionId.value = String(activeConnections.value[0]?.id || '');
  contactSearchQuery.value = '';
  contactResults.value = [];
  selectedContact.value = null;
  amount.value = '';
  billingType.value =
    activeConnections.value[0]?.provider === 'manual' ? 'other' : 'pix';
  dueOn.value = '';
  cpfCnpj.value = '';
  description.value = '';
  error.value = '';
};

const abortContactSearch = () => {
  contactSearchController.value?.abort();
  contactSearchController.value = null;
};

const searchContacts = async query => {
  const trimmedQuery = query.trim();
  if (trimmedQuery.length < 2) {
    contactResults.value = [];
    return;
  }

  abortContactSearch();
  const controller = new AbortController();
  contactSearchController.value = controller;
  isSearchingContacts.value = true;

  try {
    const response = await ContactAPI.search(trimmedQuery, 1, 'name', '', {
      signal: controller.signal,
    });
    if (!controller.signal.aborted) {
      contactResults.value = camelcaseKeys(response.data?.payload || [], {
        deep: true,
      });
    }
  } catch (searchError) {
    if (
      searchError?.name !== 'AbortError' &&
      searchError?.name !== 'CanceledError'
    ) {
      contactResults.value = [];
    }
  } finally {
    if (contactSearchController.value === controller) {
      contactSearchController.value = null;
      isSearchingContacts.value = false;
    }
  }
};

const debouncedSearchContacts = debounce(searchContacts, 250, false);

const onContactInput = () => {
  selectedContact.value = null;
  debouncedSearchContacts(contactSearchQuery.value);
};

const selectContact = contact => {
  selectedContact.value = contact;
  contactSearchQuery.value =
    contact.name || contact.email || contact.phoneNumber || '';
  contactResults.value = [];
};

const onConnectionChange = () => {
  billingType.value = isManualConnection.value ? 'other' : 'pix';
  cpfCnpj.value = '';
};

const open = () => {
  resetForm();
  dialog.value?.open();
};

const close = () => {
  abortContactSearch();
  dialog.value?.close();
};

const save = async () => {
  if (!canSave.value) return;

  isSaving.value = true;
  error.value = '';

  try {
    const { data } = await FinanceAPI.createPayment({
      payment: {
        contact_id: paymentContact.value.id,
        finance_provider_connection_id: Number(connectionId.value),
        ...(props.kanbanCardId ? { kanban_card_id: props.kanbanCardId } : {}),
        amount_cents: amountCents.value,
        billing_type: billingType.value,
        due_on: dueOn.value,
        currency: props.market === 'PT' ? 'EUR' : 'BRL',
        ...(requiresTaxIdentifier.value
          ? { cpf_cnpj: cpfCnpj.value.replace(/\D/g, '') }
          : {}),
        description: description.value.trim(),
      },
    });
    emit('created', data);
    close();
  } catch (requestError) {
    error.value =
      requestError.response?.data?.message || t('FINANCE.PAYMENTS.ERROR');
  } finally {
    isSaving.value = false;
  }
};

onUnmounted(abortContactSearch);

defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialog"
    width="md"
    overflow-y-auto
    :title="t('FINANCE.PAYMENTS.CREATE_TITLE')"
    :description="t('FINANCE.PAYMENTS.CREATE_DESCRIPTION')"
    :show-confirm-button="false"
    @close="resetForm"
  >
    <div class="grid gap-4">
      <div v-if="contact" class="grid gap-1.5">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('FINANCE.PAYMENTS.CONTACT') }}
        </span>
        <p class="mb-0 text-sm text-n-slate-11">
          {{ contact.name || contact.email || contact.phone_number }}
        </p>
      </div>
      <label v-else class="grid gap-1.5">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('FINANCE.PAYMENTS.CONTACT') }}
        </span>
        <input
          v-model="contactSearchQuery"
          data-testid="finance-payment-contact-search"
          type="search"
          :placeholder="t('FINANCE.PAYMENTS.SEARCH_CONTACT')"
          class="h-10 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none placeholder:text-n-slate-9 focus:border-n-brand focus:ring-2 focus:ring-n-brand/20"
          @input="onContactInput"
        />
        <span v-if="isSearchingContacts" class="text-xs text-n-slate-11">
          {{ t('FINANCE.PAYMENTS.SEARCHING_CONTACT') }}
        </span>
        <div v-else-if="contactResults.length" class="grid gap-1">
          <button
            v-for="result in contactResults"
            :key="result.id"
            type="button"
            class="rounded-md px-2 py-1.5 text-left text-sm text-n-slate-12 outline-none hover:bg-n-alpha-2 focus:ring-2 focus:ring-n-brand/40"
            @click="selectContact(result)"
          >
            {{ result.name || result.email || result.phoneNumber }}
          </button>
        </div>
      </label>

      <div class="grid gap-4 sm:grid-cols-2">
        <label class="grid gap-1.5">
          <span class="text-sm font-medium text-n-slate-12">
            {{ t('FINANCE.PAYMENTS.AMOUNT') }}
          </span>
          <input
            v-model="amount"
            data-testid="finance-payment-amount"
            inputmode="decimal"
            :placeholder="t('FINANCE.PAYMENTS.AMOUNT_PLACEHOLDER')"
            class="h-10 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none placeholder:text-n-slate-9 focus:border-n-brand focus:ring-2 focus:ring-n-brand/20"
          />
          <span
            v-if="isBelowAsaasMinimum"
            class="text-xs text-n-ruby-11"
            role="alert"
          >
            {{ t('FINANCE.PAYMENTS.ASAAS_MINIMUM_AMOUNT') }}
          </span>
        </label>
        <label class="grid gap-1.5">
          <span class="text-sm font-medium text-n-slate-12">
            {{ t('FINANCE.PAYMENTS.BILLING_TYPE') }}
          </span>
          <select
            v-model="billingType"
            data-testid="finance-payment-billing-type"
            class="h-10 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand focus:ring-2 focus:ring-n-brand/20"
          >
            <option
              v-for="option in billingTypeOptions"
              :key="option.value"
              :value="option.value"
            >
              {{ option.label }}
            </option>
          </select>
        </label>
      </div>

      <div class="grid gap-4 sm:grid-cols-2">
        <label class="grid gap-1.5">
          <span class="text-sm font-medium text-n-slate-12">
            {{ t('FINANCE.PAYMENTS.DUE_ON') }}
          </span>
          <input
            v-model="dueOn"
            data-testid="finance-payment-due-on"
            type="date"
            class="h-10 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand focus:ring-2 focus:ring-n-brand/20"
          />
        </label>
        <label v-if="requiresTaxIdentifier" class="grid gap-1.5">
          <span class="text-sm font-medium text-n-slate-12">
            {{ t('FINANCE.PAYMENTS.CPF_CNPJ') }}
          </span>
          <input
            v-model="cpfCnpj"
            data-testid="finance-payment-cpf-cnpj"
            inputmode="numeric"
            :placeholder="t('FINANCE.PAYMENTS.CPF_CNPJ_PLACEHOLDER')"
            class="h-10 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none placeholder:text-n-slate-9 focus:border-n-brand focus:ring-2 focus:ring-n-brand/20"
          />
        </label>
      </div>

      <label class="grid gap-1.5">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('FINANCE.PAYMENTS.DESCRIPTION_FIELD') }}
        </span>
        <textarea
          v-model="description"
          data-testid="finance-payment-description"
          rows="3"
          :placeholder="t('FINANCE.PAYMENTS.DESCRIPTION_PLACEHOLDER')"
          class="resize-y rounded-md border border-n-weak bg-n-surface-1 px-3 py-2 text-sm text-n-slate-12 outline-none placeholder:text-n-slate-9 focus:border-n-brand focus:ring-2 focus:ring-n-brand/20"
        />
      </label>

      <label class="grid gap-1.5">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('FINANCE.PAYMENTS.CONNECTION') }}
        </span>
        <select
          v-model="connectionId"
          data-testid="finance-payment-connection"
          class="h-10 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand focus:ring-2 focus:ring-n-brand/20"
          @change="onConnectionChange"
        >
          <option value="">
            {{ t('FINANCE.PAYMENTS.SELECT_CONNECTION') }}
          </option>
          <option
            v-for="connection in activeConnections"
            :key="connection.id"
            :value="String(connection.id)"
          >
            {{ connection.display_name || connection.provider }}
          </option>
        </select>
      </label>

      <p v-if="error" class="mb-0 text-sm text-n-ruby-11" role="alert">
        {{ error }}
      </p>
    </div>

    <template #footer>
      <div class="flex items-center justify-end gap-3">
        <Button
          type="button"
          link
          slate
          :label="t('DIALOG.BUTTONS.CANCEL')"
          @click="close"
        />
        <Button
          type="button"
          data-testid="finance-payment-submit"
          :label="t('FINANCE.PAYMENTS.CREATE')"
          :disabled="!canSave"
          :is-loading="isSaving"
          @click="save"
        />
      </div>
    </template>
  </Dialog>
</template>
