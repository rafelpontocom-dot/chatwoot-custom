<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import MarketingAPI from 'dashboard/api/marketing';
import { useMapGetter } from 'dashboard/composables/store';
import { frontendURL } from 'dashboard/helper/URLHelper';
import RaevoPageHeader from 'dashboard/components-next/raevo/RaevoPageHeader.vue';
import RaevoStamp from 'dashboard/components-next/raevo/RaevoStamp.vue';

// Raevo · Sereno — a tela operacional responde "de onde vieram os leads".
// Ligar o módulo e conectar plataformas vivem atrás da engrenagem, como no
// Financeiro. Ver docs/raevo-design-system.md §5.
const { t } = useI18n();
const currentAccount = useMapGetter('getCurrentAccount');

const activeView = ref('panel');
const marketingModule = ref(null);
const summary = ref(null);
const touchpoints = ref([]);
const isLoading = ref(true);
const isLoadingTouchpoints = ref(false);
const isSavingModule = ref(false);
const loadError = ref('');
const saveError = ref('');

const accountId = computed(() => currentAccount.value?.id);
const permissions = computed(() => currentAccount.value?.permissions || []);
const canConfigure = computed(() =>
  ['administrator', 'marketing_configure'].some(permission =>
    permissions.value.includes(permission)
  )
);
const isEnabled = computed(() => Boolean(marketingModule.value?.enabled));

const captureRate = computed(() => summary.value?.capture_rate ?? 0);
const originRows = computed(() =>
  Object.entries(summary.value?.by_origin || {}).sort((a, b) => b[1] - a[1])
);
const campaignRows = computed(() =>
  Object.entries(summary.value?.top_campaigns || {}).sort((a, b) => b[1] - a[1])
);

const contactPath = contact =>
  frontendURL(`accounts/${accountId.value}/contacts/${contact.id}`);

const loadModule = async () => {
  const { data } = await MarketingAPI.getModule();
  marketingModule.value = data;
};

const loadPanel = async () => {
  if (!isEnabled.value) return;
  isLoadingTouchpoints.value = true;
  try {
    const [summaryResponse, listResponse] = await Promise.all([
      MarketingAPI.getSummary(),
      MarketingAPI.getTouchpoints({ limit: 25 }),
    ]);
    summary.value = summaryResponse.data;
    touchpoints.value = listResponse.data.payload || [];
  } finally {
    isLoadingTouchpoints.value = false;
  }
};

const toggleModule = async enabled => {
  isSavingModule.value = true;
  saveError.value = '';
  try {
    const { data } = await MarketingAPI.updateModule({
      marketing_module: { enabled, confirm_disable: !enabled },
    });
    marketingModule.value = data;
    if (enabled) await loadPanel();
  } catch (error) {
    saveError.value =
      error?.response?.data?.message || t('MARKETING.SETTINGS.SAVE_ERROR');
  } finally {
    isSavingModule.value = false;
  }
};

onMounted(async () => {
  try {
    await loadModule();
    await loadPanel();
  } catch (error) {
    loadError.value =
      error?.response?.data?.message || t('MARKETING.LOAD_ERROR');
  } finally {
    isLoading.value = false;
  }
});
</script>

