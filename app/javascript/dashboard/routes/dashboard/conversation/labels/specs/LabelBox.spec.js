import { shallowMount } from '@vue/test-utils';
import { computed } from 'vue';
import LabelBox from '../LabelBox.vue';

vi.mock('dashboard/composables/useConversationLabels', () => ({
  useConversationLabels: () => ({
    savedLabels: computed(() => []),
    activeLabels: computed(() => []),
    accountLabels: computed(() => [{ id: 1, title: 'vip' }]),
    addLabelToConversation: vi.fn(),
    removeLabelFromConversation: vi.fn(),
  }),
}));
vi.mock('dashboard/composables/useKeyboardEvents', () => ({
  useKeyboardEvents: vi.fn(),
}));

describe('LabelBox — adaptação Raevo', () => {
  // A 07/10 o servidor passou a deixar o agente criar a etiqueta dele (nasce
  // pessoal), e o atalho da conversa só oferecia criar ao administrador. Sem
  // isto o agente não tinha porta de entrada nenhuma.
  it('offers creating a label to whoever opens the shortcut, not only admins', async () => {
    const wrapper = shallowMount(LabelBox, {
      global: {
        mocks: {
          $t: key => key,
          $store: {
            getters: { 'conversationLabels/getUIFlags': { isFetching: false } },
          },
        },
      },
    });
    wrapper.vm.showSearchDropdownLabel = true;
    await wrapper.vm.$nextTick();

    const dropdown = wrapper.findComponent({ name: 'LabelDropdown' });
    expect(dropdown.exists()).toBe(true);
    expect(dropdown.props('allowCreation')).toBe(true);
  });
});
