import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useMapGetter } from 'dashboard/composables/store';
import { frontendURL } from 'dashboard/helper/URLHelper';

/**
 * Raevo — os módulos do produto na paleta de comandos (⌘K).
 *
 * A paleta já existia e não conhecia uma única tela do Raevo: quem procurasse
 * "agenda", "funil" ou "cobrança" não encontrava nada. Cada módulo que o
 * produto vende ficava a três cliques de navegação, enquanto as telas do
 * Chatwoot estavam a duas teclas.
 *
 * Segue o mesmo contrato declarativo de `useGoToCommandHotKeys`: um array de
 * comandos com `id`, `title`, `section`, `icon` e `path`.
 */
const RAEVO_COMMANDS = [
  {
    id: 'raevo_go_to_home',
    title: 'COMMAND_BAR.COMMANDS.RAEVO_HOME',
    section: 'COMMAND_BAR.SECTIONS.RAEVO',
    icon: 'i-lucide-house',
    path: accountId => `accounts/${accountId}/home`,
  },
  {
    id: 'raevo_go_to_pipeline',
    title: 'COMMAND_BAR.COMMANDS.RAEVO_PIPELINE',
    section: 'COMMAND_BAR.SECTIONS.RAEVO',
    icon: 'i-lucide-columns-3',
    path: accountId => `accounts/${accountId}/kanban`,
  },
  {
    id: 'raevo_go_to_calendar',
    title: 'COMMAND_BAR.COMMANDS.RAEVO_CALENDAR',
    section: 'COMMAND_BAR.SECTIONS.RAEVO',
    icon: 'i-lucide-calendar',
    path: accountId => `accounts/${accountId}/calendar`,
  },
  {
    id: 'raevo_go_to_finance',
    title: 'COMMAND_BAR.COMMANDS.RAEVO_FINANCE',
    section: 'COMMAND_BAR.SECTIONS.RAEVO',
    icon: 'i-lucide-receipt',
    path: accountId => `accounts/${accountId}/finance`,
  },
  {
    id: 'raevo_go_to_forms',
    title: 'COMMAND_BAR.COMMANDS.RAEVO_FORMS',
    section: 'COMMAND_BAR.SECTIONS.RAEVO',
    icon: 'i-lucide-clipboard-list',
    path: accountId => `accounts/${accountId}/forms`,
  },
];

export function useRaevoHotKeys() {
  const { t } = useI18n();
  const router = useRouter();
  const currentAccountId = useMapGetter('getCurrentAccountId');
  const boards = useMapGetter('kanbanBoards/kanbanBoards');

  const openRoute = url => router.push(frontendURL(url));

  /**
   * Cada funil vira um comando próprio. Numa clínica com "Vendas — Covilhã" e
   * "Vitalidade 360 — Fundão", saltar entre eles é a navegação mais repetida do
   * dia, e hoje custa dois cliques e um menu suspenso.
   */
  const boardCommands = computed(() =>
    (boards.value || [])
      .filter(board => board?.id && board?.name)
      .map(board => ({
        id: `raevo_go_to_board_${board.id}`,
        section: t('COMMAND_BAR.SECTIONS.RAEVO_BOARDS'),
        title: board.name,
        icon: 'i-lucide-columns-3',
        handler: () =>
          openRoute(`accounts/${currentAccountId.value}/kanban/${board.id}`),
      }))
  );

  const raevoHotKeys = computed(() => [
    ...RAEVO_COMMANDS.map(command => ({
      id: command.id,
      section: t(command.section),
      title: t(command.title),
      icon: command.icon,
      handler: () => openRoute(command.path(currentAccountId.value)),
    })),
    ...boardCommands.value,
  ]);

  return { raevoHotKeys };
}
