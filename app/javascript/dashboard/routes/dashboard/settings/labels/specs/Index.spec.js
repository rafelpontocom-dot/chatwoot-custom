import { mount } from '@vue/test-utils';
import { computed } from 'vue';
import LabelsIndex from '../Index.vue';

const estado = { role: 'agent', userId: 7 };
const dispatch = vi.fn();

const etiquetas = [
  { id: 1, title: 'vip', visibility: 'global', created_by_id: 1 },
  { id: 2, title: 'do-time', visibility: 'team', team_id: 3, created_by_id: 1 },
  { id: 3, title: 'minha', visibility: 'personal', created_by_id: 7 },
];

vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({ dispatch }),
  useStoreGetters: () => ({
    'labels/getLabels': computed(() => etiquetas),
    'labels/getUIFlags': computed(() => ({ isFetching: false })),
    'teams/getTeams': computed(() => [{ id: 3, name: 'Recepção' }]),
    getCurrentRole: computed(() => estado.role),
    getCurrentUserID: computed(() => estado.userId),
  }),
}));
vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, values = {}) =>
      key === 'LABEL_MGMT.LIST.VISIBILITY_TEAM' ? `Time: ${values.team}` : key,
  }),
}));

const montar = () =>
  mount(LabelsIndex, {
    global: {
      mocks: { $t: key => key },
      directives: { tooltip: {} },
      stubs: {
        SettingsLayout: {
          template: '<div><slot name="header" /><slot name="body" /></div>',
        },
        BaseSettingsHeader: {
          template: '<header><slot name="actions" /></header>',
        },
        BaseTable: {
          props: ['items'],
          template: '<table><slot name="row" :items="items" /></table>',
        },
        BaseTableRow: { template: '<tr><slot /></tr>' },
        BaseTableCell: { template: '<td><slot /></td>' },
        AddLabel: true,
        EditLabel: true,
        WootModal: true,
        WootDeleteModal: true,
      },
    },
  });

describe('Definições › Etiquetas — adaptação Raevo', () => {
  // O servidor já deixava o agente renomear e apagar a etiqueta pessoal dele,
  // mas não havia tela: Definições › Etiquetas era só do administrador.
  it('lets an agent edit and delete only their own personal labels', () => {
    estado.role = 'agent';
    const wrapper = montar();

    expect(wrapper.find('[data-testid="label-edit-minha"]').exists()).toBe(
      true
    );
    expect(wrapper.find('[data-testid="label-delete-minha"]').exists()).toBe(
      true
    );
    expect(wrapper.find('[data-testid="label-edit-vip"]').exists()).toBe(false);
    expect(wrapper.find('[data-testid="label-delete-do-time"]').exists()).toBe(
      false
    );
  });

  it('keeps reordering for the administrator only', () => {
    estado.role = 'agent';
    expect(
      montar().findAll('[aria-label="LABEL_MGMT.REORDER.MOVE_UP"]')
    ).toHaveLength(0);

    estado.role = 'administrator';
    expect(
      montar().findAll('[aria-label="LABEL_MGMT.REORDER.MOVE_UP"]')
    ).toHaveLength(3);
  });

  it('says who sees each label, in words', () => {
    estado.role = 'administrator';
    const wrapper = montar();
    const texto = titulo =>
      wrapper.find(`[data-testid="label-visibility-${titulo}"]`).text();

    expect(texto('vip')).toBe('LABEL_MGMT.FORM.VISIBILITY.GLOBAL');
    expect(texto('do-time')).toBe('Time: Recepção');
    expect(texto('minha')).toBe('LABEL_MGMT.FORM.VISIBILITY.PERSONAL');
  });
});
