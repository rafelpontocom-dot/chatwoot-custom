import { mount } from '@vue/test-utils';
import FormsCanvasEditor from '../FormsCanvasEditor.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, params = {}) => {
      if (key === 'FORMS.CANVAS.QUESTION_OF')
        return `Pergunta ${params.current} de ${params.total}`;
      return key;
    },
  }),
}));

const fieldTypes = [
  { value: 'text', label: 'Texto curto' },
  { value: 'select', label: 'Seleção' },
  { value: 'textarea', label: 'Texto longo' },
  { value: 'email', label: 'E-mail' },
];

const buildEditor = () => ({
  name: 'Anamnese',
  schema: {
    sections: [
      {
        key: 'etapa_1',
        title: 'Dados',
        fields: [
          {
            key: 'campo_1',
            label: 'Nome completo',
            helpText: '',
            type: 'text',
          },
          { key: 'campo_2', label: 'Convénio', helpText: '', type: 'select' },
        ],
      },
    ],
  },
});

const mountCanvas = (editor = buildEditor(), selectedFieldKey = 'campo_1') =>
  mount(FormsCanvasEditor, {
    props: { editor, activeSectionIndex: 0, selectedFieldKey, fieldTypes },
  });

describe('FormsCanvasEditor', () => {
  it('edits the question in place, in the size the patient reads it', async () => {
    const editor = buildEditor();
    const wrapper = mountCanvas(editor);

    const question = wrapper.find('[data-test="forms-canvas-question"]');
    expect(question.element.value).toBe('Nome completo');

    await question.setValue('Qual é o seu nome completo?');
    expect(editor.schema.sections[0].fields[0].label).toBe(
      'Qual é o seu nome completo?'
    );
    // A pergunta não pode ser escrita em corpo de texto: é o título da tela.
    expect(question.classes()).toEqual(
      expect.arrayContaining(['text-2xl', 'font-semibold'])
    );
  });

  it('escapes the global field-base styling that would repaint the canvas', () => {
    const wrapper = mountCanvas();

    ['forms-canvas-question', 'forms-canvas-help'].forEach(id => {
      expect(wrapper.find(`[data-test="${id}"]`).classes()).toContain(
        'reset-base'
      );
    });
  });

  it('applies the answer type to the focused question without a dialog', async () => {
    const editor = buildEditor();
    const wrapper = mountCanvas(editor);

    await wrapper
      .find('[data-test="forms-canvas-type-textarea"]')
      .trigger('click');

    expect(editor.schema.sections[0].fields[0].type).toBe('textarea');
  });

  it('marks the current type as pressed so the state is not colour-only', () => {
    const wrapper = mountCanvas();

    expect(
      wrapper
        .find('[data-test="forms-canvas-type-text"]')
        .attributes('aria-pressed')
    ).toBe('true');
    expect(
      wrapper
        .find('[data-test="forms-canvas-type-select"]')
        .attributes('aria-pressed')
    ).toBe('false');
  });

  it('walks the questions from the rail instead of a structure tree', async () => {
    const wrapper = mountCanvas();

    await wrapper.find('[data-test="forms-canvas-rail-1"]').trigger('click');

    expect(wrapper.emitted('selectField')).toBeTruthy();
    expect(wrapper.emitted('selectField')[0]).toEqual(['campo_2']);
  });

  it('shows the real answer shape for the type, not a grey rectangle', async () => {
    const wrapper = mountCanvas(buildEditor(), 'campo_2');
    const answer = () => wrapper.find('[data-test="forms-canvas-answer"]');

    // select → opções com tecla-letra
    expect(answer().text()).toContain('A');

    // trocar o tipo troca a prévia na hora, sem passar por diálogo
    await wrapper
      .find('[data-test="forms-canvas-type-email"]')
      .trigger('click');
    expect(answer().text()).toContain('nome@exemplo.com');

    await wrapper
      .find('[data-test="forms-canvas-type-textarea"]')
      .trigger('click');
    expect(answer().text()).toContain('FORMS.CANVAS.ANSWER_HINT');
  });

  it('adds a question on Enter at the last one instead of trapping the writer', async () => {
    const wrapper = mountCanvas(buildEditor(), 'campo_2');

    await wrapper
      .find('[data-test="forms-canvas-question"]')
      .trigger('keydown', { key: 'Enter' });

    expect(wrapper.emitted('addField')).toBeTruthy();
  });

  it('moves to the next question on Enter when there is one', async () => {
    const wrapper = mountCanvas(buildEditor(), 'campo_1');

    await wrapper
      .find('[data-test="forms-canvas-question"]')
      .trigger('keydown', { key: 'Enter' });

    expect(wrapper.emitted('selectField')[0]).toEqual(['campo_2']);
    expect(wrapper.emitted('addField')).toBeFalsy();
  });

  it('keeps advanced settings one click away without a permanent column', async () => {
    const wrapper = mountCanvas();

    await wrapper
      .find('[data-test="forms-canvas-open-settings"]')
      .trigger('click');

    expect(wrapper.emitted('openSettings')).toBeTruthy();
  });

  it('explains itself when there is no section yet', () => {
    const wrapper = mountCanvas({ schema: { sections: [] } });

    expect(wrapper.text()).toContain('FORMS.CANVAS.EMPTY');
    expect(wrapper.find('[data-test="forms-canvas-question"]').exists()).toBe(
      false
    );
  });
  it('keeps step navigation reachable when the library is collapsed', async () => {
    const editor = buildEditor();
    editor.schema.sections.push({
      key: 'etapa_2',
      title: 'Saúde',
      fields: [
        { key: 'campo_3', label: 'Alergias', helpText: '', type: 'text' },
      ],
    });
    const wrapper = mountCanvas(editor);

    expect(
      wrapper
        .find('[data-test="forms-canvas-prev-section"]')
        .attributes('disabled')
    ).toBeDefined();

    await wrapper
      .find('[data-test="forms-canvas-next-section"]')
      .trigger('click');
    expect(wrapper.emitted('selectSection')[0]).toEqual([1]);

    await wrapper
      .find('[data-test="forms-canvas-add-section"]')
      .trigger('click');
    expect(wrapper.emitted('addSection')).toBeTruthy();
  });

  it('toggles required without opening the settings dialog', async () => {
    const editor = buildEditor();
    const wrapper = mountCanvas(editor);

    await wrapper.find('[data-test="forms-canvas-required"]').setValue(true);

    expect(editor.schema.sections[0].fields[0].required).toBe(true);
    expect(wrapper.emitted('openSettings')).toBeFalsy();
  });

  it('offers removal only while more than one question remains', async () => {
    const wrapper = mountCanvas();
    await wrapper
      .find('[data-test="forms-canvas-remove-question"]')
      .trigger('click');
    expect(wrapper.emitted('removeField')[0]).toEqual(['campo_1']);

    const single = mountCanvas({
      schema: {
        sections: [
          {
            key: 'etapa_1',
            title: '',
            fields: [{ key: 'campo_1', label: '', helpText: '', type: 'text' }],
          },
        ],
      },
    });
    expect(
      single.find('[data-test="forms-canvas-remove-question"]').exists()
    ).toBe(false);
  });
  it('edits select options in the canvas without opening the dialog', async () => {
    const editor = buildEditor();
    editor.schema.sections[0].fields[1].options = ['Particular', 'Convénio'];
    const wrapper = mountCanvas(editor, 'campo_2');

    await wrapper
      .find('[data-test="forms-canvas-option-1"]')
      .setValue('Seguradora');

    expect(editor.schema.sections[0].fields[1].options).toEqual([
      'Particular',
      'Seguradora',
    ]);
    expect(wrapper.emitted('openSettings')).toBeFalsy();
  });

  it('keeps the stored value when the option is an object, changing only the label', async () => {
    const editor = buildEditor();
    editor.schema.sections[0].fields[1].options = [
      { value: 'particular', label: 'Particular' },
    ];
    const wrapper = mountCanvas(editor, 'campo_2');

    await wrapper
      .find('[data-test="forms-canvas-option-0"]')
      .setValue('Pagamento particular');

    // Trocar o `value` quebraria as respostas já enviadas.
    expect(editor.schema.sections[0].fields[1].options[0]).toEqual({
      value: 'particular',
      label: 'Pagamento particular',
    });
  });

  it('seeds options when switching to a choice type so the schema stays valid', async () => {
    const editor = buildEditor();
    const wrapper = mountCanvas(editor);

    await wrapper
      .find('[data-test="forms-canvas-type-select"]')
      .trigger('click');

    // Forms::SchemaValidator: "selection fields must include options"
    expect(editor.schema.sections[0].fields[0].options.length).toBe(2);
  });

  it('adds and removes options, never leaving fewer than one', async () => {
    const editor = buildEditor();
    editor.schema.sections[0].fields[1].options = ['A'];
    const wrapper = mountCanvas(editor, 'campo_2');

    expect(
      wrapper.find('[data-test="forms-canvas-remove-option-0"]').exists()
    ).toBe(false);

    await wrapper
      .find('[data-test="forms-canvas-add-option"]')
      .trigger('click');
    expect(editor.schema.sections[0].fields[1].options.length).toBe(2);

    await wrapper
      .find('[data-test="forms-canvas-remove-option-1"]')
      .trigger('click');
    expect(editor.schema.sections[0].fields[1].options.length).toBe(1);
  });

  it('duplicates and reorders questions from the rail', async () => {
    const wrapper = mountCanvas(buildEditor(), 'campo_2');

    await wrapper
      .find('[data-test="forms-canvas-duplicate-question"]')
      .trigger('click');
    expect(wrapper.emitted('duplicateField')[0]).toEqual(['campo_2']);

    await wrapper.find('[data-test="forms-canvas-move-up"]').trigger('click');
    expect(wrapper.emitted('moveField')[0]).toEqual([{ from: 1, to: 0 }]);
  });

  it('does not offer a move past the ends of the list', () => {
    const first = mountCanvas(buildEditor(), 'campo_1');
    expect(
      first.find('[data-test="forms-canvas-move-up"]').attributes('disabled')
    ).toBeDefined();

    const last = mountCanvas(buildEditor(), 'campo_2');
    expect(
      last.find('[data-test="forms-canvas-move-down"]').attributes('disabled')
    ).toBeDefined();
  });
});
