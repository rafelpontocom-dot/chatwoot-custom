import { frontendURL } from '../../../helper/URLHelper';
import MarketingView from './MarketingView.vue';

export const routes = [
  {
    path: frontendURL('accounts/:accountId/marketing'),
    name: 'marketing_index',
    component: MarketingView,
    meta: { permissions: ['administrator', 'agent', 'marketing_view'] },
  },
];
