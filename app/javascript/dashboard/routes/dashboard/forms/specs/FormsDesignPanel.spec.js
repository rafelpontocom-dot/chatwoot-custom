import { mount } from '@vue/test-utils';

import FormsDesignPanel from '../FormsDesignPanel.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

const monta = (props = {}) =>
  mount(FormsDesignPanel, {
    props: {
      settings: { brand_name: 'Clínica Vitá', theme: 'calm' },
      brandLogoUrl: '',
      ...props,
    },
  });

describe('FormsDesignPanel', () => {
  it('reports a brand change instead of writing on the prop', async () => {
    const wrapper = monta();

    await wrapper
      .get('[data-test="design-brand-name"]')
      .setValue('Clínica Nova');

    // O painel não escreve no objeto do editor: pede a alteração e quem manda
    // no formulário decide. Mutar um prop parece funcionar até deixar de o fazer.
    expect(wrapper.emitted('update').at(-1)).toEqual([
      { brand_name: 'Clínica Nova' },
    ]);
  });

  it('reports a theme change', async () => {
    const wrapper = monta();

    await wrapper.get('[data-test="design-theme"]').setValue('contrast');

    expect(wrapper.emitted('update').at(-1)).toEqual([{ theme: 'contrast' }]);
  });

  it('hands the chosen file over without uploading it itself', async () => {
    const wrapper = monta();

    await wrapper.get('input[type="file"]').trigger('change');

    // Quem fala com a API é o FormsView: o painel só sabe que houve escolha.
    expect(wrapper.emitted('uploadBrandLogo')).toHaveLength(1);
  });

  it('shows the uploaded logo, and offers to remove it', async () => {
    const wrapper = monta({ brandLogoUrl: '/rails/active_storage/blobs/logo' });

    expect(wrapper.get('img').attributes('src')).toBe(
      '/rails/active_storage/blobs/logo'
    );

    const remover = wrapper
      .findAll('button')
      .find(item =>
        item.text().includes('FORMS.EDITOR.BRAND_LOGO_REMOVE_ACTION')
      );
    await remover.trigger('click');

    expect(wrapper.emitted('removeBrandLogo')).toHaveLength(1);
  });

  it('does not offer to remove a logo that is not there', () => {
    const wrapper = monta();

    expect(wrapper.find('img').exists()).toBe(false);
  });

  it('locks the controls while an upload is in flight', () => {
    const wrapper = monta({ isUploadingBrandLogo: true });

    expect(
      wrapper.get('input[type="file"]').attributes('disabled')
    ).toBeDefined();
  });
});
