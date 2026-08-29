import { flushPromises, shallowMount } from '@vue/test-utils';
import { computed } from 'vue';
import FormsView from '../FormsView.vue';
import FormsAPI from 'dashboard/api/forms';

const dispatch = vi.fn();
let mockBoards = [];
let mockAgents = [];
let mockTeams = [];

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/api/forms', () => ({
  default: {
    getTemplates: vi.fn(),
    getSubmissions: vi.fn(),
    createTemplate: vi.fn(),
    updateTemplate: vi.fn(),
    uploadTemplateLogo: vi.fn(),
    removeTemplateLogo: vi.fn(),
    publishTemplate: vi.fn(),
    duplicateTemplate: vi.fn(),
    getSubmission: vi.fn(),
    downloadSubmissionExport: vi.fn(),
    getFieldGroups: vi.fn(),
    createFieldGroup: vi.fn(),
    deleteFieldGroup: vi.fn(),
  },
}));
vi.mock('dashboard/composables/store', () => ({
  useMapGetter: key => {
    if (key === 'kanbanBoards/kanbanBoards') {
      return computed(() => mockBoards);
    }
    if (key === 'agents/getAgents') return computed(() => mockAgents);
    if (key === 'teams/getTeams') return computed(() => mockTeams);
    return computed(() => []);
  },
  useStore: () => ({ dispatch }),
}));
vi.mock('shared/helpers/clipboard', () => ({ copyTextToClipboard: vi.fn() }));

const mountForms = ({ boards = [], agents = [], teams = [] } = {}) => {
  mockBoards = boards;
  mockAgents = agents;
  mockTeams = teams;
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
        Draggable: {
          props: {
            modelValue: { type: Array, default: () => [] },
          },
          template:
            '<ol><slot v-for="(element, index) in modelValue" name="item" :element="element" :index="index" /></ol>',
        },
      },
    },
  });
};

