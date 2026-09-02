<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { onClickOutside, onKeyStroke } from '@vueuse/core';

/**
 * Raevo — balão do agendamento, no formato do Google Calendar.
 *
 * Clicar num agendamento abria um diálogo modal de 543 linhas com sete botões
 * no rodapé, para responder a perguntas que quase sempre são duas: quem é, e a
 * que horas. O Google responde a essas num balão ancorado no próprio evento,
 * com as ações em ícones no topo, e guarda o resto atrás de "mais detalhes".
 *
 * Este balão não substitui o diálogo: ele adia-o. As ações que mudam a situação
 * do agendamento passam pelas mesmas chamadas de sempre — quem decide continua
 * a ser o servidor.
 */
const props = defineProps({
  appointment: { type: Object, default: null },
  anchor: { type: Object, default: null },
  isSaving: { type: Boolean, default: false },
});

// `action` só transporta o que se resolve aqui mesmo. Cancelar exige motivo e
// âmbito, e remarcar exige escolher horário: essas duas abrem o diálogo, onde
// os campos existem — o balão não finge que consegue decidir por elas.
const emit = defineEmits([
  'close',
  'action',
  'openDetails',
  'reschedule',
  'cancel',
]);
const { t } = useI18n();

const balao = ref(null);

// Um balão que só fecha no ✕ prende quem o abriu por engano. O Google fecha-o
// ao clicar fora e no Escape; sem isto, a grade por baixo ficava inerte.
onClickOutside(balao, () => {
  if (props.appointment) emit('close');
});

onKeyStroke('Escape', event => {
  if (!props.appointment) return;
  event.stopPropagation();
  emit('close');
});

const estilo = computed(() => {
  if (!props.anchor) return {};
  return { top: `${props.anchor.top}px`, left: `${props.anchor.left}px` };
});

const STATUS_LABEL = {
  scheduled: 'CALENDAR.DETAIL.STATUS.SCHEDULED',
  confirmed: 'CALENDAR.DETAIL.STATUS.CONFIRMED',
  checked_in: 'CALENDAR.DETAIL.STATUS.CHECKED_IN',
  completed: 'CALENDAR.DETAIL.STATUS.COMPLETED',
  no_show: 'CALENDAR.DETAIL.STATUS.NO_SHOW',
  canceled: 'CALENDAR.DETAIL.STATUS.CANCELED',
};

// A situação nunca é dada só pela cor: o ponto acompanha sempre a palavra.
const STATUS_TONE = {
  scheduled: 'bg-n-slate-9',
  confirmed: 'bg-n-teal-9',
  checked_in: 'bg-n-brand',
  completed: 'bg-n-teal-10',
  no_show: 'bg-n-amber-9',
  canceled: 'bg-n-ruby-9',
};

const statusLabel = computed(() =>
  props.appointment ? t(STATUS_LABEL[props.appointment.status] || '') : ''
);

const statusTone = computed(
  () => STATUS_TONE[props.appointment?.status] || 'bg-n-slate-9'
);

/** "sexta-feira, 4 de setembro · 09:00 – 09:50" — uma linha, como no Google. */
const timeLabel = computed(() => {
  if (!props.appointment) return '';
  const inicio = new Date(props.appointment.starts_at);
  const fim = new Date(props.appointment.ends_at);
  // Dia e mês abreviados para a linha caber inteira nos 320px: partida em duas,
  // a hora de fim afasta-se da de início e deixa de se ler de um relance. O dia
  // da semana por extenso não faz falta — o balão está ancorado na coluna dele.
  const dia = new Intl.DateTimeFormat(undefined, {
    weekday: 'short',
    day: 'numeric',
    month: 'short',
  }).format(inicio);
  const hora = new Intl.DateTimeFormat(undefined, {
    hour: '2-digit',
    minute: '2-digit',
  });
  return `${dia} · ${hora.format(inicio)} – ${hora.format(fim)}`;
});

const resourceLabel = computed(() =>
  (props.appointment?.resources || []).map(item => item.name).join(', ')
);

const isActive = computed(
  () =>
    props.appointment &&
    !['canceled', 'completed', 'no_show'].includes(props.appointment.status)
);

/**
 * Uma ação principal de cada vez, a que segue no fluxo do atendimento.
 * Empilhar as seis no rodapé — como fazia o diálogo — obriga a ler todas para
 * encontrar a única que interessa neste momento.
 */
const primaryAction = computed(() => {
  if (!isActive.value) return null;
  if (props.appointment.status === 'scheduled')
    return { action: 'confirm', label: 'CALENDAR.DETAIL.CONFIRM' };
  if (props.appointment.status === 'confirmed')
    return { action: 'check_in', label: 'CALENDAR.DETAIL.CHECK_IN' };
  return { action: 'complete', label: 'CALENDAR.DETAIL.COMPLETE' };
});
</script>

