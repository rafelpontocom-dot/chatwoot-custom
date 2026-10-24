import { mount } from '@vue/test-utils';
import CustomRoleModal from '../CustomRoleModal.vue';
import { AVAILABLE_CUSTOM_ROLE_PERMISSIONS } from 'dashboard/constants/permissions.js';
import en from 'dashboard/i18n/locale/en/customRole.json';
import pt from 'dashboard/i18n/locale/pt_BR/customRole.json';

// Contrato de upstream `custom-role-permission-list`: esta tela é nativa do
// Chatwoot e o fork mexeu-lhe em duas coisas que um upgrade pode levar sem
// conflito nenhum — as 18 permissões próprias (kanban/finance/marketing) na
// lista, e o «Selecionar todas» que o Pedro pediu a 24/10, porque são 27
// caixas e o caminho comum é querer quase todas.

const dispatch = vi.fn();

vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({ dispatch }),
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

const montar = (props = {}) =>
  mount(CustomRoleModal, {
    props,
    global: {
      mocks: { $t: key => key },
      stubs: {
        'woot-modal-header': { template: '<header />' },
        Button: { template: '<button />' },
      },
    },
  });

const caixas = wrapper =>
  wrapper
    .findAll('input[type="checkbox"]')
    .filter(input => input.element.checked);

describe('CustomRoleModal', () => {
  it('offers every permission the backend accepts', () => {
    const wrapper = montar();

    expect(wrapper.findAll('input[type="checkbox"]')).toHaveLength(
      AVAILABLE_CUSTOM_ROLE_PERMISSIONS.length
    );
    // As nossas 18 não podem desaparecer num upgrade do Chatwoot.
    expect(AVAILABLE_CUSTOM_ROLE_PERMISSIONS).toEqual(
      expect.arrayContaining([
        'kanban_view',
        'kanban_configure',
        'finance_refund',
        'marketing_configure',
      ])
    );
  });

  // O Pedro abriu a tela e viu quatro linhas com o nome da chave em vez do
  // texto: as quatro permissões de automação nasceram sem tradução, em pt e
  // em en. Uma permissão sem rótulo é uma permissão que ninguém liga.
  it('has a label for every permission, in both languages', () => {
    AVAILABLE_CUSTOM_ROLE_PERMISSIONS.forEach(permission => {
      const chave = permission.toUpperCase();
      expect(en.CUSTOM_ROLE.PERMISSIONS[chave]).toBeTruthy();
      expect(pt.CUSTOM_ROLE.PERMISSIONS[chave]).toBeTruthy();
    });
  });

  it('marks every permission at once, and the label becomes «clear»', async () => {
    const wrapper = montar();
    const botao = wrapper.get('[data-testid="custom-role-toggle-all"]');

    expect(botao.text()).toBe('CUSTOM_ROLE.FORM.PERMISSIONS.SELECT_ALL');

    await botao.trigger('click');

    expect(caixas(wrapper)).toHaveLength(
      AVAILABLE_CUSTOM_ROLE_PERMISSIONS.length
    );
    expect(botao.text()).toBe('CUSTOM_ROLE.FORM.PERMISSIONS.CLEAR_ALL');
  });

  it('clears everything on the second click', async () => {
    const wrapper = montar();
    const botao = wrapper.get('[data-testid="custom-role-toggle-all"]');

    await botao.trigger('click');
    await botao.trigger('click');

    expect(caixas(wrapper)).toHaveLength(0);
    expect(botao.text()).toBe('CUSTOM_ROLE.FORM.PERMISSIONS.SELECT_ALL');
  });

  // O comportamento nativo que não pode partir: marcar «gerir todas as
  // conversas» arrasta as outras duas consigo.
  it('keeps the native coupling of the conversation permissions', async () => {
    const wrapper = montar();
    const gerirTodas = wrapper.get('input[value="conversation_manage"]');

    await gerirTodas.setValue(true);

    const marcadas = caixas(wrapper).map(input => input.element.value);
    expect(marcadas).toEqual(
      expect.arrayContaining([
        'conversation_manage',
        'conversation_unassigned_manage',
        'conversation_participating_manage',
      ])
    );
  });
});
