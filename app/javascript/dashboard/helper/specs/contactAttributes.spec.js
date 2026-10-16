import {
  isWhatsappAddressingAttribute,
  withoutWhatsappAddressing,
} from '../contactAttributes';

describe('contactAttributes', () => {
  // As três chaves foram lidas da produção, contas 1 e 3, não inventadas.
  it.each(['waha_whatsapp_chat_id', 'waha_whatsapp_jid', 'waha_whatsapp_lid'])(
    'treats %s as WhatsApp addressing',
    key => {
      expect(isWhatsappAddressingAttribute({ attributeKey: key })).toBe(true);
    }
  );

  // Um sítio entrega camelCase, outro snake_case, conforme passe ou não pela
  // normalização do store. A regra tem de valer nos dois.
  it('reads the key in either shape', () => {
    expect(
      isWhatsappAddressingAttribute({ attribute_key: 'waha_whatsapp_jid' })
    ).toBe(true);
  });

  it('keeps the attributes the clinic actually fills', () => {
    const restantes = withoutWhatsappAddressing([
      { attributeKey: 'cpf' },
      { attributeKey: 'waha_whatsapp_lid' },
      { attribute_key: 'date_of_birth' },
      { attribute_key: 'waha_whatsapp_chat_id' },
    ]);

    expect(restantes.map(a => a.attributeKey ?? a.attribute_key)).toEqual([
      'cpf',
      'date_of_birth',
    ]);
  });

  it('does not choke on an empty or missing list', () => {
    expect(withoutWhatsappAddressing()).toEqual([]);
    expect(withoutWhatsappAddressing(null)).toEqual([]);
    expect(isWhatsappAddressingAttribute(null)).toBe(false);
  });
});
