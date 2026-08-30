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
      class: 'bg-n-amber-3 text-n-amber-11',
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
    class="card-drag-handle group relative cursor-grab rounded-lg border border-n-weak bg-n-solid-1 p-3 transition-[border-color,box-shadow,transform] hover:-translate-y-px hover:border-n-slate-8 hover:shadow focus:outline-none focus:ring-2 focus:ring-n-brand"
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
      class="no-drag absolute left-2 top-2 size-4 rounded border-n-weak text-n-brand opacity-0 focus:opacity-100 focus:ring-n-brand group-hover:opacity-100"
      :class="selected ? 'opacity-100' : ''"
      :checked="selected"
      :aria-label="t('KANBAN.CARD.SELECT')"
      @click.stop
      @change="emit('toggleSelection', card, $event.target.checked)"
    />
    <button
      type="button"
      data-testid="kanban-card-open-details"
      class="no-drag pointer-events-auto absolute right-10 top-1.5 flex size-8 items-center justify-center rounded-md border border-n-weak bg-n-surface-1 text-n-slate-11 opacity-0 shadow-sm transition-opacity hover:bg-n-alpha-2 hover:text-n-slate-12 focus:opacity-100 focus:outline-none focus:ring-1 focus:ring-n-brand group-hover:opacity-100"
      :aria-label="t('KANBAN.ACTIONS.OPEN_CARD_DETAILS')"
      :title="t('KANBAN.ACTIONS.OPEN_CARD_DETAILS')"
      @click.stop="openDetails"
    >
      <i class="i-lucide-square-pen size-4" />
    </button>
    <button
      type="button"
      data-testid="kanban-card-remove"
      class="no-drag pointer-events-auto absolute top-1.5 ltr:right-1.5 rtl:left-1.5 flex size-8 items-center justify-center rounded-md border border-n-weak bg-n-surface-1 text-n-ruby-11 opacity-0 shadow-sm transition-opacity hover:bg-n-ruby-2 focus:opacity-100 focus:outline-none focus:ring-1 focus:ring-n-ruby-8 group-hover:opacity-100 disabled:cursor-not-allowed disabled:opacity-50"
      :aria-label="t('KANBAN.ACTIONS.REMOVE_CARD')"
      :title="t('KANBAN.ACTIONS.REMOVE_CARD')"
      :disabled="!!activeActionKey"
      @click.stop="emit('removeCard', card)"
    >
      <i class="i-lucide-trash size-5" />
    </button>

    <div class="min-w-0 pl-6 pr-16 text-left">
      <!-- Sereno: a pessoa é a manchete; o assunto da oportunidade é apoio.
           No mockup aprovado o nome vem primeiro, ao lado do avatar quadrado. -->
      <div class="flex min-w-0 items-center gap-2.5">
        <button
          type="button"
          data-testid="kanban-card-contact-avatar"
          class="no-drag relative flex flex-shrink-0 rounded-lg focus:outline-none focus:ring-2 focus:ring-n-brand"
          :title="contactName"
          @click.stop="openConversation"
        >
          <Avatar :name="contactName" :src="contactThumbnail" :size="30" />
          <span
            v-if="inbox"
            class="absolute -bottom-1 -right-1 flex size-4.5 items-center justify-center rounded-full border border-n-solid-1 bg-n-solid-1"
          >
            <ChannelIcon :inbox="inbox" class="size-3.5 text-n-slate-11" />
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
              class="min-w-0 flex-1 truncate text-[12.5px] font-bold leading-4 tracking-tight text-n-slate-12"
            >
              {{ contactName }}
            </h4>
          </div>
          <p
            v-if="subject"
            class="mt-0.5 truncate text-[10.5px] leading-4 text-n-slate-10"
            :title="subject"
          >
            {{ subject }}
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

      <div
        v-if="nextActionStatusConfig || amountLabel || hasConversation"
        data-testid="kanban-card-workflow-summary"
        class="mt-2.5 flex min-w-0 items-center justify-between gap-2 border-t border-n-weak pt-2.5"
      >
        <div
          v-if="nextActionStatusConfig"
          data-testid="kanban-card-next-action"
          class="inline-flex min-w-0 items-center gap-1.5 rounded-full px-2.5 py-1 text-[10px] font-medium leading-4"
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
          <strong
            v-if="amountLabel"
            data-testid="kanban-card-amount"
            class="whitespace-nowrap text-[12.5px] font-extrabold tabular-nums tracking-tight text-n-slate-12"
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
