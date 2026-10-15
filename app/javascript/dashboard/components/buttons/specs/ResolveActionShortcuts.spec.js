import { mount } from '@vue/test-utils';
import { createStore } from 'vuex';
import ResolveAction from '../ResolveAction.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, params) => (params ? `${key} ${JSON.stringify(params)}` : key),
  }),
}));
vi.mock('shared/helpers/platform', () => ({ isApple: () => false }));
vi.mock('dashboard/composables/useConversationRequiredAttributes', () => ({
  useConversationRequiredAttributes: () => ({
    checkMissingAttributes: () => ({}),
  }),
}));

// O botão nativo com as dicas do Raevo: se um upgrade as levar, os atalhos
// voltam a só se saber abrindo a ajuda com ⌘/, e isto falha (123jpnbcxpe).
const store = createStore({
  getters: {
    getSelectedChat: () => ({ id: 7, status: 'open' }),
  },
});

const tooltips = [];
const mountResolve = () =>
  mount(ResolveAction, {
    global: {
      plugins: [store],
      directives: {
        tooltip: { mounted: (_, binding) => tooltips.push(binding.value) },
        onClickaway: {},
      },
      stubs: {
        ConversationResolveAttributesModal: true,
        WootDropdownMenu: true,
        WootDropdownItem: true,
      },
    },
  });

describe('ResolveAction — atalhos à vista', () => {
  beforeEach(() => {
    tooltips.length = 0;
  });

  it('says on the resolve button which keys resolve the conversation', () => {
    const wrapper = mountResolve();

    expect(tooltips).toContain(
      'RAEVO_CONVERSATION.SHORTCUTS.RESOLVE_HINT {"resolve":"Alt+E","resolveNext":"Ctrl+Alt+E","moreActions":"Alt+M"}'
    );
    expect(wrapper.find('[aria-keyshortcuts~="Alt+E"]').exists()).toBe(true);
  });

  it('names the arrow and its shortcut, instead of an icon alone', () => {
    const wrapper = mountResolve();
    const arrow = wrapper.find('[aria-keyshortcuts="Alt+M"]');

    expect(arrow.attributes('aria-label')).toContain(
      'RAEVO_CONVERSATION.SHORTCUTS.MORE_ACTIONS'
    );
  });
});
