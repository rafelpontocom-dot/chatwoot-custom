// Contacto que chegou pelo WAHA sem nome fica com o identificador do WhatsApp
// («351967564016@c.us»): uma palavra só, que parte linhas e não diz nada a quem
// liga. O que interessa é o número. Usado na grelha, na faixa das atrasadas e na
// lista do telemóvel, para as três dizerem o mesmo (123jpnbcxp8).
const WHATSAPP_ID = /^(\d{6,})@(c\.us|s\.whatsapp\.net|lid)$/i;

export const taskContactName = name => {
  const trimmed = String(name || '').trim();
  const whatsappNumber = trimmed.match(WHATSAPP_ID)?.[1];
  return whatsappNumber ? `+${whatsappNumber}` : trimmed;
};
