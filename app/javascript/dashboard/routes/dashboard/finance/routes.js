import { frontendURL } from '../../../helper/URLHelper';
import FinanceView from './FinanceView.vue';

export const routes = [
  {
    path: frontendURL('accounts/:accountId/finance'),
    name: 'finance_index',
    component: FinanceView,
    meta: { permissions: ['administrator', 'agent', 'finance_view'] },
  },
];
