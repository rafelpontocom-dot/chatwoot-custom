<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { format } from 'date-fns';
import { CONVERSATION_PRIORITY } from 'shared/constants/messages';

import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import ChannelIcon from 'dashboard/components-next/icon/ChannelIcon.vue';
import CardPriorityIcon from 'dashboard/components-next/Conversation/ConversationCard/CardPriorityIcon.vue';

const props = defineProps({
  card: {
    type: Object,
    required: true,
  },
  activeActionKey: {
    type: String,
    default: '',
  },
  selected: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits([
  'openDetails',
  'openConversation',
  'removeCard',
  'toggleSelection',
]);

/**
 * Três é o teto: acima disso o cartão deixa de se ler de relance, que é a única
 * coisa que um quadro tem de fazer bem. O resto vive no detalhe.
 */
const COMPACT_FIELD_LIMIT = 3;

const { t } = useI18n();
const store = useStore();

const conversation = computed(() => props.card.conversation || {});
const contact = computed(
  () => props.card.contact || conversation.value?.meta?.sender || {}
);
const inbox = computed(
  () =>
    props.card.inbox ||
    store.getters['inboxes/getInboxById'](conversation.value.inboxId)
);

const hasConversation = computed(() => !!props.card.conversationId);
const contactName = computed(
  () => contact.value?.name || t('KANBAN.CARD.UNKNOWN_CONTACT')
);
const priority = computed(() => conversation.value.priority || '');
const hasSupportedPriority = computed(() =>
  Object.values(CONVERSATION_PRIORITY).includes(priority.value)
);
const contactThumbnail = computed(
  () => contact.value?.thumbnail || contact.value?.avatarUrl || ''
);
const assignee = computed(
  () =>
    props.card.owner ||
    props.card.assignee ||
    conversation.value?.meta?.assignee ||
    null
);
const assigneeName = computed(() => assignee.value?.name || '');
const assigneeThumbnail = computed(
  () => assignee.value?.thumbnail || assignee.value?.avatarUrl || ''
);
const subject = computed(() => props.card.subject || '');

/**
 * Num funil comercial vende-se a oportunidade, não a pessoa: o assunto é que
 * manda no cartão. O contacto passa a subtítulo — e some quando repetiria o
 * título, como em «Maria Raevo / Jornada QA - Maria Raevo», onde o cartão
 * dizia o mesmo nome duas vezes e mais nada de útil.
 *
 * Sem assunto, o contacto sobe a título: um cartão tem sempre de dizer de quem é.
 */
const cardTitle = computed(() => subject.value || contactName.value);
const cardSubtitle = computed(() => {
  if (!subject.value) return '';
  if (subject.value.includes(contactName.value)) return '';

  return contactName.value;
});

/**
 * Os campos que a conta escolheu mostrar no cartão, em Definições do funil →
 * Sales fields → Card layout.
 *
 * A configuração existia, era guardada em `compact_card_field_keys` e a API já
 * a servia resolvida em cada cartão — só que o cartão nunca a lia. Configurar
 * o layout não mudava nada, o que é pior do que não o oferecer.
 */
const compactFields = computed(() =>
  (
    props.card.compactCustomFields ||
    props.card.compact_custom_fields ||
    []
  ).slice(0, COMPACT_FIELD_LIMIT)
);

const formatCompactValue = field => {
  const { value } = field;
  if (Array.isArray(value)) return value.join(', ');
  if (typeof value === 'boolean') {
    return value ? t('KANBAN.CARD.YES') : t('KANBAN.CARD.NO');
  }

  return String(value ?? '');
};
const amountCents = computed(
  () => props.card.amountCents ?? props.card.amount_cents
);
const amountCurrency = computed(
  () => props.card.amountCurrency || props.card.amount_currency || 'BRL'
);
const amountLabel = computed(() => {
  if (
    amountCents.value === null ||
    amountCents.value === undefined ||
    amountCents.value === ''
  ) {
    return '';
  }

  return new Intl.NumberFormat('pt-BR', {
    style: 'currency',
    currency: amountCurrency.value,
  }).format(Number(amountCents.value) / 100);
});
// Tempo na etapa: o card dizia quem é, nunca há quanto tempo está parado. Numa
// clínica o dinheiro se perde por silêncio, não por recusa. O backend já enviava
// `stage_entered_at` e `stale_in_stage` — faltava mostrar.
const stageEnteredAt = computed(
  () => props.card.stageEnteredAt || props.card.stage_entered_at || ''
);
const isStaleInStage = computed(
  () => props.card.staleInStage ?? props.card.stale_in_stage ?? false
);
const daysInStage = computed(() => {
  if (!stageEnteredAt.value) return null;

  const entered = new Date(stageEnteredAt.value);
  if (Number.isNaN(entered.getTime())) return null;

  const days = Math.floor((Date.now() - entered.getTime()) / 86400000);
  return days < 0 ? 0 : days;
});
const stageTimeLabel = computed(() => {
  const days = daysInStage.value;
  if (days === null) return '';
  if (days === 0) return t('KANBAN.CARD.STAGE_TIME.TODAY');
  return t('KANBAN.CARD.STAGE_TIME.DAYS', days, { count: days });
});
// Estado nunca só por cor (regra 5 do design system): a cor muda junto do ícone,
// e o número de dias continua legível em qualquer um dos três estados.
const stageTimeTone = computed(() => {
  if (!isStaleInStage.value) {
    return { class: 'text-n-slate-10', icon: 'i-lucide-clock' };
  }
  return { class: 'text-n-amber-11', icon: 'i-lucide-clock-alert' };
});

const nextActionStatus = computed(
  () => props.card.nextActionStatus || props.card.next_action_status || ''
);
const nextActionAt = computed(
  () => props.card.nextActionAt || props.card.next_action_at || ''
);
const nextActionType = computed(
  () => props.card.nextActionType || props.card.next_action_type || ''
);
const nextActionStatusConfig = computed(() => {
  const configs = {
    missing: {
      label: t('KANBAN.CARD.NEXT_ACTION.MISSING'),
      icon: 'i-lucide-calendar-x',
      // Neutro de propósito: não ter próxima ação marcada é o estado inicial
      // de toda a oportunidade, não uma falha. Em âmbar, o quadro inteiro
      // acendia e o âmbar deixava de querer dizer nada.
      class: 'bg-n-alpha-2 text-n-slate-11',
    },
    overdue: {
      label: t('KANBAN.CARD.NEXT_ACTION.OVERDUE'),
      icon: 'i-lucide-clock-alert',
      class: 'bg-n-ruby-3 text-n-ruby-11',
    },
    due_today: {
      label: t('KANBAN.CARD.NEXT_ACTION.DUE_TODAY'),
      icon: 'i-lucide-calendar-clock',
      class: 'bg-n-blue-3 text-n-blue-11',
    },
    future: {
      label: t('KANBAN.CARD.NEXT_ACTION.FUTURE'),
      icon: 'i-lucide-calendar',
      class: 'bg-n-teal-3 text-n-teal-11',
    },
    closed: {
      label: t('KANBAN.CARD.NEXT_ACTION.CLOSED'),
      icon: 'i-lucide-circle-check',
      class: 'border-n-green-5 bg-n-green-2 text-n-green-11',
    },
  };

  return configs[nextActionStatus.value] || null;
});
const nextActionAtLabel = computed(() => {
  if (!nextActionAt.value) return '';

  const actionDate = new Date(nextActionAt.value);
  return Number.isNaN(actionDate.getTime()) ? '' : format(actionDate, 'MMM d');
});
const nextActionLabel = computed(
  () => nextActionType.value || nextActionStatusConfig.value?.label || ''
);
const openDetails = event => {
  emit('openDetails', props.card, event);
};

const openConversation = event => {
  if (!hasConversation.value) return;

  emit('openConversation', props.card, event);
};
</script>

<template>
  <article
    class="card-drag-handle group relative cursor-grab rounded-lg border border-n-weak bg-n-solid-1 p-2.5 transition-[border-color,box-shadow,transform] hover:-translate-y-px hover:border-n-slate-8 hover:shadow focus:outline-none focus:ring-2 focus:ring-n-brand"
    :class="selected ? 'ring-2 ring-n-brand border-transparent' : ''"
    :data-card-id="card.id"
    :data-conversation-id="card.conversationId"
    role="button"
    tabindex="0"
    :aria-label="contactName"
    @click="openDetails"
    @keydown.enter.prevent="openDetails"
    @keydown.space.prevent="openDetails"
  >
    <input
      type="checkbox"
      data-testid="kanban-card-select"
      class="no-drag absolute left-3 top-3.5 z-10 size-4 rounded border-n-strong bg-n-solid-1 text-n-brand opacity-0 focus:opacity-100 focus:ring-2 focus:ring-n-brand group-hover:opacity-100"
      :class="selected ? 'opacity-100' : ''"
      :checked="selected"
      :aria-label="t('KANBAN.CARD.SELECT')"
      @click.stop
      @change="emit('toggleSelection', card, $event.target.checked)"
    />
    <button
      type="button"
      data-testid="kanban-card-open-details"
      class="no-drag pointer-events-auto absolute right-9 top-2 flex size-7 items-center justify-center rounded-full border border-n-weak bg-n-solid-1 text-n-slate-11 opacity-0 shadow transition-opacity hover:bg-n-slate-3 hover:text-n-slate-12 focus:opacity-100 focus:outline-none focus:ring-2 focus:ring-n-brand group-hover:opacity-100"
      :aria-label="t('KANBAN.ACTIONS.OPEN_CARD_DETAILS')"
      :title="t('KANBAN.ACTIONS.OPEN_CARD_DETAILS')"
      @click.stop="openDetails"
    >
      <i class="i-lucide-square-pen size-3.5" />
    </button>
    <button
      type="button"
      data-testid="kanban-card-remove"
      class="no-drag pointer-events-auto absolute top-2 ltr:right-2 rtl:left-2 flex size-7 items-center justify-center rounded-full border border-n-weak bg-n-solid-1 text-n-ruby-11 opacity-0 shadow transition-opacity hover:bg-n-ruby-3 focus:opacity-100 focus:outline-none focus:ring-2 focus:ring-n-ruby-9 group-hover:opacity-100 disabled:cursor-not-allowed disabled:opacity-50"
      :aria-label="t('KANBAN.ACTIONS.REMOVE_CARD')"
      :title="t('KANBAN.ACTIONS.REMOVE_CARD')"
      :disabled="!!activeActionKey"
      @click.stop="emit('removeCard', card)"
    >
      <i class="i-lucide-trash-2 size-3.5" />
    </button>

    <div class="min-w-0 text-left">
      <!-- Sereno: a pessoa é a manchete; o assunto da oportunidade é apoio.
           No mockup aprovado o nome vem primeiro, ao lado do avatar quadrado. -->
      <div class="flex min-w-0 items-center gap-2">
        <button
          type="button"
          data-testid="kanban-card-contact-avatar"
          class="no-drag relative flex flex-shrink-0 rounded-lg focus:outline-none focus:ring-2 focus:ring-n-brand"
          :title="contactName"
          @click.stop="openConversation"
        >
          <Avatar :name="contactName" :src="contactThumbnail" :size="24" />
          <span
            v-if="inbox"
            class="absolute -bottom-0.5 -right-0.5 flex size-3.5 items-center justify-center rounded-full bg-n-solid-1 ring-2 ring-n-solid-1"
          >
            <ChannelIcon :inbox="inbox" class="size-2.5 text-n-slate-10" />
          </span>
        </button>

        <div class="min-w-0 flex-1">
          <div class="flex min-w-0 items-center gap-1.5">
            <CardPriorityIcon
              v-if="hasSupportedPriority"
              :priority="priority"
              class="flex-shrink-0 !size-3.5"
            />
            <h4
              class="line-clamp-2 min-w-0 flex-1 break-words text-xs font-bold leading-[15px] tracking-tight text-n-slate-12"
              :title="cardTitle"
            >
              {{ cardTitle }}
            </h4>
          </div>
          <!--
            O assunto é o que a oportunidade é. Cortado a meio — «Inquérito
            Pré-Consulta de ...» — obrigava a abrir o cartão para saber de que
            se tratava. Duas linhas chegam para quase todos e mantêm a altura
            do cartão previsível.
          -->
          <p
            v-if="cardSubtitle"
            data-testid="kanban-card-subtitle"
            class="break-words text-micro leading-[14px] text-n-slate-10"
          >
            {{ cardSubtitle }}
          </p>
        </div>

        <Avatar
          v-if="assigneeName"
          :name="assigneeName"
          :src="assigneeThumbnail"
          :size="18"
          rounded-full
        />
      </div>

      <dl
        v-if="compactFields.length"
        data-testid="kanban-card-compact-fields"
        class="mt-2 flex flex-wrap gap-x-3 gap-y-1"
      >
        <div
          v-for="field in compactFields"
          :key="field.key"
          class="flex min-w-0 items-baseline gap-1"
        >
          <dt class="shrink-0 text-micro text-n-slate-10">{{ field.label }}</dt>
          <dd
            class="mb-0 min-w-0 break-words text-micro font-semibold tabular-nums text-n-slate-12"
          >
            {{ formatCompactValue(field) }}
          </dd>
        </div>
      </dl>

      <div
        v-if="
          nextActionStatusConfig ||
          amountLabel ||
          hasConversation ||
          stageTimeLabel
        "
        data-testid="kanban-card-workflow-summary"
        class="mt-2 flex min-w-0 items-center justify-between gap-2"
      >
        <div
          v-if="nextActionStatusConfig"
          data-testid="kanban-card-next-action"
          class="inline-flex min-w-0 items-center gap-1 rounded-full px-2 py-0.5 text-micro font-semibold leading-4"
          :class="nextActionStatusConfig.class"
        >
          <i
            class="size-3.5 flex-shrink-0"
            :class="nextActionStatusConfig.icon"
          />
          <span class="truncate" :title="nextActionLabel">{{
            nextActionLabel
          }}</span>
          <span v-if="nextActionAtLabel" class="flex-shrink-0">
            {{ nextActionAtLabel }}
          </span>
        </div>

        <div class="ml-auto flex shrink-0 items-center gap-1.5">
          <span
            v-if="stageTimeLabel"
            data-testid="kanban-card-stage-time"
            class="inline-flex flex-shrink-0 items-center gap-1 whitespace-nowrap text-micro font-semibold tabular-nums"
            :class="stageTimeTone.class"
            :title="t('KANBAN.CARD.STAGE_TIME.TITLE')"
          >
            <i class="size-3 flex-shrink-0" :class="stageTimeTone.icon" />
            {{ stageTimeLabel }}
          </span>

          <strong
            v-if="amountLabel"
            data-testid="kanban-card-amount"
            class="whitespace-nowrap text-xs font-extrabold tabular-nums tracking-tight text-n-slate-12"
          >
            {{ amountLabel }}
          </strong>

          <button
            v-if="hasConversation"
            type="button"
            data-testid="kanban-card-open-conversation"
            class="no-drag flex size-7 items-center justify-center rounded-md text-n-slate-10 outline-none hover:bg-n-alpha-2 hover:text-n-slate-12 focus:ring-2 focus:ring-n-brand/40"
            :aria-label="t('KANBAN.OPPORTUNITY_DETAILS.OPEN_CONVERSATION')"
            :title="t('KANBAN.OPPORTUNITY_DETAILS.OPEN_CONVERSATION')"
            @click.stop="openConversation"
          >
            <i class="i-lucide-message-circle size-4" />
          </button>
        </div>
      </div>
    </div>
  </article>
</template>
