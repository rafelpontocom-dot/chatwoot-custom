import { frontendURL } from '../../../helper/URLHelper';
import CalendarView from './CalendarView.vue';
import CalendarSettingsView from './CalendarSettingsView.vue';

const meta = {
  permissions: ['administrator', 'agent'],
};

export const routes = [
  {
    path: frontendURL('accounts/:accountId/calendar'),
    name: 'calendar_index',
    component: CalendarView,
    meta,
  },
  {
    // Cada secção tem endereço próprio, para poder ser partilhada e para o
    // browser saber voltar — o modal não permitia nem uma coisa nem outra.
    path: frontendURL('accounts/:accountId/calendar/settings/:section?'),
    name: 'calendar_settings',
    component: CalendarSettingsView,
    meta,
  },
];
