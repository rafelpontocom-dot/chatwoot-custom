<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import NextButton from 'dashboard/components-next/button/Button.vue';
import RaevoStamp from 'dashboard/components-next/raevo/RaevoStamp.vue';

// RAEVO (09/10, 123jpnbcb5m) — a linha por cima da grelha quando as tarefas
// dos leads estão à vista: as atrasadas primeiro (são as que pedem que alguém
// pegue no telefone), e os estados da maquete — a carregar, erro e vazio. O
// erro é só das tarefas: os agendamentos já estão certos na grelha.
const props = defineProps({
  overdue: { type: Object, required: true },
  hasTasks: { type: Boolean, default: false },
  isLoading: { type: Boolean, default: false },
  hasError: { type: Boolean, default: false },
  accountId: { type: [Number, String], required: true },
});

const emit = defineEmits(['retry']);

const { t } = useI18n();

const VISIBLE_OVERDUE = 2;
const showAll = ref(false);
const shown = computed(() =>
  showAll.value
    ? props.overdue.items
    : props.overdue.items.slice(0, VISIBLE_OVERDUE)
);
const hidden = computed(() => props.overdue.count - shown.value.length);

const day = value =>
  new Intl.DateTimeFormat(undefined, {
    day: '2-digit',
    month: '2-digit',
  }).format(new Date(value));
</script>

<template>
  <section
    data-testid="calendar-tasks-bar"
    class="flex flex-wrap items-center gap-x-3 gap-y-1.5 rounded-lg border border-n-weak bg-n-solid-1 px-3 py-2"
    :aria-label="t('CALENDAR.TASKS.BAR_LABEL')"
    :aria-busy="isLoading"
  >
    <template v-if="hasError">
      <p
        role="alert"
        class="mb-0 flex items-start gap-2 text-xs text-n-ruby-11"
      >
        <i
          aria-hidden="true"
          class="i-lucide-circle-alert mt-px size-3.5 shrink-0"
        />
        {{ t('CALENDAR.TASKS.ERROR') }}
      </p>
      <NextButton
        type="button"
        xs
        outline
        slate
        data-testid="calendar-tasks-retry"
        :label="t('CALENDAR.TASKS.RETRY')"
        @click="emit('retry')"
      />
    </template>
    <p v-else-if="isLoading" class="mb-0 text-xs text-n-slate-11">
      {{ t('CALENDAR.TASKS.LOADING') }}
    </p>
    <template v-else-if="overdue.count">
      <RaevoStamp
        variant="danger"
        icon="i-lucide-clock-alert"
        data-testid="calendar-tasks-overdue"
        :label="
          overdue.count_capped
            ? t('CALENDAR.TASKS.OVERDUE_CAPPED', { count: overdue.count })
            : t('CALENDAR.TASKS.OVERDUE', { count: overdue.count })
        "
      />
      <RouterLink
        v-for="item in shown"
        :key="item.kanban_card_id"
        data-testid="calendar-tasks-overdue-item"
        class="text-xs text-n-slate-12 underline-offset-2 hover:underline focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-brand"
        :to="{
          name: 'kanban_board_show',
          params: { accountId, boardId: item.kanban_board_id },
          query: { cardId: item.kanban_card_id },
        }"
      >
        {{
          [item.next_action_type, item.contact_name].filter(Boolean).join(' · ')
        }}
        <span class="text-n-slate-11">
          {{ t('CALENDAR.TASKS.ON_DATE', { date: day(item.next_action_at) }) }}
        </span>
      </RouterLink>
      <NextButton
        v-if="hidden > 0 && !showAll"
        type="button"
        xs
        link
        slate
        data-testid="calendar-tasks-overdue-more"
        :label="t('CALENDAR.TASKS.MORE', { count: hidden })"
        @click="showAll = true"
      />
    </template>
    <template v-else>
      <RaevoStamp
        variant="success"
        data-testid="calendar-tasks-none-overdue"
        :label="t('CALENDAR.TASKS.NONE_OVERDUE')"
      />
      <p
        v-if="!hasTasks"
        data-testid="calendar-tasks-empty"
        class="mb-0 text-xs text-n-slate-11"
      >
        {{ t('CALENDAR.TASKS.EMPTY') }}
      </p>
    </template>
  </section>
</template>
