<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import FinanceAPI from 'dashboard/api/finance';
import RaevoField from 'dashboard/components-next/raevo/RaevoField.vue';
import SetupChips from '../shared/SetupChips.vue';
import SetupGroup from '../shared/SetupGroup.vue';
import SetupRow from '../shared/SetupRow.vue';
import SetupSwitch from '../shared/SetupSwitch.vue';
import { useProcedureDraft } from './procedureDraft';

const { t } = useI18n();
const { draft, errors } = useProcedureDraft();

const financeModule = ref(null);
const providerName = ref('');
const HOLDS = [5, 10, 15, 20, 30, 45, 60];

const methodOptions = computed(() =>
  ['pix', 'card', 'on_site'].map(method => ({
    value: method,
    label: t(
      `CALENDAR_SETUP.PROCEDURE.PAYMENT.METHODS_LIST.${method.toUpperCase()}`
    ),
  }))
);

const modeOptions = computed(() =>
  ['full', 'deposit'].map(mode => ({
    value: mode,
    label: t(`CALENDAR_SETUP.PROCEDURE.PAYMENT.MODES.${mode.toUpperCase()}`),
  }))
);

// O valor edita-se em reais; guarda-se em centavos.
const moneyModel = field =>
  computed({
    get: () =>
      draft.value[field] === null || draft.value[field] === undefined
        ? ''
        : (draft.value[field] / 100).toFixed(2),
    set: value => {
      const number = Number(String(value).replace(',', '.'));
      draft.value[field] =
        value === '' || Number.isNaN(number) ? null : Math.round(number * 100);
    },
  });

const price = moneyModel('price_cents');
const deposit = moneyModel('deposit_cents');

onMounted(async () => {
  try {
    const [{ data: module }, { data: connections }] = await Promise.all([
      FinanceAPI.getModule(),
      FinanceAPI.getProviderConnections(),
    ]);
    financeModule.value = module;
    const connection =
      (connections || []).find(
        item => item.provider === module.default_payment_provider
      ) || (connections || [])[0];
    providerName.value = connection
      ? [connection.provider, connection.name || connection.label]
          .filter(Boolean)
          .join(' · ')
      : '';
  } catch {
    financeModule.value = { enabled: false };
  }
});
</script>

<template>
  <SetupGroup
    :title="t('CALENDAR_SETUP.PROCEDURE.PAYMENT.GROUP')"
    :hint="t('CALENDAR_SETUP.PROCEDURE.PAYMENT.GROUP_HINT')"
    data-testid="calendar-procedure-tab-payment"
  >
    <SetupRow
      :title="t('CALENDAR_SETUP.PROCEDURE.PAYMENT.ENABLED')"
      :hint="t('CALENDAR_SETUP.PROCEDURE.PAYMENT.ENABLED_HINT')"
    >
      <SetupSwitch
        v-model="draft.payment_enabled"
        :label="t('CALENDAR_SETUP.PROCEDURE.PAYMENT.ENABLED')"
        :disabled="
          financeModule && !financeModule.enabled && !draft.payment_enabled
        "
        data-testid="calendar-procedure-payment-enabled"
      />
    </SetupRow>
    <p
      v-if="financeModule && !financeModule.enabled"
      class="mb-0 flex items-center gap-1.5 text-xs text-n-amber-11"
      role="status"
    >
      <i class="i-lucide-triangle-alert size-3.5" aria-hidden="true" />
      {{ t('CALENDAR_SETUP.PROCEDURE.PAYMENT.FINANCE_OFF') }}
    </p>

    <template v-if="draft.payment_enabled">
      <div class="grid gap-3 md:grid-cols-2">
        <RaevoField
          compact
          :label="t('CALENDAR_SETUP.PROCEDURE.PAYMENT.PRICE')"
          :error="errors.price_cents"
        >
          <template #default="{ controlClass, fieldId }">
            <input
              :id="fieldId"
              v-model.lazy="price"
              type="number"
              min="0"
              step="0.01"
              inputmode="decimal"
              :class="controlClass"
              data-testid="calendar-procedure-price"
            />
          </template>
        </RaevoField>
        <div class="grid content-start gap-1.5">
          <span class="text-xs font-medium text-n-slate-11">{{
            t('CALENDAR_SETUP.PROCEDURE.PAYMENT.MODE')
          }}</span>
          <SetupChips
            v-model="draft.payment_mode"
            :label="t('CALENDAR_SETUP.PROCEDURE.PAYMENT.MODE')"
            :options="modeOptions"
          />
          <small class="text-xs text-n-slate-10">{{
            t('CALENDAR_SETUP.PROCEDURE.PAYMENT.MODE_HINT')
          }}</small>
        </div>
      </div>
      <RaevoField
        v-if="draft.payment_mode === 'deposit'"
        compact
        :label="t('CALENDAR_SETUP.PROCEDURE.PAYMENT.DEPOSIT')"
        :error="errors.deposit_cents"
      >
        <template #default="{ controlClass, fieldId }">
          <input
            :id="fieldId"
            v-model.lazy="deposit"
            type="number"
            min="0"
            step="0.01"
            inputmode="decimal"
            :class="controlClass"
          />
        </template>
      </RaevoField>
      <SetupRow :title="t('CALENDAR_SETUP.PROCEDURE.PAYMENT.METHODS')">
        <SetupChips
          v-model="draft.payment_methods"
          multiple
          :label="t('CALENDAR_SETUP.PROCEDURE.PAYMENT.METHODS')"
          :options="methodOptions"
        />
      </SetupRow>
      <div class="grid gap-3 md:grid-cols-2">
        <RaevoField
          compact
          variant="select"
          :label="t('CALENDAR_SETUP.PROCEDURE.PAYMENT.HOLD')"
          :hint="t('CALENDAR_SETUP.PROCEDURE.PAYMENT.HOLD_HINT')"
        >
          <template #default="{ controlClass, fieldId, describedBy }">
            <select
              :id="fieldId"
              v-model.number="draft.hold_minutes"
              :class="controlClass"
              :aria-describedby="describedBy"
            >
              <option v-for="value in HOLDS" :key="value" :value="value">
                {{ t('CALENDAR_SETUP.COMMON.MINUTES', { count: value }) }}
              </option>
            </select>
          </template>
        </RaevoField>
        <RaevoField
          compact
          :label="t('CALENDAR_SETUP.PROCEDURE.PAYMENT.PROVIDER')"
        >
          <template #default="{ controlClass, fieldId }">
            <input
              :id="fieldId"
              :value="
                providerName ||
                t('CALENDAR_SETUP.PROCEDURE.PAYMENT.PROVIDER_NONE')
              "
              type="text"
              readonly
              :class="controlClass"
            />
          </template>
        </RaevoField>
      </div>
    </template>
  </SetupGroup>
</template>