describe('FormsView', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    window.localStorage.clear();
    mockBoards = [];
    mockAgents = [];
    mockTeams = [];
    dispatch.mockResolvedValue();
    FormsAPI.getSubmissions.mockResolvedValue({ data: [] });
    FormsAPI.getFieldGroups.mockResolvedValue({ data: [] });
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

  it('uploads a brand logo from the form settings', async () => {
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
              key: 'principal',
              title: 'Principal',
              fields: [{ key: 'nome', label: 'Nome', type: 'text' }],
            },
          ],
        },
      },
    };
    FormsAPI.getTemplates.mockResolvedValue({ data: [template] });
    FormsAPI.uploadTemplateLogo.mockResolvedValue({
      data: { ...template, brand_logo_url: '/rails/active_storage/blobs/logo' },
    });
    const wrapper = mountForms();
    await flushPromises();

    const file = new File(['logo'], 'logo.png', { type: 'image/png' });
    const input = wrapper.get('input[type="file"]');
    Object.defineProperty(input.element, 'files', { value: [file] });
    await input.trigger('change');
    await flushPromises();

    expect(FormsAPI.uploadTemplateLogo).toHaveBeenCalledWith(9, file);
    expect(
      wrapper.get('img[alt="Captação de consulta"]').attributes('src')
    ).toBe('/rails/active_storage/blobs/logo');
  });

  it('removes the uploaded form logo without changing the editor settings', async () => {
    const template = {
      id: 10,
      name: 'Pré-consulta',
      slug: 'pre-consulta',
      category: 'pre_consultation',
      public_enabled: false,
      brand_logo_url: '/rails/active_storage/blobs/logo',
      settings: { brand_logo_url: 'https://assets.example.test/logo.svg' },
      active_version: {
        version_number: 1,
        schema: {
          sections: [
            {
              key: 'principal',
              title: 'Principal',
              fields: [{ key: 'nome', label: 'Nome', type: 'text' }],
            },
          ],
        },
      },
    };
    FormsAPI.getTemplates.mockResolvedValue({ data: [template] });
    FormsAPI.removeTemplateLogo.mockResolvedValue({
      data: { ...template, brand_logo_url: null },
    });
    const wrapper = mountForms();
    await flushPromises();

    const remove = wrapper
      .findAll('button')
      .find(item =>
        item.text().includes('FORMS.EDITOR.BRAND_LOGO_REMOVE_ACTION')
      );
    await remove.trigger('click');
    await flushPromises();

    expect(FormsAPI.removeTemplateLogo).toHaveBeenCalledWith(10);
    expect(wrapper.find('img[alt="Pré-consulta"]').exists()).toBe(false);
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

  it('shows clinical documents only in the authorized submission detail', async () => {
    FormsAPI.getTemplates.mockResolvedValue({ data: [] });
    FormsAPI.getSubmissions.mockResolvedValue({
      data: [
        { id: 12, form_name: 'Anamnese', submitted_at: '2026-08-28T12:00:00Z' },
      ],
    });
    FormsAPI.getSubmission.mockResolvedValue({
      data: {
        id: 12,
        answers: { alergias: 'Penicilina' },
        fields: [{ key: 'alergias', label: 'Alergias', type: 'textarea' }],
        attachments: [
          {
            id: 33,
            filename: 'exame.pdf',
            content_type: 'application/pdf',
            byte_size: 1024,
          },
        ],
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

    expect(wrapper.text()).toContain('exame.pdf');
    expect(wrapper.text()).toContain('FORMS.SUBMISSIONS.CLINICAL_DOCUMENTS');
  });

  it('shows the immutable clinical consent evidence in the authorized detail', async () => {
    FormsAPI.getTemplates.mockResolvedValue({ data: [] });
    FormsAPI.getSubmissions.mockResolvedValue({
      data: [
        { id: 14, form_name: 'Anamnese', submitted_at: '2026-08-28T12:00:00Z' },
      ],
    });
    FormsAPI.getSubmission.mockResolvedValue({
      data: {
        id: 14,
        answers: { alergias: 'Penicilina', consentimento_clinico: true },
        fields: [{ key: 'alergias', label: 'Alergias', type: 'textarea' }],
        consent_snapshot: [
          {
            key: 'consentimento_clinico',
            label: 'Autorizo o tratamento dos dados de saúde',
            type: 'consent',
            value: true,
            recorded_at: '2026-08-28T12:00:00Z',
          },
        ],
        audit_trail: [
          {
            id: 92,
            action: 'view',
            occurred_at: '2026-08-28T12:03:00Z',
            actor: { id: 2, name: 'Dra. Raevo' },
          },
        ],
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

    expect(wrapper.text()).toContain('FORMS.SUBMISSIONS.CLINICAL_CONSENT');
    expect(wrapper.text()).toContain(
      'Autorizo o tratamento dos dados de saúde'
    );
    expect(wrapper.text()).toContain('FORMS.SUBMISSIONS.ACCESS_HISTORY');
    expect(wrapper.text()).toContain('Dra. Raevo');
  });

  it('exports a response from the detail dialog', async () => {
    FormsAPI.getTemplates.mockResolvedValue({ data: [] });
    FormsAPI.getSubmissions.mockResolvedValue({
      data: [
        { id: 13, form_name: 'Anamnese', submitted_at: '2026-08-28T12:00:00Z' },
      ],
    });
    FormsAPI.getSubmission.mockResolvedValue({
      data: {
        id: 13,
        form_name: 'Anamnese',
        answers: { alergias: 'Penicilina' },
        fields: [{ key: 'alergias', label: 'Alergias', type: 'textarea' }],
      },
    });
    FormsAPI.downloadSubmissionExport.mockResolvedValue({
      data: new Blob(['{}'], { type: 'application/json' }),
    });
    const createObjectUrl = vi.fn(() => 'blob:forms-export');
    const revokeObjectUrl = vi.fn();
    vi.stubGlobal('URL', {
      createObjectURL: createObjectUrl,
      revokeObjectURL: revokeObjectUrl,
    });
    const click = vi
      .spyOn(HTMLAnchorElement.prototype, 'click')
      .mockImplementation(() => {});
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

    await wrapper.get('[data-test="forms-export-submission"]').trigger('click');
    await flushPromises();

    expect(FormsAPI.downloadSubmissionExport).toHaveBeenCalledWith(13);
    click.mockRestore();
    vi.unstubAllGlobals();
  });

  it('lets an administrator choose the professionals and teams that may read an anamnese', async () => {
    const template = {
      id: 21,
      name: 'Anamnese inicial',
      slug: 'anamnese-inicial',
      category: 'clinical',
      access_classification: 'sensitive_health',
      public_enabled: false,
      settings: {
        clinical_access: { user_ids: [4], team_ids: [] },
        clinical_retention_days: 365,
      },
      active_version: {
        version_number: 1,
        schema: {
          sections: [
            {
              key: 'saude',
              title: 'Saúde',
              fields: [
                {
                  key: 'consentimento',
                  label: 'Autorizo',
                  type: 'consent',
                  required: true,
                },
              ],
            },
          ],
        },
      },
    };
    FormsAPI.getTemplates.mockResolvedValue({ data: [template] });

    const wrapper = mountForms({
      agents: [{ id: 4, name: 'Dra. Ana' }],
      teams: [{ id: 8, name: 'Clínica Centro' }],
    });
    await flushPromises();

    expect(wrapper.get('[data-test="forms-clinical-access"]').text()).toContain(
      'Dra. Ana'
    );
    expect(
      wrapper.get('[data-test="forms-clinical-access-user-4"]').element.checked
    ).toBe(true);
    expect(
      wrapper.get('[data-test="forms-clinical-access-team-8"]').exists()
    ).toBe(true);
    expect(
      wrapper.get('[data-test="forms-clinical-retention-days"]').element.value
    ).toBe('365');
  });

  it('filters the clinical access list without changing selected permissions', async () => {
    const template = {
      id: 22,
      name: 'Anamnese de retorno',
      slug: 'anamnese-retorno',
      category: 'clinical',
      access_classification: 'sensitive_health',
      public_enabled: false,
      settings: { clinical_access: { user_ids: [4], team_ids: [] } },
      active_version: {
        version_number: 1,
        schema: {
          sections: [
            {
              key: 'saude',
              title: 'Saúde',
              fields: [
                {
                  key: 'consentimento',
                  label: 'Autorizo',
                  type: 'consent',
                  required: true,
                },
              ],
            },
          ],
        },
      },
    };
    FormsAPI.getTemplates.mockResolvedValue({ data: [template] });

    const wrapper = mountForms({
      agents: [
        { id: 4, name: 'Dra. Ana' },
        { id: 5, name: 'Secretaria Beatriz' },
      ],
      teams: [{ id: 8, name: 'Clínica Centro' }],
    });
    await flushPromises();

    await wrapper
      .get('[data-test="forms-clinical-access-search"]')
      .setValue('Beatriz');

    expect(
      wrapper.find('[data-test="forms-clinical-access-user-4"]').exists()
    ).toBe(false);
    expect(
      wrapper.get('[data-test="forms-clinical-access-user-5"]').exists()
    ).toBe(true);
    expect(
      wrapper.get('[data-test="forms-clinical-access-user-5"]').element.checked
    ).toBe(false);
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

  it('adds a selected question type from the visual builder', async () => {
    const template = {
      id: 12,
      name: 'Pré-consulta',
      slug: 'pre-consulta',
      category: 'pre_consultation',
      public_enabled: false,
      settings: {},
      active_version: {
        version_number: 1,
        schema: {
          sections: [
            {
              key: 'principal',
              title: 'Principal',
              fields: [
                {
                  key: 'campo_1',
                  label: 'Nome',
                  type: 'text',
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

    await wrapper
      .get('[data-test="forms-builder-add-question-0"]')
      .trigger('click');
    await wrapper.get('[data-test="forms-add-field-date"]').trigger('click');
    await flushPromises();

    expect(
      wrapper.find('[data-test="forms-builder-field-campo_2"]').exists()
    ).toBe(true);
  });

  it('keeps an unsaved visual edit in a local draft', async () => {
    const template = {
      id: 13,
      name: 'Cadastro',
      slug: 'cadastro',
      category: 'lead_capture',
      public_enabled: false,
      settings: {},
      active_version: {
        version_number: 1,
        schema: {
          sections: [
            {
              key: 'principal',
              title: 'Principal',
              fields: [
                {
                  key: 'campo_1',
                  label: 'Nome',
                  type: 'text',
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
    await wrapper
      .get('[data-test="forms-builder-question-label"]')
      .setValue('Nome completo');
    await flushPromises();

    expect(
      wrapper.find('[data-test="forms-local-draft-status"]').exists()
    ).toBe(true);
    expect(
      window.localStorage.getItem('raevo-form-builder-draft:13')
    ).toContain('Nome completo');
  });

  it('saves the selected section as an account reusable group', async () => {
    const template = {
      id: 15,
      name: 'Cadastro',
      slug: 'cadastro-3',
      category: 'lead_capture',
      public_enabled: false,
      settings: {},
      active_version: {
        version_number: 1,
        schema: {
          sections: [
            {
              key: 'principal',
              title: 'Dados iniciais',
              fields: [
                {
                  key: 'nome',
                  label: 'Nome completo',
                  type: 'text',
                  options: [],
                },
              ],
            },
          ],
        },
      },
    };
    FormsAPI.getTemplates.mockResolvedValue({ data: [template] });
    FormsAPI.createFieldGroup.mockResolvedValue({
      data: {
        id: 4,
        name: 'Dados iniciais',
        section: template.active_version.schema.sections[0],
      },
    });

    const wrapper = mountForms();
    await flushPromises();

    const saveGroup = wrapper
      .findAll('button')
      .find(item => item.text().includes('FORMS.ACTIONS.SAVE_GROUP'));
    await saveGroup.trigger('click');
    await wrapper
      .get('[data-test="forms-save-field-group-dialog"]')
      .get('[data-test="dialog-confirm"]')
      .trigger('click');
    await flushPromises();

    expect(FormsAPI.createFieldGroup).toHaveBeenCalledWith({
      form_field_group: expect.objectContaining({
        name: 'Dados iniciais',
        section: expect.objectContaining({ key: 'principal' }),
      }),
    });
  });

  it('duplicates a question from its visual settings', async () => {
    const template = {
      id: 14,
      name: 'Cadastro',
      slug: 'cadastro-2',
      category: 'lead_capture',
      public_enabled: false,
      settings: {},
      active_version: {
        version_number: 1,
        schema: {
          sections: [
            {
              key: 'principal',
              title: 'Principal',
              fields: [
                {
                  key: 'campo_1',
                  label: 'Nome',
                  type: 'text',
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
    await wrapper
      .get('[data-test="forms-builder-duplicate-question"]')
      .trigger('click');
    await flushPromises();

    expect(
      wrapper.find('[data-test="forms-builder-field-campo_1_2"]').exists()
    ).toBe(true);
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

  it('does not publish a public form until contact mapping is complete', async () => {
    const template = {
      id: 16,
      name: 'Captação',
      slug: 'captacao-publica',
      category: 'lead_capture',
      public_enabled: true,
      settings: {},
      active_version: {
        version_number: 1,
        schema: {
          sections: [
            {
              key: 'dados',
              fields: [
                { key: 'nome', label: 'Nome', type: 'text' },
                { key: 'telefone', label: 'Telefone', type: 'phone' },
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
    await flushPromises();

    expect(FormsAPI.publishTemplate).not.toHaveBeenCalled();
    expect(wrapper.text()).toContain(
      'FORMS.BUILDER.CHECKLIST.PUBLIC_CONTACT_MAPPING'
    );
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
