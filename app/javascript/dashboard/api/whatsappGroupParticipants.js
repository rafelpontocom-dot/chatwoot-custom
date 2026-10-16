/* global axios */
import ApiClient from './ApiClient';

// RAEVO (08/10, 123jpnbcb4w): quem escreveu num grupo de WhatsApp, para o @.
class WhatsappGroupParticipantsAPI extends ApiClient {
  constructor() {
    super('conversations', { accountScoped: true });
  }

  get(conversationId) {
    return axios.get(
      `${this.url}/${conversationId}/whatsapp_group_participants`
    );
  }
}

export default new WhatsappGroupParticipantsAPI();
