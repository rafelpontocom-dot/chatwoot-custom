/**
 * Raevo — o estado da próxima ação, num sítio só.
 *
 * O mesmo estado aparece no cartão do quadro e na linha da vista de lista. Escrito
 * duas vezes ia divergir: foi assim que o produto acumulou três tratamentos do
 * mesmo campo. Cada estado traz cor, ícone e rótulo — os três sempre, porque a
 * regra 5 do AGENTS.md proíbe comunicar estado só por cor.
 *
 * O `labelKey` fica por traduzir de propósito: quem chama tem o `t()`.
 */
export const KANBAN_NEXT_ACTION_STATES = {
  missing: {
    labelKey: 'KANBAN.CARD.NEXT_ACTION.MISSING',
    icon: 'i-lucide-calendar-x',
    // Neutro de propósito: não ter próxima ação marcada é o estado inicial
    // de toda a oportunidade, não uma falha. Em âmbar, o quadro inteiro
    // acendia e o âmbar deixava de querer dizer nada.
    class: 'bg-n-alpha-2 text-n-slate-11',
  },
  overdue: {
    labelKey: 'KANBAN.CARD.NEXT_ACTION.OVERDUE',
    icon: 'i-lucide-clock-alert',
    class: 'bg-n-ruby-3 text-n-ruby-11',
  },
  due_today: {
    labelKey: 'KANBAN.CARD.NEXT_ACTION.DUE_TODAY',
    icon: 'i-lucide-calendar-clock',
    class: 'bg-n-blue-3 text-n-blue-11',
  },
  future: {
    labelKey: 'KANBAN.CARD.NEXT_ACTION.FUTURE',
    icon: 'i-lucide-calendar',
    class: 'bg-n-teal-3 text-n-teal-11',
  },
  closed: {
    labelKey: 'KANBAN.CARD.NEXT_ACTION.CLOSED',
    icon: 'i-lucide-circle-check',
    class: 'border-n-green-5 bg-n-green-2 text-n-green-11',
  },
};

export const getKanbanNextActionState = status =>
  KANBAN_NEXT_ACTION_STATES[status] || null;
