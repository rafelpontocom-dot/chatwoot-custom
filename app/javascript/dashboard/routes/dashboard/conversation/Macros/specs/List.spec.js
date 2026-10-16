import { shallowMount } from '@vue/test-utils';
import { computed } from 'vue';
import MacrosList from '../List.vue';

const macros = { value: [] };

vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({ dispatch: vi.fn() }),
  useMapGetter: key =>
    key === 'macros/getMacros'
      ? computed(() => macros.value)
      : computed(() => ({ isFetching: false })),
}));
vi.mock('dashboard/composables/useAccount', () => ({
  useAccount: () => ({ accountScopedUrl: url => `/app/accounts/1/${url}` }),
}));
vi.mock('dashboard/composables/useMacroExecution', () => ({
  useMacroExecution: () => ({ executingMacroId: computed(() => null) }),
}));
vi.mock('dashboard/composables/useOrderedMacros', () => ({
  useOrderedMacros: () => ({ orderedMacros: computed(() => macros.value) }),
}));

const montar = () =>
  shallowMount(MacrosList, {
    props: { conversationId: 1 },
    global: {
      mocks: { $t: key => key },
      stubs: {
        RouterLink: { props: ['to'], template: '<a :href="to"><slot /></a>' },
      },
    },
  });

describe('Macros/List — adaptação Raevo', () => {
  // Com macros criadas não havia caminho para criar outra a partir da conversa:
  // o único botão aparecia só com a lista vazia.
  it('offers creating another macro when the list already has some', () => {
    macros.value = [{ id: 1, name: 'Boas-vindas' }];

    const link = montar().find('[data-testid="conversation-macros-add"]');

    expect(link.exists()).toBe(true);
    expect(link.attributes('href')).toBe('/app/accounts/1/settings/macros/new');
  });

  it('keeps the native empty state alone when there are no macros', () => {
    macros.value = [];

    expect(
      montar().find('[data-testid="conversation-macros-add"]').exists()
    ).toBe(false);
  });
});
