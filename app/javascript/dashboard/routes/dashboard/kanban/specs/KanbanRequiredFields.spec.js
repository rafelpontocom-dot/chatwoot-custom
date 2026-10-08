import { mount } from '@vue/test-utils';
import KanbanRequiredFields from '../KanbanRequiredFields.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

const montar = (definitions, modelValue = {}) =>
  mount(KanbanRequiredFields, {
    props: { definitions, modelValue, testidPrefix: 'campo-' },
  });

describe('KanbanRequiredFields', () => {
  // Desenhado como texto livre, o multiselect gravava «Implante, Faceta» — que
  // não é nenhuma das opções, e o servidor recusava.
  it('offers a required multiselect as a list of its options and answers with a list', async () => {
    const wrapper = montar(
      [
        {
          key: 'tratamentos',
          label: 'Tratamentos',
          fieldType: 'multiselect',
          options: ['Implante', 'Faceta', 'Limpeza'],
        },
      ],
      { tratamentos: [] }
    );
    const campo = wrapper.find('[data-testid="campo-tratamentos"]');

    expect(campo.element.tagName).toBe('SELECT');
    expect(campo.attributes('multiple')).toBeDefined();
    const opcoes = campo.findAll('option');
    opcoes[0].element.selected = true;
    opcoes[1].element.selected = true;
    await campo.trigger('change');

    expect(wrapper.emitted('update:modelValue').at(-1)).toEqual([
      { tratamentos: ['Implante', 'Faceta'] },
    ]);
  });

  it('answers a boolean with true or false, not with text', async () => {
    const wrapper = montar(
      [{ key: 'consentimento', label: 'Consentimento', field_type: 'boolean' }],
      { consentimento: '' }
    );

    await wrapper.find('[data-testid="campo-consentimento"]').setValue('false');

    expect(wrapper.emitted('update:modelValue').at(-1)).toEqual([
      { consentimento: false },
    ]);
  });
});
