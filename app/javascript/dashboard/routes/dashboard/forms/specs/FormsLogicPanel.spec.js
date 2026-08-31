import { mount } from '@vue/test-utils';

import FormsLogicPanel from '../FormsLogicPanel.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

const campos = [
  { key: 'nome', type: 'text', label: 'Nome' },
  {
    key: 'gravida',
    type: 'select',
    label: 'Grávida?',
    options: ['Sim', 'Não'],
  },
  { key: 'idade', type: 'number', label: 'Idade' },
  { key: 'assinatura', type: 'signature', label: 'Assinatura' },
];

const monta = (props = {}) =>
  mount(FormsLogicPanel, {
    props: {
      field: campos[1],
      fields: campos,
      logics: [],
      variables: [],
      endings: [{ key: 'encaminhar', label: 'Vamos falar consigo' }],
      hiddenFields: [{ key: 'token' }],
      ...props,
    },
  });

const ultimoEvento = (wrapper, nome) => {
  const eventos = wrapper.emitted(nome);
  return eventos[eventos.length - 1][0];
};

describe('FormsLogicPanel', () => {
  it('offers only the operators the referenced field type can answer', async () => {
    const wrapper = monta();
    await wrapper.get('[data-test="forms-logic-add-rule"]').trigger('click');
    await wrapper.setProps({ logics: ultimoEvento(wrapper, 'updateLogics') });

    const opcoes = wrapper
      .get('[data-test="forms-logic-operator"]')
      .findAll('option')
      .map(option => option.element.value);

    // `gravida` é seleção única: nada de «contém» nem de «maior que».
    expect(opcoes).toEqual(['is', 'is_not', 'is_empty', 'is_not_empty']);
  });

  it('changes the operator list when the condition points at another question', async () => {
    // A partir da assinatura, `idade` já é uma pergunta anterior — uma condição
    // não pode ler o que ainda não foi respondido.
    const wrapper = monta({ field: campos[3] });
    await wrapper.get('[data-test="forms-logic-add-rule"]').trigger('click');
    await wrapper.setProps({ logics: ultimoEvento(wrapper, 'updateLogics') });

    await wrapper.get('[data-test="forms-logic-ref"]').setValue('idade');
    await wrapper.setProps({ logics: ultimoEvento(wrapper, 'updateLogics') });

    const opcoes = wrapper
      .get('[data-test="forms-logic-operator"]')
      .findAll('option')
      .map(option => option.element.value);

    expect(opcoes).toContain('greater_than');
    expect(opcoes).not.toContain('starts_with');
  });

  it('writes a rule in the shape the server validates', async () => {
    const wrapper = monta();

    await wrapper.get('[data-test="forms-logic-add-rule"]').trigger('click');

    expect(ultimoEvento(wrapper, 'updateLogics')).toEqual([
      {
        field_key: 'gravida',
        payloads: [
          {
            condition: { ref: 'gravida', comparison: 'is', expected: '' },
            action: { kind: 'navigate', field_key: 'idade' },
          },
        ],
      },
    ]);
  });

  it('never offers a jump backwards, and offers the endings', async () => {
    const wrapper = monta();
    await wrapper.get('[data-test="forms-logic-add-rule"]').trigger('click');
    await wrapper.setProps({ logics: ultimoEvento(wrapper, 'updateLogics') });

    const alvos = wrapper
      .get('[data-test="forms-logic-target"]')
      .findAll('option')
      .map(option => option.element.value);

    // Saltar para trás repetiria perguntas já respondidas.
    expect(alvos).toEqual(['idade', 'assinatura', 'encaminhar']);
    expect(alvos).not.toContain('nome');
  });

  it('hides the value box for an operator that takes no value', async () => {
    const logics = [
      {
        field_key: 'gravida',
        payloads: [
          {
            condition: {
              ref: 'gravida',
              comparison: 'is_not_empty',
              expected: '',
            },
            action: { kind: 'navigate', field_key: 'idade' },
          },
        ],
      },
    ];
    const wrapper = monta({ logics });

    expect(wrapper.find('[data-test="forms-logic-expected"]').exists()).toBe(
      false
    );
  });

  it('swaps the action shape when the rule becomes a calculation', async () => {
    const logics = [
      {
        field_key: 'gravida',
        payloads: [
          {
            condition: { ref: 'gravida', comparison: 'is', expected: 'Sim' },
            action: { kind: 'navigate', field_key: 'idade' },
          },
        ],
      },
    ];
    const wrapper = monta({
      logics,
      variables: [{ name: 'risco', kind: 'number', initial: '0' }],
    });

    await wrapper.get('[data-test="forms-logic-action"]').setValue('calculate');

    expect(ultimoEvento(wrapper, 'updateLogics')[0].payloads[0].action).toEqual(
      {
        kind: 'calculate',
        variable: 'risco',
        operator: 'addition',
        value: '',
      }
    );
  });

  it('drops the whole entry when its last rule is removed', async () => {
    const logics = [
      {
        field_key: 'gravida',
        payloads: [
          {
            condition: { ref: 'gravida', comparison: 'is', expected: 'Sim' },
            action: { kind: 'navigate', field_key: 'idade' },
          },
        ],
      },
    ];
    const wrapper = monta({ logics });

    await wrapper.get('[data-test="forms-logic-remove-rule"]').trigger('click');

    // Uma lista vazia só ocuparia espaço na versão publicada.
    expect(ultimoEvento(wrapper, 'updateLogics')).toEqual([]);
  });

  it('keeps the rules of other questions untouched', async () => {
    const outra = {
      field_key: 'idade',
      payloads: [
        {
          condition: {
            ref: 'idade',
            comparison: 'greater_than',
            expected: '60',
          },
          action: { kind: 'navigate', field_key: 'assinatura' },
        },
      ],
    };
    const wrapper = monta({ logics: [outra] });

    await wrapper.get('[data-test="forms-logic-add-rule"]').trigger('click');

    expect(ultimoEvento(wrapper, 'updateLogics')).toContainEqual(outra);
  });

  it('names a new variable without colliding with the ones already there', async () => {
    const wrapper = monta({
      variables: [{ name: 'variavel', kind: 'number', initial: '0' }],
    });

    await wrapper
      .get('[data-test="forms-logic-add-variable"]')
      .trigger('click');

    expect(ultimoEvento(wrapper, 'updateVariables')[1].name).toBe('variavel_2');
  });

  describe('grupos de condições', () => {
    const comUmaRegra = async wrapper => {
      await wrapper.get('[data-test="forms-logic-add-rule"]').trigger('click');
      await wrapper.setProps({ logics: ultimoEvento(wrapper, 'updateLogics') });
      return wrapper;
    };

    it('keeps a single condition in its plain shape', async () => {
      const wrapper = await comUmaRegra(monta());

      // O schema não guarda grupo de um: seria ruído na versão publicada.
      const regra = ultimoEvento(wrapper, 'updateLogics')[0].payloads[0];
      expect(regra.condition.combinator).toBeUndefined();
      expect(regra.condition.ref).toBe('gravida');
    });

    it('turns the rule into a group when a second condition is added', async () => {
      const wrapper = await comUmaRegra(monta());

      await wrapper
        .get('[data-test="forms-logic-add-condition"]')
        .trigger('click');

      const condicao = ultimoEvento(wrapper, 'updateLogics')[0].payloads[0]
        .condition;
      expect(condicao.combinator).toBe('all');
      expect(condicao.conditions).toHaveLength(2);
    });

    it('offers and or or between conditions', async () => {
      const wrapper = await comUmaRegra(monta());
      await wrapper
        .get('[data-test="forms-logic-add-condition"]')
        .trigger('click');
      await wrapper.setProps({ logics: ultimoEvento(wrapper, 'updateLogics') });

      const combinador = wrapper.get('[data-test="forms-logic-combinator"]');
      expect(
        combinador.findAll('option').map(option => option.element.value)
      ).toEqual(['all', 'any']);

      await combinador.setValue('any');

      expect(
        ultimoEvento(wrapper, 'updateLogics')[0].payloads[0].condition
          .combinator
      ).toBe('any');
    });

    it('edits one condition of the group without touching the other', async () => {
      const wrapper = await comUmaRegra(monta());
      await wrapper
        .get('[data-test="forms-logic-add-condition"]')
        .trigger('click');
      await wrapper.setProps({ logics: ultimoEvento(wrapper, 'updateLogics') });

      await wrapper
        .findAll('[data-test="forms-logic-operator"]')[1]
        .setValue('is_not');

      const condicoes = ultimoEvento(wrapper, 'updateLogics')[0].payloads[0]
        .condition.conditions;
      expect(condicoes[0].comparison).toBe('is');
      expect(condicoes[1].comparison).toBe('is_not');
    });

    it('falls back to the plain shape when the group drops to one', async () => {
      const wrapper = await comUmaRegra(monta());
      await wrapper
        .get('[data-test="forms-logic-add-condition"]')
        .trigger('click');
      await wrapper.setProps({ logics: ultimoEvento(wrapper, 'updateLogics') });

      await wrapper
        .findAll('[data-test="forms-logic-remove-condition"]')[1]
        .trigger('click');

      const condicao = ultimoEvento(wrapper, 'updateLogics')[0].payloads[0]
        .condition;
      expect(condicao.combinator).toBeUndefined();
      expect(condicao.ref).toBe('gravida');
    });

    it('does not offer to remove the only condition there is', async () => {
      const wrapper = await comUmaRegra(monta());

      expect(
        wrapper.find('[data-test="forms-logic-remove-condition"]').exists()
      ).toBe(false);
    });
  });

  it('asks for a question to be selected instead of showing an empty rule list', () => {
    const wrapper = monta({ field: null });

    expect(wrapper.find('[data-test="forms-logic-add-rule"]').exists()).toBe(
      false
    );
  });
});
