<script setup>
import { useI18n } from 'vue-i18n';
import { iconForActionType } from 'dashboard/helper/kanbanActionIcon';

// RAEVO (09/10, 123jpnbcb5m) — a Agenda no telemóvel, como na maquete aprovada:
// o dia numa lista, marcações e tarefas dos leads pela hora. A grelha da
// semana não cabe em 390px — rolava de lado e escondia cinco dias de sete.
// Os itens chegam prontos da CalendarView (os mesmos dados da grelha).
defineProps({
  dayLabel: { type: String, required: true },
  items: { type: Array, required: true },
  accountId: { type: [Number, String], required: true },
  hasError: { type: Boolean, default: false },
});

const emit = defineEmits([
  'previousDay',
  'nextDay',
  'openAppointment',
  'retry',
]);

const { t } = useI18n();
</script>

<template>
  <section
    data-testid="calendar-day-list"
    class="flex min-h-0 flex-1 flex-col overflow-hidden rounded-lg border border-n-weak bg-n-solid-1"
    :aria-label="t('CALENDAR.DAY_LIST.LABEL')"
  >
    <header
      class="flex items-center justify-between gap-2 border-b border-n-weak px-3 py-2"
    >
      <button
        type="button"
        data-testid="calendar-day-previous"
        class="flex size-11 items-center justify-center rounded-lg border border-solid border-n-weak text-n-slate-12 outline-none hover:bg-n-alpha-1 focus-visible:ring-2 focus-visible:ring-n-brand"
        :aria-label="t('CALENDAR.DAY_LIST.PREVIOUS')"
        @click="emit('previousDay')"
      >
        <i class="i-lucide-chevron-left size-4" aria-hidden="true" />
      </button>
      <h2
        data-testid="calendar-day-label"
        class="mb-0 text-base font-semibold text-n-slate-12"
      >
        {{ dayLabel }}
      </h2>
      <button
        type="button"
        data-testid="calendar-day-next"
        class="flex size-11 items-center justify-center rounded-lg border border-solid border-n-weak text-n-slate-12 outline-none hover:bg-n-alpha-1 focus-visible:ring-2 focus-visible:ring-n-brand"
        :aria-label="t('CALENDAR.DAY_LIST.NEXT')"
        @click="emit('nextDay')"
      >
        <i class="i-lucide-chevron-right size-4" aria-hidden="true" />
      </button>
    </header>

    <div
      v-if="hasError"
      role="alert"
      class="flex flex-col items-center gap-2 px-4 py-6 text-center"
    >
      <p class="mb-0 text-sm text-n-slate-12">
        {{ t('CALENDAR.LOAD_ERROR_TITLE') }}
      </p>
      <button
        type="button"
        class="min-h-11 text-sm font-medium text-n-brand outline-none focus-visible:ring-2 focus-visible:ring-n-brand"
        @click="emit('retry')"
      >
        {{ t('CALENDAR.RETRY') }}
      </button>
    </div>
    <p
      v-else-if="!items.length"
      data-testid="calendar-day-empty"
      class="mb-0 px-4 py-6 text-center text-sm text-n-slate-11"
    >
      {{ t('CALENDAR.DAY_LIST.EMPTY') }}
    </p>
    <ol v-else class="m-0 grid list-none gap-2 overflow-y-auto p-3">
      <li
        v-for="item in items"
        :key="item.key"
        data-testid="calendar-day-item"
        :data-kind="item.kind"
        class="grid grid-cols-[3rem_minmax(0,1fr)] items-start gap-2"
      >
        <span class="pt-2.5 text-xs tabular-nums text-n-slate-11">
          {{ item.time }}
        </span>
        <button
          v-if="item.kind === 'appointment'"
          type="button"
          class="raevo-card flex min-h-11 flex-col items-start gap-0.5 rounded-md border-s-[3px] px-2.5 py-2 text-left outline-none focus-visible:ring-2 focus-visible:ring-n-brand"
          :class="item.toneClass"
          :style="item.accent"
          @click="emit('openAppointment', item.appointment, $event)"
        >
          <span class="break-words text-sm font-semibold text-n-slate-12">
            {{ item.appointment.procedure?.name }}
          </span>
          <span class="break-words text-xs text-n-slate-11">
            {{
              item.endsAt
                ? t('CALENDAR.DAY_LIST.CONTACT_UNTIL', {
                    contact: item.appointment.contact?.name,
                    time: item.endsAt,
                  })
                : item.appointment.contact?.name
            }}
          </span>
        </button>
        <RouterLink
          v-else
          :to="{
            name: 'kanban_board_show',
            params: { accountId, boardId: item.task.kanban_board_id },
            query: { cardId: item.task.kanban_card_id },
          }"
          class="flex min-h-11 items-center gap-2 rounded-md border border-dashed border-n-slate-9 px-2.5 py-2 text-n-slate-12 no-underline outline-none hover:bg-n-slate-2 focus-visible:ring-2 focus-visible:ring-n-brand"
        >
          <i
            aria-hidden="true"
            class="size-3.5 shrink-0 text-n-slate-11"
            :class="iconForActionType(item.task.next_action_type)"
          />
          <span class="grid min-w-0 gap-0.5">
            <span class="break-words text-sm font-medium">
              {{
                [item.task.next_action_type, item.task.contact_name]
                  .filter(Boolean)
                  .join(' · ')
              }}
            </span>
            <span class="break-words text-xs text-n-slate-11">
              {{
                t('CALENDAR.DAY_LIST.TASK_WHERE', {
                  board: item.task.kanban_board_name,
                  stage: item.task.kanban_stage_name,
                })
              }}
            </span>
          </span>
        </RouterLink>
      </li>
    </ol>
  </section>
</template>
