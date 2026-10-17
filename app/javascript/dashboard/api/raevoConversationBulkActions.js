/* global axios */
import ApiClient from './ApiClient';

// RAEVO (17/10, 123jpnbcxh4): ações em massa nas Conversas, também sobre o filtro inteiro.
class RaevoConversationBulkActionsAPI extends ApiClient {
  constructor() {
    super('raevo_conversation_bulk_actions', { accountScoped: true });
  }

  count(scope) {
    return axios.post(`${this.url}/count`, { scope });
  }

  apply({ scope, operation, value }) {
    return axios.post(this.url, { scope, operation, value });
  }
}

export default new RaevoConversationBulkActionsAPI();
