import { flushPromises, shallowMount } from '@vue/test-utils';
import FormsSubmissionDetailsDialog from '../FormsSubmissionDetailsDialog.vue';
import FormsAPI from 'dashboard/api/forms';

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/api/forms', () => ({
  default: { getSubmission: vi.fn() },
}));

const mountDialog = () =>
  shallowMount(FormsSubmissionDetailsDialog, {
    global: {
      stubs: {
        Button: { template: '<button><slot /></button>' },
        Dialog: {
          setup(_, { expose }) {
            expose({ open: vi.fn(), close: vi.fn() });
          },
          template: '<div><slot /></div>',
        },
      },
    },
  });

describe('FormsSubmissionDetailsDialog', () => {
  beforeEach(() => vi.clearAllMocks());

  it('loads and groups the selected response for reading inside the opportunity', async () => {
    FormsAPI.getSubmission.mockResolvedValue({
      data: {
        answers: { objetivo: 'Agendar consulta', acompanha: true },
        fields: [
          {
            key: 'objetivo',
            label: 'Objetivo',
            section_title: 'Dados iniciais',
          },
          {
            key: 'acompanha',
            label: 'Já acompanha?',
            section_title: 'Dados iniciais',
          },
        ],
      },
    });
    const wrapper = mountDialog();

    await wrapper.vm.open(24);
    await flushPromises();

    expect(FormsAPI.getSubmission).toHaveBeenCalledWith(24);
    expect(wrapper.text()).toContain('Dados iniciais');
    expect(wrapper.text()).toContain('Agendar consulta');
    expect(wrapper.text()).toContain('FORMS.SUBMISSIONS.YES');
  });
});
