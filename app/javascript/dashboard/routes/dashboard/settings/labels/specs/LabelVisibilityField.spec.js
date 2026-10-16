import { mount } from '@vue/test-utils';
import LabelVisibilityField from '../LabelVisibilityField.vue';

const storeMocks = vi.hoisted(() => ({
  role: 'administrator',
  teams: [
    { id: 7, name: 'Recepção' },
    { id: 8, name: 'Clínico' },
  ],
  dispatch: vi.fn(),
}));

vi.mock('dashboard/composables/store', async () => {
  const { computed } = await vi.importActual('vue');

  return {
    useStore: () => ({ dispatch: storeMocks.dispatch }),
    useStoreGetters: () => ({
      getCurrentRole: computed(() => storeMocks.role),
    }),
    useMapGetter: () => computed(() => storeMocks.teams),
  };
});

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

const montar = (props = {}) =>
  mount(LabelVisibilityField, {
    props: { visibility: 'global', teamId: null, ...props },
  });

describe('LabelVisibilityField', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    storeMocks.role = 'administrator';
  });

  it('offers the three levels to an administrator', () => {
    const wrapper = montar();
    const opcoes = wrapper
      .find('[data-testid="label-visibility"]')
      .findAll('option')
      .map(option => option.attributes('value'));

    expect(opcoes).toEqual(['global', 'team', 'personal']);
  });

  it('asks for a team only when the label belongs to one', async () => {
    const wrapper = montar();

    expect(wrapper.find('[data-testid="label-visibility-team"]').exists()).toBe(
      false
    );

    await wrapper.setProps({ visibility: 'team' });

    const times = wrapper
      .find('[data-testid="label-visibility-team"]')
      .findAll('option')
      .map(option => option.text());
    expect(times).toContain('Recepção');
    expect(times).toContain('Clínico');
  });

  it('clears the team when the label stops belonging to one', async () => {
    const wrapper = montar({ visibility: 'team', teamId: 7 });

    await wrapper.setProps({ visibility: 'global' });

    expect(wrapper.emitted('update:teamId')).toContainEqual([null]);
  });

  // O agente não escolhe. E não se deixa «de todos» selecionado para o servidor
  // o trocar por baixo — diz-se no ecrã o que vai acontecer.
  it('tells an agent the label will be theirs, and sends personal', () => {
    storeMocks.role = 'agent';
    const wrapper = montar();

    expect(wrapper.find('[data-testid="label-visibility"]').exists()).toBe(
      false
    );
    expect(
      wrapper.find('[data-testid="label-visibility-agent-note"]').exists()
    ).toBe(true);
    expect(wrapper.emitted('update:visibility')).toEqual([['personal']]);
    expect(storeMocks.dispatch).not.toHaveBeenCalled();
  });
});