<template>
  <div
    v-if="appointment"
    ref="balao"
    data-testid="calendar-event-popover"
    class="fixed z-50 w-80 rounded-xl border border-n-weak bg-n-solid-1 shadow-lg"
    :style="estilo"
    role="dialog"
    :aria-label="t('CALENDAR.DETAIL.TITLE')"
  >
    <div class="flex items-center justify-end gap-0.5 px-2 pt-2">
      <button
        v-if="isActive"
        type="button"
        class="flex p-0 size-8 items-center justify-center rounded-full text-n-slate-11 outline-none hover:bg-n-alpha-2 focus-visible:ring-2 focus-visible:ring-n-brand"
        :title="t('CALENDAR.DETAIL.RESCHEDULE')"
        :aria-label="t('CALENDAR.DETAIL.RESCHEDULE')"
        data-testid="calendar-event-reschedule"
        @click="emit('reschedule')"
      >
        <i class="i-lucide-clock size-4" aria-hidden="true" />
      </button>
      <button
        v-if="isActive"
        type="button"
        class="flex p-0 size-8 items-center justify-center rounded-full text-n-slate-11 outline-none hover:bg-n-alpha-2 focus-visible:ring-2 focus-visible:ring-n-brand"
        :title="t('CALENDAR.DETAIL.CANCEL')"
        :aria-label="t('CALENDAR.DETAIL.CANCEL')"
        data-testid="calendar-event-cancel"
        @click="emit('cancel')"
      >
        <i class="i-lucide-trash-2 size-4" aria-hidden="true" />
      </button>
      <button
        type="button"
        class="flex p-0 size-8 items-center justify-center rounded-full text-n-slate-11 outline-none hover:bg-n-alpha-2 focus-visible:ring-2 focus-visible:ring-n-brand"
        :title="t('CALENDAR.DETAIL.TITLE')"
        :aria-label="t('CALENDAR.DETAIL.TITLE')"
        data-testid="calendar-event-details"
        @click="emit('openDetails')"
      >
        <i class="i-lucide-ellipsis-vertical size-4" aria-hidden="true" />
      </button>
      <button
        type="button"
        class="flex p-0 size-8 items-center justify-center rounded-full text-n-slate-11 outline-none hover:bg-n-alpha-2 focus-visible:ring-2 focus-visible:ring-n-brand"
        :title="t('GENERAL.CLOSE')"
        :aria-label="t('GENERAL.CLOSE')"
        data-testid="calendar-event-close"
        @click="emit('close')"
      >
        <i class="i-lucide-x size-4" aria-hidden="true" />
      </button>
    </div>

    <div class="grid gap-3 px-4 pb-4">
      <div class="flex items-start gap-3">
        <span
          class="mt-1.5 size-3 shrink-0 rounded-sm"
          :class="statusTone"
          aria-hidden="true"
        />
        <div class="grid min-w-0 gap-0.5">
          <h3
            class="mb-0 truncate text-base font-medium text-n-slate-12"
            data-testid="calendar-event-title"
          >
            {{ appointment.contact.name }}
          </h3>
          <p class="mb-0 text-sm text-n-slate-11">{{ timeLabel }}</p>
        </div>
      </div>

      <dl class="grid gap-2 text-sm">
        <div class="flex items-start gap-3">
          <i
            class="i-lucide-stethoscope mt-0.5 size-4 shrink-0 text-n-slate-10"
            aria-hidden="true"
          />
          <dt class="sr-only">{{ t('CALENDAR.SETTINGS.PROCEDURES') }}</dt>
          <dd class="mb-0 min-w-0 truncate text-n-slate-12">
            {{ appointment.procedure.name }}
          </dd>
        </div>
        <div v-if="resourceLabel" class="flex items-start gap-3">
          <i
            class="i-lucide-user mt-0.5 size-4 shrink-0 text-n-slate-10"
            aria-hidden="true"
          />
          <dt class="sr-only">{{ t('CALENDAR.DETAIL.RESOURCE') }}</dt>
          <dd
            class="mb-0 min-w-0 truncate text-n-slate-12"
            data-testid="calendar-event-resource"
          >
            {{ resourceLabel }}
          </dd>
        </div>
        <div class="flex items-start gap-3">
          <i
            class="i-lucide-circle-check mt-0.5 size-4 shrink-0 text-n-slate-10"
            aria-hidden="true"
          />
          <dt class="sr-only">{{ t('CALENDAR.DETAIL.STATUS_LABEL') }}</dt>
          <dd class="mb-0 text-n-slate-12" data-testid="calendar-event-status">
            {{ statusLabel }}
          </dd>
        </div>
      </dl>

      <button
        v-if="primaryAction"
        type="button"
        class="h-9 w-full rounded-full bg-n-brand text-sm font-medium text-white outline-none transition-colors hover:bg-n-brand/90 focus-visible:ring-2 focus-visible:ring-n-brand/40 disabled:cursor-not-allowed disabled:opacity-60"
        :disabled="isSaving"
        data-testid="calendar-event-primary"
        @click="emit('action', primaryAction.action)"
      >
        {{ t(primaryAction.label) }}
      </button>
    </div>
  </div>
</template>
