import { frontendURL } from '../../../helper/URLHelper';
import RaevoAiView from './RaevoAiView.vue';
import { FEATURE_FLAGS } from '../../../featureFlags';

export const routes = [
  {
    path: frontendURL('accounts/:accountId/raevo-ai'),
    name: 'raevo_ai',
    component: RaevoAiView,
    meta: {
      featureFlag: FEATURE_FLAGS.RAEVO_AI,
      permissions: ['administrator', 'agent'],
    },
  },
];
