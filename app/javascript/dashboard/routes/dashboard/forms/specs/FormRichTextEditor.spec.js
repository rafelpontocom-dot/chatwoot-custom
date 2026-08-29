import { mount } from '@vue/test-utils';
import FormRichTextEditor from '../FormRichTextEditor.vue';

describe('FormRichTextEditor', () => {
  it('emits a structured document when the administrator changes rich text', async () => {
    const wrapper = mount(FormRichTextEditor, {
      props: { modelValue: 'Orientações antes da consulta.' },
    });

    await wrapper.get('[data-test="forms-rich-text-bold"]').trigger('click');
    const content = wrapper.get('.ProseMirror');
    content.element.textContent = 'Orientações atualizadas.';
    await content.trigger('input');

    expect(wrapper.emitted('update:modelValue').at(-1)[0]).toMatchObject({
      type: 'doc',
      content: expect.any(Array),
    });
  });

  it('adds a safe link through the contextual text control', async () => {
    const wrapper = mount(FormRichTextEditor, {
      props: { modelValue: 'Leia nossa política de privacidade.' },
    });

    wrapper.vm.$.setupState.editor.commands.selectAll();
    await wrapper.get('[data-test="forms-rich-text-link"]').trigger('click');
    await wrapper
      .get('[data-test="forms-rich-text-link-url"]')
      .setValue('https://raevo.io/privacidade');
    await wrapper
      .get('[data-test="forms-rich-text-link-apply"]')
      .trigger('click');

    expect(
      JSON.stringify(wrapper.emitted('update:modelValue').at(-1)[0])
    ).toContain('https://raevo.io/privacidade');
  });
});
