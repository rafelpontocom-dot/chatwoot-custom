import { flushPromises, shallowMount } from '@vue/test-utils';
import { computed } from 'vue';
import FormsView from '../FormsView.vue';
import FormsAPI from 'dashboard/api/forms';

const dispatch = vi.fn();
let mockBoards = [];

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/api/forms', () => ({
  default: {
    getTemplates: vi.fn(),
    getSubmissions: vi.fn(),
    createTemplate: vi.fn(),
    updateTemplate: vi.fn(),
    publishTemplate: vi.fn(),
    duplicateTemplate: vi.fn(),
    getSubmission: vi.fn(),
  },
}));
vi.mock('dashboard/composables/store', () => ({
  useMapGetter: key => {
    if (key === 'kanbanBoards/kanbanBoards') {
      return computed(() => mockBoards);
    }
    return computed(() => []);
  },
  useStore: () => ({ dispatch }),
}));
vi.mock('shared/helpers/clipboard', () => ({ copyTextToClipboard: vi.fn() }));

const mountForms = ({ boards = [] } = {}) => {
  mockBoards = boards;
  return shallowMount(FormsView, {
    global: {
      stubs: {
        Button: {
          emits: ['click'],
          props: {
            label: { type: String, default: '' },
            disabled: { type: Boolean, default: false },
          },
          template:
            '<button type="button" :disabled="disabled" @click="$emit(\'click\')">{{ label }}</button>',
        },
        Dialog: {
          emits: ['confirm'],
          setup(_, { expose }) {
            expose({ open: vi.fn(), close: vi.fn() });
          },
          template:
            '<div><slot /><button data-test="dialog-confirm" @click="$emit(\'confirm\')" /></div>',
        },
      },
    },
  });
};

