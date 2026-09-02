import { flushPromises, shallowMount } from '@vue/test-utils';
import FormsInvitationDialog from '../FormsInvitationDialog.vue';
import FormsAPI from 'dashboard/api/forms';

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/api/forms', () => ({
  default: { getSendableTemplates: vi.fn(), createInvitation: vi.fn() },
}));
vi.mock('shared/helpers/clipboard', () => ({ copyTextToClipboard: vi.fn() }));

const mountDialog = () =>
  shallowMount(FormsInvitationDialog, {
    props: {
      contact: { id: 9, name: 'Pedro Raevo' },
      kanbanCardId: 12,
    },
    global: {
      stubs: {
        Dialog: {
          setup(_, { expose }) {
            expose({ open: vi.fn() });
          },
          template: '<div><slot /></div>',
        },
      },
    },
  });

describe('FormsInvitationDialog', () => {
  beforeEach(() => vi.clearAllMocks());

  it('offers a published anamnese for the already linked contact', async () => {
    // O servidor já devolve só os que se podem enviar, e sem o schema: quem
    // envia pode ser agente, e agente não vê a configuração do formulário.
    FormsAPI.getSendableTemplates.mockResolvedValue({
      data: [
        {
          id: 3,
          name: 'Anamnese inicial',
          category: 'clinical',
          access_classification: 'sensitive_health',
        },
      ],
    });
    const wrapper = mountDialog();

    await wrapper.vm.open();
    await flushPromises();

    expect(wrapper.find('select').text()).toContain('Anamnese inicial');
    expect(
      wrapper.find('input[type="number"]').attributes('disabled')
    ).toBeDefined();
    expect(wrapper.text()).toContain(
      'FORMS.INVITATION.SENSITIVE_HEALTH_NOTICE'
    );
  });
});