<template>
  <div class="h-full w-full overflow-auto bg-n-background p-6">
    <div class="mx-auto flex w-full max-w-6xl flex-col gap-6">
      <RaevoPageHeader
        :eyebrow="t('MARKETING.EYEBROW')"
        :title="t('MARKETING.TITLE')"
        :subtitle="t('MARKETING.SUBTITLE')"
      >
        <template #actions>
          <RaevoStamp
            v-if="marketingModule"
            :variant="isEnabled ? 'success' : 'neutral'"
            :label="
              isEnabled
                ? t('MARKETING.STATUS.ENABLED')
                : t('MARKETING.STATUS.DISABLED')
            "
          />
          <button
            v-if="canConfigure"
            type="button"
            data-testid="marketing-toggle-settings"
            class="flex p-0 size-9 items-center justify-center rounded-full border border-solid border-n-weak text-n-slate-11 outline-none hover:bg-n-slate-3 hover:text-n-slate-12 focus-visible:ring-2 focus-visible:ring-n-brand"
            :class="activeView === 'settings' ? 'bg-n-blue-3 text-n-brand' : ''"
            :aria-pressed="activeView === 'settings'"
            :aria-label="
              activeView === 'settings'
                ? t('MARKETING.BACK_TO_PANEL')
                : t('MARKETING.OPEN_SETTINGS')
            "
            :title="
              activeView === 'settings'
                ? t('MARKETING.BACK_TO_PANEL')
                : t('MARKETING.OPEN_SETTINGS')
            "
            @click="
              activeView = activeView === 'settings' ? 'panel' : 'settings'
            "
          >
            <i class="i-lucide-settings size-4" />
          </button>
        </template>
      </RaevoPageHeader>

      <p v-if="loadError" class="mb-0 text-sm text-n-ruby-11" role="alert">
        {{ loadError }}
      </p>

      <div v-else-if="isLoading" class="text-sm text-n-slate-11">
        {{ t('MARKETING.LOADING') }}
      </div>

      <!-- Configurações: ligar o módulo. Conexões e entrada de leads entram aqui. -->
      <section
        v-else-if="activeView === 'settings'"
        class="grid gap-4 rounded-xl border border-n-weak bg-n-solid-1 p-4"
      >
        <h3 class="mb-0 text-sm font-semibold text-n-slate-12">
          {{ t('MARKETING.SETTINGS.TITLE') }}
        </h3>
        <p class="mb-0 text-sm text-n-slate-11">
          {{ t('MARKETING.SETTINGS.DESCRIPTION') }}
        </p>
        <label class="flex items-center gap-2 text-sm text-n-slate-12">
          <input
            :checked="isEnabled"
            :disabled="isSavingModule"
            type="checkbox"
            data-testid="marketing-toggle-module"
            class="size-4 rounded border-n-weak text-n-brand focus:ring-n-brand"
            @change="toggleModule($event.target.checked)"
          />
          {{ t('MARKETING.SETTINGS.ENABLE') }}
        </label>
        <p v-if="saveError" class="mb-0 text-xs text-n-ruby-11" role="alert">
          {{ saveError }}
        </p>
      </section>

      <!-- Módulo desligado: um único caminho à frente, não uma tela vazia. -->
      <section
        v-else-if="!isEnabled"
        class="grid gap-3 rounded-xl border border-n-weak bg-n-solid-1 p-6 text-center"
      >
        <h3 class="mb-0 text-sm font-semibold text-n-slate-12">
          {{ t('MARKETING.EMPTY.DISABLED_TITLE') }}
        </h3>
        <p class="mb-0 text-sm text-n-slate-11">
          {{ t('MARKETING.EMPTY.DISABLED_BODY') }}
        </p>
      </section>

      <template v-else>
        <!--
          A taxa de captação primeiro: antes de prometer ROAS, ela diz se
          estamos conseguindo saber de onde o lead vem.
        -->
        <section class="grid gap-4 sm:grid-cols-3">
          <div class="rounded-xl border border-n-weak bg-n-solid-1 p-4">
            <span
              class="block text-micro font-bold uppercase tracking-[0.16em] text-n-slate-10"
            >
              {{ t('MARKETING.PANEL.CAPTURE_RATE') }}
            </span>
            <strong
              data-testid="marketing-capture-rate"
              class="mt-1 block text-3xl font-bold tabular-nums text-n-slate-12"
            >
              {{ captureRate }}%
            </strong>
            <span class="text-xs text-n-slate-11">
              {{
                t('MARKETING.PANEL.CAPTURE_RATE_HINT', {
                  identified: summary?.identified ?? 0,
                  total: summary?.total ?? 0,
                })
              }}
            </span>
          </div>
          <div
            class="rounded-xl border border-n-weak bg-n-solid-1 p-4 sm:col-span-2"
          >
            <span
              class="block text-micro font-bold uppercase tracking-[0.16em] text-n-slate-10"
            >
              {{ t('MARKETING.PANEL.BY_ORIGIN') }}
            </span>
            <p
              v-if="!originRows.length"
              class="mb-0 mt-2 text-sm text-n-slate-9"
            >
              {{ t('MARKETING.PANEL.NO_DATA') }}
            </p>
            <dl v-else class="mt-2 grid gap-1">
              <div
                v-for="[origin, count] in originRows"
                :key="origin"
                class="flex items-baseline justify-between gap-3"
              >
                <dt class="min-w-0 break-words text-sm text-n-slate-11">
                  {{ origin }}
                </dt>
                <dd
                  class="mb-0 text-sm font-semibold tabular-nums text-n-slate-12"
                >
                  {{ count }}
                </dd>
              </div>
            </dl>
          </div>
        </section>

        <section
          v-if="campaignRows.length"
          class="rounded-xl border border-n-weak bg-n-solid-1 p-4"
        >
          <h3 class="mb-2 text-sm font-semibold text-n-slate-12">
            {{ t('MARKETING.PANEL.TOP_CAMPAIGNS') }}
          </h3>
          <dl class="grid gap-1">
            <div
              v-for="[campaign, count] in campaignRows"
              :key="campaign"
              class="flex items-baseline justify-between gap-3"
            >
              <dt class="min-w-0 break-words text-sm text-n-slate-11">
                {{ campaign }}
              </dt>
              <dd
                class="mb-0 text-sm font-semibold tabular-nums text-n-slate-12"
              >
                {{ count }}
              </dd>
            </div>
          </dl>
        </section>

        <section class="rounded-xl border border-n-weak bg-n-solid-1 p-4">
          <h3 class="mb-2 text-sm font-semibold text-n-slate-12">
            {{ t('MARKETING.PANEL.RECENT') }}
          </h3>
          <p v-if="isLoadingTouchpoints" class="mb-0 text-sm text-n-slate-11">
            {{ t('MARKETING.LOADING') }}
          </p>
          <p
            v-else-if="!touchpoints.length"
            class="mb-0 text-sm text-n-slate-9"
            data-testid="marketing-touchpoints-empty"
          >
            {{ t('MARKETING.PANEL.NO_TOUCHPOINTS') }}
          </p>
          <div v-else class="overflow-x-auto">
            <table
              class="w-full text-left text-sm"
              data-testid="marketing-touchpoints-table"
            >
              <thead>
                <tr class="text-n-slate-10">
                  <th class="py-2 pr-3 font-medium">
                    {{ t('MARKETING.TABLE.WHEN') }}
                  </th>
                  <th class="py-2 pr-3 font-medium">
                    {{ t('MARKETING.TABLE.ORIGIN') }}
                  </th>
                  <th class="py-2 pr-3 font-medium">
                    {{ t('MARKETING.TABLE.CAMPAIGN') }}
                  </th>
                  <th class="py-2 font-medium">
                    {{ t('MARKETING.TABLE.CONTACT') }}
                  </th>
                </tr>
              </thead>
              <tbody>
                <tr
                  v-for="touchpoint in touchpoints"
                  :key="touchpoint.id"
                  class="border-t border-n-weak"
                >
                  <td class="py-2 pr-3 tabular-nums text-n-slate-11">
                    {{ new Date(touchpoint.occurred_at).toLocaleString() }}
                  </td>
                  <td class="py-2 pr-3 text-n-slate-12">
                    {{
                      touchpoint.payload.origem_do_lead ||
                      t('MARKETING.TABLE.UNKNOWN')
                    }}
                  </td>
                  <td class="min-w-0 break-words py-2 pr-3 text-n-slate-11">
                    {{
                      touchpoint.payload.utm_campaign ||
                      t('MARKETING.TABLE.UNKNOWN')
                    }}
                  </td>
                  <td class="py-2">
                    <router-link
                      v-if="touchpoint.contact"
                      :to="contactPath(touchpoint.contact)"
                      class="text-n-brand hover:underline"
                    >
                      {{ touchpoint.contact.name }}
                    </router-link>
                    <span v-else class="text-n-slate-9">
                      {{ t('MARKETING.TABLE.NO_CONTACT') }}
                    </span>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </section>
      </template>
    </div>
  </div>
</template>
