import { frontendURL } from '../../../helper/URLHelper';
import KanbanOverview from './KanbanOverview.vue';
import KanbanView from './KanbanView.vue';
import KanbanBoardSettings from './KanbanBoardSettings.vue';
import KanbanAutomations from './KanbanAutomations.vue';

const meta = {
  permissions: ['administrator', 'agent'],
};

export const routes = [
  {
    path: frontendURL('accounts/:accountId/kanban'),
    name: 'kanban_boards',
    component: KanbanOverview,
    meta,
  },
  {
    path: frontendURL('accounts/:accountId/kanban/:boardId'),
    name: 'kanban_board_show',
    component: KanbanView,
    meta,
  },
  {
    path: frontendURL('accounts/:accountId/kanban/:boardId/settings'),
    name: 'kanban_board_settings',
    component: KanbanBoardSettings,
    meta,
  },
  {
    path: frontendURL('accounts/:accountId/kanban/:boardId/settings/fields'),
    name: 'kanban_board_field_settings',
    component: KanbanBoardSettings,
    meta,
  },
  {
    path: frontendURL('accounts/:accountId/kanban/:boardId/automations'),
    name: 'kanban_board_automations',
    component: KanbanAutomations,
    meta,
  },
];
