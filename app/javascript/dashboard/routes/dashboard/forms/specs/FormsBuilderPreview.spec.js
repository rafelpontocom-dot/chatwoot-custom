import { mount } from '@vue/test-utils';
import FormsBuilderPreview from '../FormsBuilderPreview.vue';

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));

const editor = {
  name: 'Anamnese inicial',
  settings: {
    brand_name: 'Clínica Raevo',
    description: 'Responda com calma antes da consulta.',
  },
  schema: {
    sections: [
      {
        key: 'identificacao',
        title: 'Identificação',
        description: 'Como podemos falar com você?',
        fields: [
          {
            key: 'nome',
            label: 'Nome completo',
            helpText: 'Como está no documento.',
            type: 'text',
            required: true,
            options: [],
          },
          {
            key: 'periodo',
            label: 'Período preferido',
            type: 'select',
            required: false,
            options: ['Manhã', 'Tarde'],
          },
        ],
      },
      { key: 'saude', title: 'Saúde', fields: [] },
    ],
  },
};

describe('FormsBuilderPreview', () => {
  it('renders a safe live preview of the selected section', () => {
    const wrapper = mount(FormsBuilderPreview, {
      props: { editor, activeSectionIndex: 0, selectedFieldKey: 'nome' },
    });

    expect(wrapper.get('[data-test="forms-live-preview"]').text()).toContain(
      'Clínica Raevo'
    );
    expect(wrapper.text()).toContain('Nome completo');
    expect(wrapper.find('#forms-preview-nome').attributes('readonly')).toBe(
      undefined
    );
    expect(
      wrapper.get('[data-test="forms-preview-field-nome"]').element
        .parentElement.className
    ).toContain('border-n-teal-8');
  });

  it('lets the administrator select a question or another section', async () => {
    const wrapper = mount(FormsBuilderPreview, {
      props: { editor, activeSectionIndex: 0, selectedFieldKey: '' },
    });

    await wrapper
      .get('[data-test="forms-preview-field-nome"]')
      .trigger('click');
    await wrapper.get('[data-test="forms-preview-section-1"]').trigger('click');

    expect(wrapper.emitted('selectField')).toEqual([['nome']]);
    expect(wrapper.emitted('selectSection')).toEqual([[1]]);
  });

  it('tests conditional questions with ephemeral preview answers', async () => {
    const conditionalEditor = {
      ...editor,
      schema: {
        sections: [
          {
            ...editor.schema.sections[0],
            fields: [
              ...editor.schema.sections[0].fields,
              {
                key: 'detalhe',
                label: 'Conte mais',
                type: 'textarea',
                visible_when: {
                  field: 'periodo',
                  operator: 'equals',
                  value: 'Manhã',
                },
              },
            ],
          },
        ],
      },
    };
    const wrapper = mount(FormsBuilderPreview, {
      props: {
        editor: conditionalEditor,
        activeSectionIndex: 0,
        selectedFieldKey: '',
      },
    });

    expect(
      wrapper.find('[data-test="forms-preview-field-detalhe"]').exists()
    ).toBe(false);
    await wrapper.get('#forms-preview-periodo').setValue('Manhã');

    expect(
      wrapper.find('[data-test="forms-preview-field-detalhe"]').exists()
    ).toBe(true);
  });

  it('renders a signature field as a visual text acceptance', () => {
    const signatureEditor = {
      ...editor,
      schema: {
        sections: [
          {
            key: 'aceite',
            title: 'Aceite',
            fields: [
              {
                key: 'assinatura',
                label: 'Digite seu nome',
                type: 'signature',
                required: true,
              },
            ],
          },
        ],
      },
    };
    const wrapper = mount(FormsBuilderPreview, {
      props: { editor: signatureEditor, activeSectionIndex: 0 },
    });

    expect(wrapper.get('#forms-preview-assinatura').attributes('type')).toBe(
      'text'
    );
  });

  it('renders structured rich text in the editor preview', async () => {
    const richTextEditor = {
      ...editor,
      schema: {
        sections: [
          {
            ...editor.schema.sections[0],
            content_blocks: [
              {
                id: 'orientacao',
                type: 'rich_text',
                content: {
                  type: 'doc',
                  content: [
                    {
                      type: 'paragraph',
                      content: [{ type: 'text', text: 'Preencha com calma.' }],
                    },
                  ],
                },
              },
            ],
          },
        ],
      },
    };
    const wrapper = mount(FormsBuilderPreview, {
      props: { editor: richTextEditor, activeSectionIndex: 0 },
    });
    await wrapper.vm.$nextTick();
    await wrapper.vm.$nextTick();

    expect(wrapper.text()).toContain('Preencha com calma.');
  });

  it('renders a clinical document question as an upload control in the preview', () => {
    const attachmentEditor = {
      ...editor,
      schema: {
        sections: [
          {
            key: 'documentos',
            title: 'Documentos',
            fields: [
              {
                key: 'exames',
                label: 'Exames recentes',
                type: 'attachment',
                required: true,
              },
            ],
          },
        ],
      },
    };
    const wrapper = mount(FormsBuilderPreview, {
      props: { editor: attachmentEditor, activeSectionIndex: 0 },
    });

    expect(wrapper.get('#forms-preview-exames').attributes('type')).toBe(
      'file'
    );
  });
});
