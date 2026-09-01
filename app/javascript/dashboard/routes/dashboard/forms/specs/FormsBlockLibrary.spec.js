import { mount } from '@vue/test-utils';
import FormsBlockLibrary from '../FormsBlockLibrary.vue';

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));

const montar = () =>
  mount(FormsBlockLibrary, {
    props: {
      fieldTypes: [
        { value: 'text', label: 'Texto curto' },
        { value: 'date', label: 'Data' },
      ],
      contentBlockTypes: [
        { value: 'heading', label: 'Título', icon: 'i-lucide-heading' },
      ],
      fieldGroupOptions: [{ id: 'contact', title: 'Dados de contacto' }],
      customFieldGroups: [{ id: 7, name: 'Triagem', section: { fields: [] } }],
    },
  });

describe('FormsBlockLibrary', () => {
  it('asks for each kind of block through its own event', async () => {
    const wrapper = montar();

    await wrapper
      .get('[data-test="forms-builder-library-field-date"]')
      .trigger('click');
    await wrapper
      .get('[data-test="forms-builder-library-content-heading"]')
      .trigger('click');
    await wrapper
      .get('[data-test="forms-builder-library-group-contact"]')
      .trigger('click');
    await wrapper
      .get('[data-test="forms-builder-library-saved-7"]')
      .trigger('click');

    expect(wrapper.emitted('addField')[0]).toEqual(['date']);
    expect(wrapper.emitted('addContent')[0]).toEqual(['heading']);
    expect(wrapper.emitted('addGroup')[0]).toEqual(['contact']);
    expect(wrapper.emitted('addSavedGroup')[0][0]).toMatchObject({ id: 7 });
  });

  it('searches across every section at once', async () => {
    // Quem monta o formulário procura pelo nome do que quer, sem saber em que
    // categoria mora.
    const wrapper = montar();

    await wrapper
      .get('[data-test="forms-builder-library-search"]')
      .setValue('tri');

    expect(
      wrapper.find('[data-test="forms-builder-library-saved-7"]').exists()
    ).toBe(true);
    expect(
      wrapper.find('[data-test="forms-builder-library-field-date"]').exists()
    ).toBe(false);
    expect(
      wrapper.find('[data-test="forms-builder-library-group-contact"]').exists()
    ).toBe(false);
  });

  it('opens itself when a section asks for the search box', async () => {
    const wrapper = montar();
    const details = wrapper.get('details');
    details.element.open = false;

    wrapper.vm.focusSearch();

    expect(details.element.open).toBe(true);
  });
});
