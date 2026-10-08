import { requiredFieldOptions } from '../kanbanRequiredFields';

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
