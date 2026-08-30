<script setup>
/**
 * Raevo · Sereno — campanhas como tabela.
 *
 * Substitui `components-next/Campaigns/Pages/CampaignPage/CampaignList.vue`
 * mantendo o mesmo contrato (props `campaigns`/`isLiveChatType`, eventos
 * `edit`/`delete`), para trocar na página sem tocar em mais nada.
 *
 * COLUNAS: o mockup mostrava Público, Enviadas, Abertura e Respostas. Esses
 * dados NÃO existem no modelo de campanha do Chatwoot — inventá-los seria
 * mentir na tela. As colunas aqui são as que têm dado real.
 *
 * Esta tela é NOSSA. Ver docs/raevo-design-system.md §5.
 */
import { useI18n } from 'vue-i18n';
import { dateFormat } from 'shared/helpers/timeHelper';
import RaevoStamp from './RaevoStamp.vue';

const props = defineProps({
  campaigns: { type: Array, required: true },
  isLiveChatType: { type: Boolean, default: false },
});
const emit = defineEmits(['edit', 'delete']);
const { t } = useI18n();

const columns = [
  { key: 'NAME', label: t('CAMPAIGN.TABLE.NAME') },
  { key: 'CHANNEL', label: t('CAMPAIGN.TABLE.CHANNEL') },
  { key: 'STATUS', label: t('CAMPAIGN.TABLE.STATUS') },
  { key: 'SENDER', label: t('CAMPAIGN.TABLE.SENDER') },
  { key: 'SCHEDULED', label: t('CAMPAIGN.TABLE.SCHEDULED') },
  { key: 'ACTIONS', label: t('CAMPAIGN.TABLE.ACTIONS') },
];

// enum do back: active | completed | processing
const VARIANTE = {
  active: 'success',
  processing: 'warning',
  completed: 'neutral',
};

const situacao = campaign => {
  if (props.isLiveChatType) {
    return campaign.enabled === false
      ? { variant: 'neutral', chave: 'DISABLED' }
      : { variant: 'success', chave: 'ACTIVE' };
  }

  if (campaign.enabled === false)
    return { variant: 'neutral', chave: 'DISABLED' };
  const s = campaign.campaign_status || 'active';
  return { variant: VARIANTE[s] || 'neutral', chave: s.toUpperCase() };
};

const agendamento = campaign =>
  campaign.scheduled_at
    ? dateFormat(campaign.scheduled_at, 'dd/MM/yyyy HH:mm')
    : '—';

const statusLabel = campaign => {
  const { chave } = situacao(campaign);

  return {
    ACTIVE: t('CAMPAIGN.STATUS.ACTIVE'),
    PROCESSING: t('CAMPAIGN.STATUS.PROCESSING'),
    COMPLETED: t('CAMPAIGN.STATUS.COMPLETED'),
    DISABLED: t('CAMPAIGN.STATUS.DISABLED'),
  }[chave];
};
</script>

<template>
  <div
    class="overflow-hidden rounded-xl border border-n-weak bg-n-solid-1"
    data-testid="raevo-campaigns-table"
  >
    <table class="w-full border-collapse text-xs">
      <thead>
        <tr>
          <th
            v-for="column in columns"
            :key="column.key"
            scope="col"
            class="whitespace-nowrap border-b border-n-weak bg-n-slate-1 px-3 py-2.5 text-start text-micro font-bold uppercase tracking-[0.11em] text-n-slate-10"
            :class="column.key === 'ACTIONS' ? 'text-end' : ''"
          >
            <span v-if="column.key === 'ACTIONS'" class="sr-only">
              {{ column.label }}
            </span>
            <template v-else>{{ column.label }}</template>
          </th>
        </tr>
      </thead>
      <tbody>
        <tr
          v-for="campaign in campaigns"
          :key="campaign.id"
          class="border-b border-n-weak last:border-b-0 hover:bg-n-slate-2"
          :data-testid="`raevo-campaign-row-${campaign.id}`"
        >
          <td class="h-[52px] max-w-[22rem] px-3">
            <p
              class="truncate text-xs font-semibold text-n-slate-12"
              :title="campaign.title"
            >
              {{ campaign.title }}
            </p>
            <p
              v-if="campaign.message"
              class="truncate text-micro text-n-slate-10"
              :title="campaign.message"
            >
              {{ campaign.message }}
            </p>
          </td>
          <td class="whitespace-nowrap px-3 text-n-slate-11">
            {{ campaign.inbox?.name || '—' }}
          </td>
          <td class="px-3">
            <RaevoStamp
              :variant="situacao(campaign).variant"
              :label="statusLabel(campaign)"
              size="sm"
            />
          </td>
          <td class="max-w-[12rem] truncate px-3 text-n-slate-11">
            {{ campaign.sender?.name || '—' }}
          </td>
          <td class="whitespace-nowrap px-3 tabular-nums text-n-slate-11">
            {{ agendamento(campaign) }}
          </td>
          <td class="whitespace-nowrap px-3 text-end">
            <span class="inline-flex gap-1">
              <button
                type="button"
                class="flex size-8 items-center justify-center rounded-full text-n-slate-10 outline-none hover:bg-n-slate-3 hover:text-n-slate-12 focus-visible:ring-2 focus-visible:ring-n-brand"
                :aria-label="t('CAMPAIGN.TABLE.EDIT')"
                :title="t('CAMPAIGN.TABLE.EDIT')"
                @click="emit('edit', campaign)"
              >
                <i class="i-lucide-pencil size-4" />
              </button>
              <button
                type="button"
                class="flex size-8 items-center justify-center rounded-full text-n-ruby-11 outline-none hover:bg-n-ruby-3 focus-visible:ring-2 focus-visible:ring-n-ruby-9"
                :aria-label="t('CAMPAIGN.TABLE.DELETE')"
                :title="t('CAMPAIGN.TABLE.DELETE')"
                @click="emit('delete', campaign)"
              >
                <i class="i-lucide-trash-2 size-4" />
              </button>
            </span>
          </td>
        </tr>
      </tbody>
    </table>
  </div>
</template>
