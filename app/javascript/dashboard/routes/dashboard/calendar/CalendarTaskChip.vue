<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { iconForActionType } from 'dashboard/helper/kanbanActionIcon';

// RAEVO (09/10, 123jpnbcb5m) — uma tarefa de lead na grelha da Agenda. Contorno
// tracejado e ícone, sem o fundo de cor das marcações: uma tarefa não ocupa a
// agenda de ninguém, é um lembrete com hora. Abre a oportunidade.
const props = defineProps({
  task: { type: Object, required: true },
  accountId: { type: [Number, String], required: true },
  time: { type: String, default: '' },
});

const { t } = useI18n();

// «Gina T.»: o nome inteiro não cabe numa coluna de um dia da semana.
const shortName = computed(() => {
  const [first, ...rest] = String(props.task.contact_name || '')
    .trim()
    .split(/\s+/);
  const last = rest.at(-1);
  return last ? `${first} ${last[0]}.` : first || '';
});

const label = computed(() =>
  [props.task.next_action_type, shortName.value].filter(Boolean).join(' · ')
);
</script>

<template>
  <RouterLink
    data-testid="calendar-task"
    :to="{
      name: 'kanban_board_show',
      params: { accountId, boardId: task.kanban_board_id },
      query: { cardId: task.kanban_card_id },
    }"
    :title="task.next_action_note || task.subject"
    :aria-label="
      t('CALENDAR.TASKS.OPEN', {
        type: task.next_action_type || t('CALENDAR.TASKS.UNTYPED'),
        contact: task.contact_name,
        time,
        where: `${task.kanban_board_name} › ${task.kanban_stage_name}`,
      })
    "
    class="flex min-w-0 items-center gap-1 rounded-md border border-dashed border-n-slate-9 bg-n-solid-1 px-1.5 py-0.5 text-xs text-n-slate-12 no-underline outline-none hover:bg-n-slate-2 focus-visible:ring-2 focus-visible:ring-n-brand"
  >
    <i
      aria-hidden="true"
      class="size-3 shrink-0 text-n-slate-11"
      :class="iconForActionType(task.next_action_type)"
    />
    <span class="min-w-0 break-words leading-4">{{ label }}</span>
  </RouterLink>
</template>
