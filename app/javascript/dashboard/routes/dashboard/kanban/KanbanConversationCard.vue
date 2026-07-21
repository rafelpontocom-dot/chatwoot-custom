<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { format } from 'date-fns';
import { dynamicTime, shortTimestamp } from 'shared/helpers/timeHelper';
import { CONVERSATION_PRIORITY } from 'shared/constants/messages';

import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import ChannelIcon from 'dashboard/components-next/icon/ChannelIcon.vue';
import InboxName from 'dashboard/components/widgets/InboxName.vue';
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
});

const emit = defineEmits(['openDetails', 'openConversation', 'removeCard']);

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
const inboxName = computed(
  () =>
    inbox.value?.name ||
    conversation.value?.meta?.channel ||
    t('KANBAN.CARD.UNKNOWN_INBOX')
);
const contactThumbnail = computed(
  () => contact.value?.thumbnail || contact.value?.avatarUrl || ''
);
const assignee = computed(() => conversation.value?.meta?.assignee || null);
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
  if (amountCents.value === null || amountCents.value === undefined) return '';

  return new Intl.NumberFormat('pt-BR', {
    style: 'currency',
    currency: amountCurrency.value,
  }).format(Number(amountCents.value) / 100);
});
const compactCustomFields = computed(
  () => props.card.compactCustomFields || props.card.compact_custom_fields || []
);
const compactFieldValue = field =>
  Array.isArray(field.value) ? field.value.join(', ') : String(field.value);
const staleInStage = computed(
  () => props.card.staleInStage || props.card.stale_in_stage
);
const nextActionStatus = computed(
  () => props.card.nextActionStatus || props.card.next_action_status || ''
);
const nextActionAt = computed(
  () => props.card.nextActionAt || props.card.next_action_at || ''
);
const nextActionStatusConfig = computed(() => {
  const configs = {
    missing: {
      label: t('KANBAN.CARD.NEXT_ACTION.MISSING'),
      icon: 'i-lucide-calendar-x',
      class: 'border-n-amber-5 bg-n-amber-2 text-n-amber-11',
    },
    overdue: {
      label: t('KANBAN.CARD.NEXT_ACTION.OVERDUE'),
      icon: 'i-lucide-clock-alert',
      class: 'border-n-ruby-5 bg-n-ruby-2 text-n-ruby-11',
    },
    due_today: {
      label: t('KANBAN.CARD.NEXT_ACTION.DUE_TODAY'),
      icon: 'i-lucide-calendar-clock',
      class: 'border-n-blue-5 bg-n-blue-2 text-n-blue-11',
    },
    future: {
      label: t('KANBAN.CARD.NEXT_ACTION.FUTURE'),
      icon: 'i-lucide-calendar',
      class: 'border-n-teal-5 bg-n-teal-2 text-n-teal-11',
    },
    closed: {
      label: t('KANBAN.CARD.NEXT_ACTION.CLOSED'),
      icon: 'i-lucide-circle-check',
      class: 'border-n-green-5 bg-n-green-2 text-n-green-11',
    },
  };

  return configs[nextActionStatus.value] || null;
});

const toUnixTimestamp = value => {
  if (!value) return null;
  if (typeof value === 'number') return value;

  const timestamp = Date.parse(value);
  return Number.isNaN(timestamp) ? null : Math.floor(timestamp / 1000);
};

