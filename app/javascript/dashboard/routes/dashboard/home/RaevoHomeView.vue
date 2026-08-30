<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import RaevoHomeAPI from 'dashboard/api/raevoHome';
import RaevoPageHeader from 'dashboard/components-next/raevo/RaevoPageHeader.vue';
import RaevoStamp from 'dashboard/components-next/raevo/RaevoStamp.vue';

const { t, locale } = useI18n();
const route = useRoute();
const router = useRouter();
const data = ref({
  open_conversations_count: 0,
  open_conversations: [],
  overdue_actions: [],
});
const isLoading = ref(true);
const hasError = ref(false);

const openConversations = computed(() => data.value.open_conversations || []);
const overdueActions = computed(() => data.value.overdue_actions || []);
const totalAttention = computed(
  () =>
    Number(data.value.open_conversations_count || 0) +
    overdueActions.value.length
);

const loadHome = async () => {
  isLoading.value = true;
  hasError.value = false;

  try {
    const response = await RaevoHomeAPI.get();
    data.value = response.data;
  } catch {
    hasError.value = true;
  } finally {
    isLoading.value = false;
  }
};

const openConversation = conversation => {
  router.push({
    name: 'inbox_conversation',
    params: {
      accountId: route.params.accountId,
      conversation_id: conversation.display_id,
    },
  });
};

const openOpportunity = action => {
  router.push({
    name: 'kanban_board_show',
    params: {
      accountId: route.params.accountId,
      boardId: action.kanban_board_id,
    },
    query: { cardId: action.kanban_card_id },
  });
};

const formatDateTime = value => {
  if (!value) return '';

  return new Intl.DateTimeFormat(
    locale.value === 'pt_BR' ? 'pt-BR' : locale.value,
    {
      dateStyle: 'short',
      timeStyle: 'short',
    }
  ).format(new Date(value));
};

onMounted(loadHome);
</script>

