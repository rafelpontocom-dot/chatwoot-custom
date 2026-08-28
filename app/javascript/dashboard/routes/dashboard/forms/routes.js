import { frontendURL } from '../../../helper/URLHelper';
import FormsView from './FormsView.vue';

export const routes = [
  {
    path: frontendURL('accounts/:accountId/forms'),
    name: 'forms_index',
    component: FormsView,
    meta: { permissions: ['administrator'] },
  },
];
