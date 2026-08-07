import { frontendURL } from '../../../helper/URLHelper';
import CalendarView from './CalendarView.vue';

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
];
