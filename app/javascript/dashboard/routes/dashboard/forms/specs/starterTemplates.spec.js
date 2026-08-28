import { FORM_STARTERS, getFormStarterSchema } from '../starterTemplates';

const t = key => key;

describe('form starter templates', () => {
  it('offers the supported commercial and clinical starting points', () => {
    expect(FORM_STARTERS).toEqual([
      'blank',
      'lead_capture',
      'pre_consultation',
      'clinical_intake',
    ]);
  });

  it('keeps the blank starter empty', () => {
    expect(getFormStarterSchema('blank', t)).toBeNull();
  });

  it('builds a lead capture schema with explicit contact mapping', () => {
    expect(getFormStarterSchema('lead_capture', t)).toEqual(
      expect.objectContaining({
        crm_mapping: {
          contact: {
            name: 'nome',
            phone_number: 'telefone',
            email: 'email',
          },
        },
        sections: [
          expect.objectContaining({
            fields: expect.arrayContaining([
              expect.objectContaining({ key: 'nome', required: true }),
              expect.objectContaining({
                key: 'aceite_contato',
                type: 'consent',
                required: true,
              }),
            ]),
          }),
        ],
      })
    );
  });

  it('builds a pre-consultation schema with valid selectable periods', () => {
    const schema = getFormStarterSchema('pre_consultation', t);
    const period = schema.sections[1].fields.find(
      field => field.key === 'melhor_periodo'
    );

    expect(period).toEqual(
      expect.objectContaining({
        type: 'select',
        options: expect.arrayContaining([
          'FORMS.STARTERS.PRE_CONSULTATION.MORNING',
          'FORMS.STARTERS.PRE_CONSULTATION.AFTERNOON',
          'FORMS.STARTERS.PRE_CONSULTATION.EVENING',
        ]),
      })
    );
  });

  it('builds an anamnese schema with mandatory clinical consent and no CRM mapping', () => {
    const schema = getFormStarterSchema('clinical_intake', t);
    const fields = schema.sections.flatMap(section => section.fields);

    expect(schema).not.toHaveProperty('crm_mapping');
    expect(fields).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ key: 'alergias', type: 'textarea' }),
        expect.objectContaining({
          key: 'consentimento_clinico',
          type: 'consent',
          required: true,
        }),
      ])
    );
  });
});
