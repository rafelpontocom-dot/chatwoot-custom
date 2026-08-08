import { mount } from '@vue/test-utils';
import TagMultiSelectComboBox from '../TagMultiSelectComboBox.vue';

describe('TagMultiSelectComboBox', () => {
  it('emits a new selected-values array when an option is toggled', async () => {
    const wrapper = mount(TagMultiSelectComboBox, {
      props: {
        modelValue: [],
        options: [{ value: 7, label: 'Profissional de validação' }],
      },
      global: {
        stubs: {
          OnClickOutside: { template: '<div><slot /></div>' },
          ComboBoxDropdown: {
            props: ['options'],
            template:
              '<button type="button" @click="$emit(\'select\', options[0])">Selecionar</button>',
          },
        },
      },
    });

    await wrapper.find('button').trigger('click');

    const [selectedValues] = wrapper.emitted('update:modelValue')[0];
    expect(selectedValues).toEqual([7]);
    expect(selectedValues).not.toBe(wrapper.props('modelValue'));
  });
});
