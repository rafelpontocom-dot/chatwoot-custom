import { frontendURL } from '../../../helper/URLHelper';
import RaevoHomeView from './RaevoHomeView.vue';

export const routes = [
  {
    path: frontendURL('accounts/:accountId/home'),
    name: 'raevo_home',
    component: RaevoHomeView,
    meta: { permissions: ['administrator', 'agent'] },
  },
];
