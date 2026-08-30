import { mount } from '@vue/test-utils';
import FormsBuilderSettingsDialog from '../FormsBuilderSettingsDialog.vue';

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));

const mountDialog = props =>
  mount(FormsBuilderSettingsDialog, {
    props,
    global: {
      stubs: {
        Dialog: {
          template: '<div><slot /></div>',
        },
        FormRichTextEditor: true,
      },
    },
  });

describe('FormsBuilderSettingsDialog', () => {
  it('edits answer options one per line', async () => {
    const field = {
      key: 'periodo',
      label: 'Melhor horário',
      type: 'select',
      options: ['Manhã'],
    };
    const wrapper = mountDialog({ field, section: { fields: [field] } });

    await wrapper
      .get('[data-test="forms-builder-field-options"]')
      .setValue('Manhã\nTarde\nNoite');

    expect(wrapper.emitted('updateField')).toEqual([
      [
        {
          key: 'options',
          value: ['Manhã', 'Tarde', 'Noite'],
        },
      ],
    ]);
  });

  it('keeps destructive removal unavailable for a section with one question', () => {
    const field = { key: 'nome', label: 'Nome', type: 'text', options: [] };
    const wrapper = mountDialog({ field, section: { fields: [field] } });

    expect(
      wrapper
        .get('[data-test="forms-builder-delete-question"]')
        .attributes('disabled')
    ).toBeDefined();
  });

  it('keeps CRM mapping and display condition inside the question settings', () => {
    const sourceField = {
      key: 'periodo',
      label: 'Melhor horário',
      type: 'select',
      options: ['Manhã', 'Tarde'],
    };
    const field = {
      key: 'observacao',
      label: 'Observação',
      type: 'textarea',
      options: [],
      contactTarget: '',
      visibleWhenField: '',
    };
    const wrapper = mountDialog({
      field,
      section: { fields: [sourceField, field] },
      contactMappings: [{ value: '', label: 'Sem destino' }],
      conditionFields: [sourceField],
      opportunityFields: [{ key: 'origem', label: 'Origem' }],
      canMapToCrm: true,
    });

    expect(
      wrapper.get('[data-test="forms-builder-contact-target"]').exists()
    ).toBe(true);
    expect(
      wrapper.get('[data-test="forms-builder-condition-field"]').exists()
    ).toBe(true);
    expect(
      wrapper.get('[data-test="forms-builder-opportunity-target"]').exists()
    ).toBe(true);
  });
});