const stageEnteredAt = computed(() =>
  toUnixTimestamp(props.card.stage_entered_at || props.card.stageEnteredAt)
);
const stageTime = computed(() =>
  stageEnteredAt.value
    ? shortTimestamp(dynamicTime(stageEnteredAt.value), true)
    : ''
);
const dueAt = computed(() => props.card.due_at || props.card.dueAt);
const dueAtLabel = computed(() => {
  if (!dueAt.value) return '';

  const dueDate = new Date(dueAt.value);
  return Number.isNaN(dueDate.getTime()) ? '' : format(dueDate, 'MMM d');
});
const nextActionAtLabel = computed(() => {
  if (!nextActionAt.value) return '';

  const actionDate = new Date(nextActionAt.value);
  return Number.isNaN(actionDate.getTime()) ? '' : format(actionDate, 'MMM d');
});

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
    class="card-drag-handle group relative cursor-grab rounded-lg border border-n-weak bg-n-surface-1 p-2"
    :data-card-id="card.id"
    :data-conversation-id="card.conversationId"
    @click="openDetails"
  >
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

    <div class="min-w-0 text-left">
      <p
        v-if="subject"
        class="truncate text-sm font-medium leading-4 text-n-slate-12"
        :title="subject"
      >
        {{ subject }}
      </p>

      <div class="mt-1 flex items-center gap-1.5">
        <button
          type="button"
          data-testid="kanban-card-contact-avatar"
          class="no-drag relative flex flex-shrink-0 rounded-full focus:outline-none focus:ring-1 focus:ring-n-brand"
          :title="contactName"
          @click.stop="openConversation"
        >
          <Avatar
            :name="contactName"
            :src="contactThumbnail"
            :size="28"
            rounded-full
          />
          <span
            v-if="inbox"
            class="absolute -bottom-1 -right-1 flex size-5 items-center justify-center rounded-full border border-n-surface-1 bg-n-surface-1"
          >
            <ChannelIcon :inbox="inbox" class="size-3.5 text-n-slate-11" />
          </span>
        </button>

        <h4
          class="min-w-0 flex-1 truncate text-xs font-medium leading-4 text-n-slate-12"
        >
          {{ contactName }}
        </h4>

        <Avatar
          v-if="assigneeName"
          :name="assigneeName"
          :src="assigneeThumbnail"
          :size="18"
          rounded-full
        />
      </div>

      <div class="mt-1 flex min-w-0">
        <div
          class="inline-flex max-w-full items-center rounded-md bg-n-alpha-2 px-1.5 py-0.5 text-xs leading-4"
        >
          <InboxName
            :inbox="{ ...inbox, name: inboxName }"
            :show-icon="false"
            class="max-w-full"
          />
        </div>
      </div>

      <div
        v-if="nextActionStatusConfig"
        data-testid="kanban-card-next-action"
        class="mt-1 inline-flex max-w-full items-center gap-1 rounded-md border px-1.5 py-0.5 text-xs leading-4"
        :class="nextActionStatusConfig.class"
      >
        <i
          class="size-3.5 flex-shrink-0"
          :class="nextActionStatusConfig.icon"
        />
        <span class="truncate">{{ nextActionStatusConfig.label }}</span>
        <span v-if="nextActionAtLabel" class="flex-shrink-0">
          {{ nextActionAtLabel }}
        </span>
      </div>

      <div
        v-if="amountLabel"
        data-testid="kanban-card-amount"
        class="mt-1 text-sm font-semibold text-n-slate-12"
      >
        {{ amountLabel }}
      </div>

      <div
        v-if="compactCustomFields.length"
        data-testid="kanban-card-custom-fields"
        class="mt-1 grid gap-0.5 text-xs leading-4 text-n-slate-11"
      >
        <p
          v-for="field in compactCustomFields"
          :key="field.key"
          class="mb-0 truncate"
          :title="`${field.label}: ${compactFieldValue(field)}`"
        >
          {{
            t('KANBAN.CARD.CUSTOM_FIELD', {
              label: field.label,
              value: compactFieldValue(field),
            })
          }}
        </p>
      </div>

      <div
        v-if="staleInStage"
        data-testid="kanban-card-stale"
        class="mt-1 inline-flex items-center gap-1 rounded-md border border-n-amber-5 bg-n-amber-2 px-1.5 py-0.5 text-xs text-n-amber-11"
      >
        <i class="i-lucide-hourglass size-3.5" />
        {{ t('KANBAN.CARD.STALE_IN_STAGE') }}
      </div>

      <div
        v-if="hasSupportedPriority || stageTime || dueAtLabel"
        data-testid="kanban-card-meta"
        class="mt-1 flex items-center justify-between gap-1.5 text-xs leading-4 text-n-slate-10"
      >
        <CardPriorityIcon
          v-if="hasSupportedPriority"
          :priority="priority"
          class="flex-shrink-0 !size-3.5"
        />
        <span v-else />

        <div class="flex min-w-0 items-center justify-end gap-1.5">
          <span
            v-if="stageTime"
            class="truncate"
            :title="dynamicTime(stageEnteredAt)"
          >
            {{ stageTime }}
          </span>
          <span v-if="dueAtLabel" class="flex-shrink-0" :title="dueAt">
            {{ dueAtLabel }}
          </span>
        </div>
      </div>
    </div>
  </article>
</template>
