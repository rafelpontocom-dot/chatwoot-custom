<script setup>
import { computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';

import { useStore } from 'dashboard/composables/store';
import ConversationBox from 'dashboard/components/widgets/conversation/ConversationBox.vue';

const props = defineProps({
  conversationId: { type: [Number, String], default: null },
  title: { type: String, default: '' },
  show: { type: Boolean, default: false },
});

const emit = defineEmits(['close', 'openFullConversation']);
const { t } = useI18n();
const store = useStore();

const hasConversation = computed(() => Number(props.conversationId) > 0);

const activateConversation = async () => {
  if (!props.show || !hasConversation.value) return;

  await store.dispatch('getConversation', Number(props.conversationId));
  const conversation = store.getters.getConversationById(
    Number(props.conversationId)
  );
  if (conversation?.id) {
    await store.dispatch('setActiveChat', { data: conversation });
  }
};

watch(() => [props.show, props.conversationId], activateConversation, {
  immediate: true,
});
</script>

<template>
  <div>
    <aside
      v-if="show"
      data-testid="kanban-conversation-drawer"
      class="fixed inset-y-0 right-0 z-50 flex w-full max-w-3xl flex-col border-l border-n-weak bg-n-surface-1 shadow-2xl"
      role="dialog"
      aria-modal="true"
      :aria-label="t('KANBAN.CONVERSATION_DRAWER.TITLE')"
      @keydown.esc="emit('close')"
    >
      <header
        class="flex shrink-0 items-center justify-between gap-3 border-b border-n-weak px-4 py-3"
      >
        <div class="min-w-0">
          <p class="mb-0 truncate text-sm font-semibold text-n-slate-12">
            {{ title }}
          </p>
        </div>
        <div class="flex items-center gap-1">
          <button
            type="button"
            class="flex p-0 size-9 items-center justify-center rounded-md text-n-slate-11 outline-none hover:bg-n-alpha-2 hover:text-n-slate-12 focus:ring-2 focus:ring-n-brand/40"
            :aria-label="t('KANBAN.CONVERSATION_DRAWER.OPEN_FULL')"
            :title="t('KANBAN.CONVERSATION_DRAWER.OPEN_FULL')"
            @click="emit('openFullConversation')"
          >
            <i class="i-lucide-external-link size-4" />
          </button>
          <button
            type="button"
            data-testid="kanban-conversation-drawer-close"
            class="flex p-0 size-9 items-center justify-center rounded-md text-n-slate-11 outline-none hover:bg-n-alpha-2 hover:text-n-slate-12 focus:ring-2 focus:ring-n-brand/40"
            :aria-label="t('GENERAL.CLOSE')"
            @click="emit('close')"
          >
            <i class="i-lucide-x size-4" />
          </button>
        </div>
      </header>
      <ConversationBox
        class="min-h-0 flex-1"
        :inbox-id="0"
        is-inbox-view
        is-on-expanded-layout
      />
    </aside>
  </div>
</template>
