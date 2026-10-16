/**
 * Atributos de contato que são endereçamento interno do WhatsApp.
 *
 * A integração do WAHA cria-os sozinha: conferido em produção, as contas 1 e 3
 * têm `waha_whatsapp_chat_id`, `waha_whatsapp_jid` e `waha_whatsapp_lid`. São
 * identificadores de protocolo, não dado de quem atende, e enchiam a ficha do
 * contato e a aba Contato da oportunidade empurrando o que interessa para baixo.
 *
 * A regra vive aqui porque três telas a precisam. Quando estava copiada numa
 * delas, a ficha do contato ficou limpa e a aba da oportunidade continuou suja —
 * foi assim que o Pedro voltou a ver o Chat ID depois de o cartão estar fechado.
 *
 * Filtra-se por prefixo e não pelos três nomes: a chave é da integração, não
 * nossa, e a próxima que ela criar já nasce escondida.
 */
export const WHATSAPP_ADDRESSING_PREFIX = 'waha_whatsapp_';

// As definições chegam em `attributeKey` nuns sítios e `attribute_key` noutros,
// conforme passem ou não pela normalização do store.
const chaveDe = attribute =>
  attribute?.attributeKey ?? attribute?.attribute_key ?? '';

export const isWhatsappAddressingAttribute = attribute =>
  String(chaveDe(attribute)).startsWith(WHATSAPP_ADDRESSING_PREFIX);

export const withoutWhatsappAddressing = (attributes = []) =>
  (attributes || []).filter(
    attribute => !isWhatsappAddressingAttribute(attribute)
  );