<template>
  <main class="mx-auto flex w-full max-w-[96rem] flex-col gap-4 p-4 lg:p-6">
    <RaevoPageHeader
      :eyebrow="t('HOME.EYEBROW')"
      :title="t('HOME.TITLE')"
      :badge="String(totalAttention)"
      :subtitle="t('HOME.SUBTITLE')"
    >
      <template #actions>
        <button
          type="button"
          class="inline-flex size-9 items-center justify-center rounded-lg text-n-slate-11 hover:bg-n-alpha-2 focus:outline-none focus:ring-2 focus:ring-n-brand/40"
          :aria-label="t('HOME.REFRESH')"
          :title="t('HOME.REFRESH')"
          @click="loadHome"
        >
          <i class="i-lucide-refresh-cw size-4" aria-hidden="true" />
        </button>
      </template>
    </RaevoPageHeader>

    <div v-if="isLoading" class="grid gap-4 xl:grid-cols-2" aria-busy="true">
      <div
        v-for="item in 2"
        :key="item"
        class="h-72 animate-pulse rounded-xl bg-n-slate-3"
      />
    </div>

    <section
      v-else-if="hasError"
      class="rounded-xl border border-n-weak bg-n-solid-1 p-6 text-center"
    >
      <p class="text-sm text-n-slate-11">{{ t('HOME.LOAD_ERROR') }}</p>
      <button
        type="button"
        class="mt-3 rounded-lg bg-n-brand px-3 py-2 text-sm font-medium text-n-solid-1 focus:outline-none focus:ring-2 focus:ring-n-brand/40"
        @click="loadHome"
      >
        {{ t('HOME.TRY_AGAIN') }}
      </button>
    </section>

    <div v-else class="grid gap-4 xl:grid-cols-2">
      <section
        class="overflow-hidden rounded-xl border border-n-weak bg-n-solid-1"
      >
        <div
          class="flex items-center justify-between border-b border-n-weak px-4 py-3"
        >
          <div class="flex min-w-0 items-center gap-2">
            <i
              class="i-lucide-message-circle size-4 text-n-brand"
              aria-hidden="true"
            />
            <h2 class="text-sm font-semibold text-n-slate-12">
              {{ t('HOME.OPEN_CONVERSATIONS') }}
            </h2>
          </div>
          <RaevoStamp
            :label="String(data.open_conversations_count || 0)"
            size="sm"
          />
        </div>
        <div v-if="openConversations.length" class="divide-y divide-n-weak">
          <button
            v-for="conversation in openConversations"
            :key="conversation.id"
            type="button"
            class="flex w-full items-center gap-3 px-4 py-3 text-left hover:bg-n-alpha-2 focus:outline-none focus:ring-2 focus:ring-inset focus:ring-n-brand/40"
            @click="openConversation(conversation)"
          >
            <span
              class="grid size-8 shrink-0 place-items-center rounded-full bg-n-blue-3 text-n-blue-11"
            >
              <i class="i-lucide-message-circle size-4" aria-hidden="true" />
            </span>
            <span class="min-w-0 flex-1">
              <span
                class="block break-words text-sm font-medium text-n-slate-12"
              >
                {{ conversation.contact_name || t('HOME.UNKNOWN_CONTACT') }}
              </span>
              <span class="mt-0.5 block break-words text-xs text-n-slate-10">{{
                conversation.inbox_name || t('HOME.NO_INBOX')
              }}</span>
            </span>
            <span class="shrink-0 text-xs text-n-slate-10">{{
              formatDateTime(conversation.last_activity_at)
            }}</span>
          </button>
        </div>
        <p v-else class="px-4 py-10 text-center text-sm text-n-slate-10">
          {{ t('HOME.EMPTY_CONVERSATIONS') }}
        </p>
      </section>

      <section
        class="overflow-hidden rounded-xl border border-n-weak bg-n-solid-1"
      >
        <div
          class="flex items-center justify-between border-b border-n-weak px-4 py-3"
        >
          <div class="flex min-w-0 items-center gap-2">
            <i
              class="i-lucide-clock-alert size-4 text-n-ruby-11"
              aria-hidden="true"
            />
            <h2 class="text-sm font-semibold text-n-slate-12">
              {{ t('HOME.OVERDUE_ACTIONS') }}
            </h2>
          </div>
          <RaevoStamp
            variant="danger"
            :label="String(overdueActions.length)"
            size="sm"
          />
        </div>
        <div v-if="overdueActions.length" class="divide-y divide-n-weak">
          <button
            v-for="action in overdueActions"
            :key="action.kanban_card_id"
            type="button"
            class="flex w-full items-center gap-3 px-4 py-3 text-left hover:bg-n-alpha-2 focus:outline-none focus:ring-2 focus:ring-inset focus:ring-n-brand/40"
            @click="openOpportunity(action)"
          >
            <span
              class="grid size-8 shrink-0 place-items-center rounded-full bg-n-ruby-3 text-n-ruby-11"
            >
              <i class="i-lucide-clock-alert size-4" aria-hidden="true" />
            </span>
            <span class="min-w-0 flex-1">
              <span
                class="block break-words text-sm font-medium text-n-slate-12"
              >
                {{ action.subject }}
              </span>
              <span class="mt-0.5 block break-words text-xs text-n-slate-10">
                {{
                  t('HOME.PIPELINE_STAGE', {
                    pipeline: action.kanban_board_name,
                    stage: action.kanban_stage_name,
                  })
                }}
              </span>
            </span>
            <span class="shrink-0 text-xs font-medium text-n-ruby-11">{{
              formatDateTime(action.next_action_at)
            }}</span>
          </button>
        </div>
        <p v-else class="px-4 py-10 text-center text-sm text-n-slate-10">
          {{ t('HOME.EMPTY_ACTIONS') }}
        </p>
      </section>
    </div>
  </main>
</template>
