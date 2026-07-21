/* global axios */
import ApiClient from './ApiClient';

class KanbanBoardsAPI extends ApiClient {
  constructor() {
    super('kanban_boards', { accountScoped: true });
  }

  createStage(boardId, payload) {
    return axios.post(`${this.url}/${boardId}/stages`, payload);
  }

  updateStage(boardId, stageId, payload) {
    return axios.patch(`${this.url}/${boardId}/stages/${stageId}`, payload);
  }

  reorderStage(boardId, stageId, payloadOrDirection) {
    const payload =
      typeof payloadOrDirection === 'string'
        ? { direction: payloadOrDirection }
        : payloadOrDirection;
    return axios.patch(
      `${this.url}/${boardId}/stages/${stageId}/reorder`,
      payload
    );
  }

  deleteStage(boardId, stageId) {
    return axios.delete(`${this.url}/${boardId}/stages/${stageId}`);
  }

  getBoards(config = {}) {
    return axios.get(this.url, config);
  }

  showBoard(boardId, config = {}) {
    return axios.get(`${this.url}/${boardId}`, config);
  }

  getSalesSummary(boardId, config = {}) {
    return axios.get(`${this.url}/${boardId}/reports/sales_summary`, config);
  }

  getSettings(boardId) {
    return axios.get(`${this.url}/${boardId}/settings`);
  }

  updateSettings(boardId, payload) {
    return axios.patch(`${this.url}/${boardId}/settings`, payload);
  }

  getSavedFilters(boardId) {
    return axios.get(`${this.url}/${boardId}/saved_filters`);
  }

  createSavedFilter(boardId, payload) {
    return axios.post(`${this.url}/${boardId}/saved_filters`, payload);
  }

  importExistingConversations(boardId, payload) {
    return axios.post(
      `${this.url}/${boardId}/settings/import_existing_conversations`,
      payload
    );
  }

  getConversationCards(conversationId, config = {}) {
    return axios.get(
      `${this.baseUrl()}/conversations/${conversationId}/kanban_cards`,
      config
    );
  }

  createConversationCard(conversationId, payload, config = {}) {
    return axios.post(
      `${this.baseUrl()}/conversations/${conversationId}/kanban_cards`,
      payload,
      config
    );
  }

  getContactCards(contactId, config = {}) {
    return axios.get(
      `${this.baseUrl()}/contacts/${contactId}/kanban_cards`,
      config
    );
  }

  getStageCards(boardId, stageId, params = {}) {
    return axios.get(`${this.url}/${boardId}/stages/${stageId}/cards`, {
      params,
    });
  }

  createManualCard(boardId, payload) {
    return axios.post(`${this.url}/${boardId}/cards/manual`, payload);
  }

  getArchivedCards(boardId) {
    return axios.get(`${this.url}/${boardId}/cards/archived`);
  }

  restoreCardById(boardId, cardId) {
    return axios.patch(`${this.url}/${boardId}/cards/by_id/${cardId}/restore`);
  }

  bulkUpdateCards(boardId, payload) {
    return axios.patch(`${this.url}/${boardId}/cards/bulk`, payload);
  }

  updateCardById(boardId, cardId, payload) {
    return axios.patch(`${this.url}/${boardId}/cards/by_id/${cardId}`, payload);
  }

  showCardById(boardId, cardId) {
    return axios.get(`${this.url}/${boardId}/cards/by_id/${cardId}`);
  }

  getCardTimeline(boardId, cardId) {
    return axios.get(`${this.url}/${boardId}/cards/by_id/${cardId}/timeline`);
  }

  updateCardDetailsById(boardId, cardId, payload) {
    return axios.patch(`${this.url}/${boardId}/cards/by_id/${cardId}`, {
      card: payload,
    });
  }

  getCardLabels(boardId, cardId) {
    return axios.get(`${this.url}/${boardId}/cards/by_id/${cardId}/labels`);
  }

  updateCardLabels(boardId, cardId, labels) {
    return axios.put(`${this.url}/${boardId}/cards/by_id/${cardId}/labels`, {
      labels,
    });
  }

  reorderCardById(boardId, cardId, payloadOrDirection) {
    const payload =
      typeof payloadOrDirection === 'string'
        ? { direction: payloadOrDirection }
        : payloadOrDirection;
    return axios.patch(
      `${this.url}/${boardId}/cards/by_id/${cardId}/reorder`,
      payload
    );
  }

  deleteCardById(boardId, cardId) {
    return axios.delete(`${this.url}/${boardId}/cards/by_id/${cardId}`);
  }
}

export default new KanbanBoardsAPI();