describe('FormsView', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mockBoards = [];
    dispatch.mockResolvedValue();
    FormsAPI.getSubmissions.mockResolvedValue({ data: [] });
  });

  it('loads the template catalogue into the administrator workspace', async () => {
    FormsAPI.getTemplates.mockResolvedValue({
      data: [
        {
          id: 9,
          name: 'Captação de consulta',
          slug: 'captacao',
          category: 'lead_capture',
          public_enabled: false,
          settings: {},
          active_version: null,
        },
      ],
    });

    const wrapper = mountForms();
    await flushPromises();

    expect(FormsAPI.getTemplates).toHaveBeenCalled();
    expect(wrapper.text()).toContain('Captação de consulta');
  });

  it('loads submissions only when the response workspace is selected', async () => {
    FormsAPI.getTemplates.mockResolvedValue({ data: [] });
    const wrapper = mountForms();
    await flushPromises();

    const button = wrapper
      .findAll('button')
      .find(item => item.text().includes('FORMS.TABS.SUBMISSIONS'));
    await button.trigger('click');
    await flushPromises();

    expect(FormsAPI.getSubmissions).toHaveBeenCalled();
  });

  it('opens the authorized submission detail from the response list', async () => {
    FormsAPI.getTemplates.mockResolvedValue({ data: [] });
    FormsAPI.getSubmissions.mockResolvedValue({
      data: [
        {
          id: 11,
          form_name: 'Captação',
          submitted_at: '2026-08-28T12:00:00Z',
          contact: { name: 'Pedro Raevo' },
          opportunity: { subject: 'Consulta' },
        },
      ],
    });
    FormsAPI.getSubmission.mockResolvedValue({
      data: {
        id: 11,
        answers: { nome: 'Pedro Raevo' },
        fields: [{ key: 'nome', label: 'Nome', type: 'text' }],
      },
    });
    const wrapper = mountForms();
    await flushPromises();

    const tab = wrapper
      .findAll('button')
      .find(item => item.text().includes('FORMS.TABS.SUBMISSIONS'));
    await tab.trigger('click');
    await flushPromises();

    const open = wrapper
      .findAll('button')
      .find(item => item.text().includes('FORMS.SUBMISSIONS.OPEN'));
    await open.trigger('click');
    await flushPromises();

    expect(FormsAPI.getSubmission).toHaveBeenCalledWith(11);
  });

  it('preserves a simple visibility condition when publishing a form', async () => {
    const template = {
      id: 9,
      name: 'Captação de consulta',
      slug: 'captacao',
      category: 'lead_capture',
      public_enabled: false,
      settings: {},
      active_version: {
        version_number: 1,
        schema: {
          sections: [
            {
              key: 'consulta',
              title: 'Consulta',
              fields: [
                {
                  key: 'deseja_consulta',
                  label: 'Deseja consultar?',
                  type: 'select',
                  options: ['sim', 'nao'],
                },
                {
                  key: 'melhor_horario',
                  label: 'Melhor horário',
                  type: 'text',
                  visible_when: {
                    field: 'deseja_consulta',
                    operator: 'equals',
                    value: 'sim',
                  },
                },
              ],
            },
          ],
        },
      },
    };
    FormsAPI.getTemplates.mockResolvedValue({ data: [template] });
    FormsAPI.updateTemplate.mockResolvedValue({ data: template });
    FormsAPI.publishTemplate.mockResolvedValue({ data: template });
    const wrapper = mountForms();
    await flushPromises();

    const save = wrapper
      .findAll('button')
      .find(item => item.text().includes('FORMS.ACTIONS.SAVE'));
    await save.trigger('click');
    await flushPromises();

    expect(FormsAPI.publishTemplate).toHaveBeenCalledWith(
      9,
      expect.objectContaining({
        sections: [
          expect.objectContaining({
            fields: expect.arrayContaining([
              expect.objectContaining({
                key: 'melhor_horario',
                visible_when: {
                  field: 'deseja_consulta',
                  operator: 'equals',
                  value: 'sim',
                },
              }),
            ]),
          }),
        ],
      })
    );
  });

  it('publishes checkbox conditions as booleans', async () => {
    const template = {
      id: 10,
      name: 'Consentimento de novidades',
      slug: 'consentimento-novidades',
      category: 'lead_capture',
      public_enabled: false,
      settings: {},
      active_version: {
        version_number: 1,
        schema: {
          sections: [
            {
              key: 'consentimento',
              title: 'Consentimento',
              fields: [
                {
                  key: 'aceite',
                  label: 'Aceito receber novidades',
                  type: 'consent',
                },
                {
                  key: 'canal',
                  label: 'Canal preferido',
                  type: 'select',
                  options: ['WhatsApp'],
                  visible_when: {
                    field: 'aceite',
                    operator: 'equals',
                    value: 'true',
                  },
                },
              ],
            },
          ],
        },
      },
    };
    FormsAPI.getTemplates.mockResolvedValue({ data: [template] });
    FormsAPI.updateTemplate.mockResolvedValue({ data: template });
    FormsAPI.publishTemplate.mockResolvedValue({ data: template });
    const wrapper = mountForms();
    await flushPromises();

    const save = wrapper
      .findAll('button')
      .find(item => item.text().includes('FORMS.ACTIONS.SAVE'));
    await save.trigger('click');
    await flushPromises();

    expect(FormsAPI.publishTemplate).toHaveBeenCalledWith(
      10,
      expect.objectContaining({
        sections: [
          expect.objectContaining({
            fields: expect.arrayContaining([
              expect.objectContaining({
                key: 'canal',
                visible_when: {
                  field: 'aceite',
                  operator: 'equals',
                  value: true,
                },
              }),
            ]),
          }),
        ],
      })
    );
  });

  it('does not publish a selection field without options', async () => {
    const template = {
      id: 12,
      name: 'Origem do lead',
      slug: 'origem-lead',
      category: 'lead_capture',
      public_enabled: false,
      settings: {},
      active_version: {
        version_number: 1,
        schema: {
          sections: [
            {
              key: 'identificacao',
              title: 'Identificação',
              fields: [
                {
                  key: 'origem',
                  label: 'Como conheceu a clínica?',
                  type: 'select',
                  options: [],
                },
              ],
            },
          ],
        },
      },
    };
    FormsAPI.getTemplates.mockResolvedValue({ data: [template] });
    const wrapper = mountForms();
    await flushPromises();

    const save = wrapper
      .findAll('button')
      .find(item => item.text().includes('FORMS.ACTIONS.SAVE'));
    await save.trigger('click');

    expect(FormsAPI.publishTemplate).not.toHaveBeenCalled();
    expect(wrapper.text()).toContain('FORMS.ERROR.INVALID_CONFIGURATION');
  });

  it('adds a reusable contact group with unique field keys', async () => {
    const template = {
      id: 16,
      name: 'Contato complementar',
      slug: 'contato-complementar',
      category: 'lead_capture',
      public_enabled: false,
      settings: {},
      active_version: {
        version_number: 1,
        schema: {
          sections: [
            {
              key: 'inicial',
              title: 'Inicial',
              fields: [
                {
                  key: 'nome',
                  label: 'Nome anterior',
                  type: 'text',
                },
              ],
            },
          ],
        },
      },
    };
    FormsAPI.getTemplates.mockResolvedValue({ data: [template] });
    FormsAPI.updateTemplate.mockResolvedValue({ data: template });
    FormsAPI.publishTemplate.mockResolvedValue({ data: template });
    const wrapper = mountForms();
    await flushPromises();

    await wrapper
      .get('[data-test="forms-field-group-contact"]')
      .trigger('click');
    const save = wrapper
      .findAll('button')
      .find(item => item.text().includes('FORMS.ACTIONS.SAVE'));
    await save.trigger('click');
    await flushPromises();

    expect(FormsAPI.publishTemplate).toHaveBeenCalledWith(
      16,
      expect.objectContaining({
        sections: expect.arrayContaining([
          expect.objectContaining({
            key: 'contato',
            fields: expect.arrayContaining([
              expect.objectContaining({ key: 'nome_2' }),
              expect.objectContaining({ key: 'telefone' }),
            ]),
          }),
        ]),
      })
    );
  });

  it('reorders sections and preserves their respondent-facing description', async () => {
    const template = {
      id: 19,
      name: 'Jornada comercial',
      slug: 'jornada-comercial',
      category: 'lead_capture',
      public_enabled: false,
      settings: {},
      active_version: {
        version_number: 1,
        schema: {
          sections: [
            {
              key: 'identificacao',
              title: 'Identificação',
              fields: [{ key: 'nome', label: 'Nome', type: 'text' }],
            },
            {
              key: 'agenda',
              title: 'Agenda',
              fields: [{ key: 'data', label: 'Data', type: 'date' }],
            },
          ],
        },
      },
    };
    FormsAPI.getTemplates.mockResolvedValue({ data: [template] });
    FormsAPI.updateTemplate.mockResolvedValue({ data: template });
    FormsAPI.publishTemplate.mockResolvedValue({ data: template });
    const wrapper = mountForms();
    await flushPromises();

    await wrapper
      .get('[data-test="forms-section-description-1"]')
      .setValue('Escolha o melhor momento para conversar.');
    await wrapper.get('[data-test="forms-move-section-up-1"]').trigger('click');
    const save = wrapper
      .findAll('button')
      .find(item => item.text().includes('FORMS.ACTIONS.SAVE'));
    await save.trigger('click');
    await flushPromises();

    const [, publishedSchema] = FormsAPI.publishTemplate.mock.calls.at(-1);

    expect(publishedSchema.sections).toMatchObject([
      {
        key: 'agenda',
        description: 'Escolha o melhor momento para conversar.',
      },
      { key: 'identificacao' },
    ]);
  });

  it('maps a compatible answer to a custom opportunity field', async () => {
    const board = {
      id: 27,
      name: 'Raevo',
      stages_summary: [{ id: 4, name: 'Novo' }],
      custom_field_definitions: [
        {
          key: 'origem_lead',
          label: 'Origem do lead',
          field_type: 'select',
          options: ['Formulario'],
        },
      ],
    };
    const template = {
      id: 15,
      name: 'Captação Raevo',
      slug: 'captacao-raevo',
      category: 'lead_capture',
      public_enabled: false,
      settings: {},
      active_version: {
        version_number: 1,
        schema: {
          crm_destination: {
            kanban_board_id: 27,
            kanban_stage_id: 4,
            inbox_id: 9,
            opportunity_policy: 'reuse_open',
          },
          sections: [
            {
              key: 'origem',
              title: 'Origem',
              fields: [
                {
                  key: 'origem_formulario',
                  label: 'Como conheceu a clínica?',
                  type: 'select',
                  options: ['Formulario'],
                },
              ],
            },
          ],
        },
      },
    };
    FormsAPI.getTemplates.mockResolvedValue({ data: [template] });
    FormsAPI.updateTemplate.mockResolvedValue({ data: template });
    FormsAPI.publishTemplate.mockResolvedValue({ data: template });
    const wrapper = mountForms({ boards: [board] });
    await flushPromises();

    await wrapper
      .get('[data-test="forms-opportunity-target-origem_formulario"]')
      .setValue('origem_lead');
    const save = wrapper
      .findAll('button')
      .find(item => item.text().includes('FORMS.ACTIONS.SAVE'));
    await save.trigger('click');
    await flushPromises();

    expect(FormsAPI.publishTemplate).toHaveBeenCalledWith(
      15,
      expect.objectContaining({
        crm_mapping: {
          kanban_card: {
            custom_field_values: {
              origem_lead: 'origem_formulario',
            },
          },
        },
      })
    );
  });

  it('duplicates the selected template as a separate private copy', async () => {
    const template = {
      id: 17,
      name: 'Captação',
      slug: 'captacao',
      category: 'lead_capture',
      public_enabled: true,
      settings: {},
      active_version: {
        version_number: 1,
        schema: {
          sections: [
            {
              key: 'dados',
              title: 'Dados',
              fields: [{ key: 'nome', label: 'Nome', type: 'text' }],
            },
          ],
        },
      },
    };
    const copiedTemplate = {
      ...template,
      id: 18,
      name: 'Cópia de Captação',
      slug: 'captacao-copia',
      public_enabled: false,
    };
    FormsAPI.getTemplates.mockResolvedValue({ data: [template] });
    FormsAPI.duplicateTemplate.mockResolvedValue({ data: copiedTemplate });
    const wrapper = mountForms();
    await flushPromises();

    await wrapper.get('[data-test="forms-duplicate"]').trigger('click');
    await wrapper
      .get('[data-test="forms-duplicate-name"]')
      .setValue('Cópia de Captação');
    await wrapper
      .get('[data-test="forms-duplicate-slug"]')
      .setValue('captacao-copia');
    await wrapper
      .findAll('[data-test="dialog-confirm"]')
      .at(-1)
      .trigger('click');
    await flushPromises();

    expect(FormsAPI.duplicateTemplate).toHaveBeenCalledWith(17, {
      form_template: {
        name: 'Cópia de Captação',
        slug: 'captacao-copia',
      },
    });
    expect(wrapper.text()).toContain('Cópia de Captação');
  });

  it('offers a safe public preview after a public form is published', async () => {
    FormsAPI.getTemplates.mockResolvedValue({
      data: [
        {
          id: 13,
          name: 'Pré-consulta',
          slug: 'pre-consulta',
          category: 'pre_consultation',
          public_enabled: true,
          public_token: 'formulario-publico',
          settings: {},
          active_version: null,
        },
      ],
    });
    const wrapper = mountForms();
    await flushPromises();

    const preview = wrapper.get('[data-test="forms-public-preview"]');

    expect(preview.attributes('href')).toBe(
      `${window.location.origin}/formularios/formulario-publico`
    );
    expect(preview.attributes('rel')).toBe('noopener noreferrer');
  });

  it('publishes the selected lead capture starter when creating a form', async () => {
    const createdTemplate = {
      id: 14,
      name: 'Pedido de contato',
      slug: 'pedido-de-contato',
      category: 'lead_capture',
      public_enabled: false,
      settings: {},
      active_version: null,
    };
    const publishedTemplate = {
      ...createdTemplate,
      active_version: { version_number: 1, schema: { sections: [] } },
    };
    FormsAPI.getTemplates.mockResolvedValue({ data: [] });
    FormsAPI.createTemplate.mockResolvedValue({ data: createdTemplate });
    FormsAPI.publishTemplate.mockResolvedValue({ data: publishedTemplate });
    const wrapper = mountForms();
    await flushPromises();

    const [name, slug] = wrapper.findAll('input');
    await name.setValue('Pedido de contato');
    await slug.setValue('pedido-de-contato');
    await wrapper.findAll('select')[1].setValue('lead_capture');
    await wrapper.find('[data-test="dialog-confirm"]').trigger('click');
    await flushPromises();

    expect(FormsAPI.publishTemplate).toHaveBeenCalledWith(
      14,
      expect.objectContaining({
        crm_mapping: {
          contact: {
            name: 'nome',
            phone_number: 'telefone',
            email: 'email',
          },
        },
      })
    );
    expect(wrapper.text()).toContain('Pedido de contato');
  });

  it('creates an anamnese as a private sensitive-health template', async () => {
    const createdTemplate = {
      id: 20,
      name: 'Anamnese inicial',
      slug: 'anamnese-inicial',
      category: 'clinical',
      access_classification: 'sensitive_health',
      public_enabled: false,
      settings: {},
      active_version: null,
    };
    const publishedTemplate = {
      ...createdTemplate,
      active_version: { version_number: 1, schema: { sections: [] } },
    };
    FormsAPI.getTemplates.mockResolvedValue({ data: [] });
    FormsAPI.createTemplate.mockResolvedValue({ data: createdTemplate });
    FormsAPI.publishTemplate.mockResolvedValue({ data: publishedTemplate });
    const wrapper = mountForms();
    await flushPromises();

    const [name, slug] = wrapper.findAll('input');
    await name.setValue('Anamnese inicial');
    await slug.setValue('anamnese-inicial');
    await wrapper.findAll('select')[1].setValue('clinical_intake');
    await wrapper.find('[data-test="dialog-confirm"]').trigger('click');
    await flushPromises();

    expect(FormsAPI.createTemplate).toHaveBeenCalledWith({
      form_template: expect.objectContaining({
        category: 'clinical',
        access_classification: 'sensitive_health',
      }),
    });
    expect(FormsAPI.publishTemplate).toHaveBeenCalledWith(
      20,
      expect.objectContaining({
        sections: expect.arrayContaining([
          expect.objectContaining({
            fields: expect.arrayContaining([
              expect.objectContaining({ key: 'consentimento_clinico' }),
            ]),
          }),
        ]),
      })
    );
    expect(wrapper.text()).not.toContain('FORMS.EDITOR.DESTINATION');
    expect(wrapper.text()).not.toContain('FORMS.EDITOR.FIELD_MAPPING');
  });
});
