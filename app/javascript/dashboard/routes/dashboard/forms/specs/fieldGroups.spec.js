import { getFormFieldGroup } from '../fieldGroups';

const t = key => key;

describe('form field groups', () => {
  it('provides an editable commercial contact group with contact mappings', () => {
    const group = getFormFieldGroup('contact', t);

    expect(group.fields).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ key: 'nome', contactTarget: 'name' }),
        expect.objectContaining({
          key: 'telefone',
          contactTarget: 'phone_number',
        }),
      ])
    );
  });

  it('keeps agenda and commercial blocks free from sensitive health fields', () => {
    const keys = ['appointment', 'commercial'].flatMap(group =>
      getFormFieldGroup(group, t).fields.map(field => field.key)
    );

    expect(keys).toEqual([
      'data_preferida',
      'periodo_preferido',
      'origem',
      'interesse',
    ]);
  });

  it('does not return a group for an unsupported identifier', () => {
    expect(getFormFieldGroup('clinical', t)).toBeNull();
  });
});
