import {
  isRequiredFieldEmpty,
  mergeRequiredFields,
  requiredFieldOptions,
  requiredFieldsForStage,
} from '../kanbanRequiredFields';

const t = key => key;

describe('requiredFieldOptions', () => {
  it('offers yes and no for a boolean, which the server sends without options', () => {
    expect(
      requiredFieldOptions({ field_type: 'boolean', options: [] }, t)
    ).toEqual([
      { value: true, label: 'KANBAN.OPPORTUNITY_DETAILS.BOOLEAN_YES' },
      { value: false, label: 'KANBAN.OPPORTUNITY_DETAILS.BOOLEAN_NO' },
    ]);
  });

  it('keeps the options of a select, camelized or not', () => {
    expect(
      requiredFieldOptions({ fieldType: 'select', options: ['A', 'B'] }, t)
    ).toEqual([
      { value: 'A', label: 'A' },
      { value: 'B', label: 'B' },
    ]);
  });
});

describe('requiredFieldsForStage', () => {
  const definicoes = [
    { key: 'procedimento', field_type: 'select', required_stage_ids: [100] },
    { key: 'outra_etapa', fieldType: 'text', requiredStageIds: [200] },
    {
      key: 'condicional',
      fieldType: 'text',
      requiredStageIds: [100],
      condition: { fieldKey: 'procedimento', equals: 'Retorno' },
    },
    { key: 'livre', fieldType: 'text' },
  ];

  // Os condicionais dependem de outra resposta: numa criação quase sempre estão
  // escondidos, e é a recusa do servidor que os traz se forem precisos.
  it('knows before the server which fields the stage requires, except conditional ones', () => {
    expect(
      requiredFieldsForStage(definicoes, '100').map(item => item.key)
    ).toEqual(['procedimento']);
  });
});

describe('isRequiredFieldEmpty', () => {
  it('treats an empty list as empty and false as an answer', () => {
    expect(isRequiredFieldEmpty([])).toBe(true);
    expect(isRequiredFieldEmpty('')).toBe(true);
    expect(isRequiredFieldEmpty(false)).toBe(false);
    expect(isRequiredFieldEmpty(['Implante'])).toBe(false);
  });
});

describe('mergeRequiredFields', () => {
  it('adds what the server says is missing without erasing what was typed', () => {
    const juntos = mergeRequiredFields(
      [{ key: 'procedimento', fieldType: 'select' }],
      { procedimento: 'Retorno' },
      [
        { key: 'procedimento', fieldType: 'select' },
        { key: 'tratamentos', fieldType: 'multiselect' },
      ],
      ['tratamentos']
    );

    expect(juntos.definitions.map(item => item.key)).toEqual([
      'procedimento',
      'tratamentos',
    ]);
    expect(juntos.values).toEqual({ procedimento: 'Retorno', tratamentos: [] });
  });
});
