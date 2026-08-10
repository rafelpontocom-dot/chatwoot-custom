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

  getArchivedBoards() {
    return axios.get(`${this.url}/archived`);
  }

  restoreBoard(boardId) {
    return axios.patch(`${this.url}/${boardId}/restore`);
  }

  duplicateBoard(boardId) {
    return axios.post(`${this.url}/${boardId}/duplicate`);
  }

  showBoard(boardId, config = {}) {
    return axios.get(`${this.url}/${boardId}`, config);
  }

  getSalesSummary(boardId, config = {}) {
    return axios.get(`${this.url}/${boardId}/reports/sales_summary`, config);
  }

  getActivities(boardId, config = {}) {
    return axios.get(`${this.url}/${boardId}/reports/activities`, config);
  }

  exportCards(boardId, config = {}) {
    return axios.get(`${this.url}/${boardId}/reports/export`, {
      ...config,
      responseType: 'blob',
    });
  }

  getSettings(boardId) {
    return axios.get(`${this.url}/${boardId}/settings`);
  }

  getBirthdayAutomation() {
    return axios.get(`${this.baseUrl()}/birthday_automation`);
  }

  updateBirthdayAutomation(payload) {
    return axios.patch(`${this.baseUrl()}/birthday_automation`, payload);
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

  updateSavedFilter(boardId, filterId, payload) {
    return axios.patch(
      `${this.url}/${boardId}/saved_filters/${filterId}`,
      payload
    );
  }

  deleteSavedFilter(boardId, filterId) {
    return axios.delete(`${this.url}/${boardId}/saved_filters/${filterId}`);
  }

  importExistingConversations(boardId, payload) {
    return axios.post(
      `${this.url}/${boardId}/settings/import_existing_conversations`,
      payload
    );
  }

  getAutomationRules(boardId) {
    return axios.get(`${this.url}/${boardId}/automation_rules`);
  }

  createAutomationRule(boardId, payload) {
    return axios.post(`${this.url}/${boardId}/automation_rules`, payload);
  }

  updateAutomationRule(boardId, ruleId, payload) {
    return axios.patch(
      `${this.url}/${boardId}/automation_rules/${ruleId}`,
      payload
    );
  }

  deleteAutomationRule(boardId, ruleId) {
    return axios.delete(`${this.url}/${boardId}/automation_rules/${ruleId}`);
  }

  getAutomationRuleVersions(boardId, ruleId) {
    return axios.get(
      `${this.url}/${boardId}/automation_rules/${ruleId}/versions`
    );
  }

  restoreAutomationRuleVersion(boardId, ruleId, versionId) {
    return axios.post(
      `${this.url}/${boardId}/automation_rules/${ruleId}/versions/${versionId}/restore`
    );
  }

  testAutomationRule(boardId, ruleId, cardId) {
    return axios.post(
      `${this.url}/${boardId}/automation_rules/${ruleId}/test`,
      { card_id: cardId }
    );
  }

  getAutomationExecutions(boardId, ruleId) {
    return axios.get(
      `${this.url}/${boardId}/automation_rules/${ruleId}/executions`
    );
  }

  cancelAutomationExecution(boardId, ruleId, executionId) {
    return axios.post(
      `${this.url}/${boardId}/automation_rules/${ruleId}/executions/${executionId}/cancel`
    );
  }

  retryAutomationExecution(boardId, ruleId, executionId) {
    return axios.post(
      `${this.url}/${boardId}/automation_rules/${ruleId}/executions/${executionId}/retry`
    );
  }

  runAutomationRule(boardId, ruleId, cardId) {
    return axios.post(`${this.url}/${boardId}/automation_rules/${ruleId}/run`, {
      card_id: cardId,
    });
  }

  getAllAutomationExecutions(boardId) {
    return axios.get(`${this.url}/${boardId}/automation_rules/executions`);
  }

  getAutomationMetrics(boardId) {
    return axios.get(`${this.url}/${boardId}/automation_rules/metrics`);
  }

  getAutomationConnections(boardId) {
    return axios.get(`${this.url}/${boardId}/automation_connections`);
  }

  getAutomationConnectionAudits(boardId) {
    return axios.get(`${this.url}/${boardId}/automation_connections/audits`);
  }

  createAutomationConnection(boardId, payload) {
    return axios.post(`${this.url}/${boardId}/automation_connections`, payload);
  }

  updateAutomationConnection(boardId, connectionId, payload) {
    return axios.patch(
      `${this.url}/${boardId}/automation_connections/${connectionId}`,
      payload
    );
  }

  deleteAutomationConnection(boardId, connectionId) {
    return axios.delete(
      `${this.url}/${boardId}/automation_connections/${connectionId}`
    );
  }

  resetAutomationConnectionSecret(boardId, connectionId) {
    return axios.post(
      `${this.url}/${boardId}/automation_connections/${connectionId}/reset_secret`
    );
  }

  getCadences(boardId) {
    return axios.get(`${this.url}/${boardId}/cadences`);
  }

  createCadence(boardId, payload) {
    return axios.post(`${this.url}/${boardId}/cadences`, payload);
  }

  updateCadence(boardId, cadenceId, payload) {
    return axios.patch(`${this.url}/${boardId}/cadences/${cadenceId}`, payload);
  }

  deleteCadence(boardId, cadenceId) {
    return axios.delete(`${this.url}/${boardId}/cadences/${cadenceId}`);
  }

  getAppointmentReminderRules(boardId) {
    return axios.get(`${this.url}/${boardId}/appointment_reminder_rules`);
  }

  createAppointmentReminderRule(boardId, payload) {
    return axios.post(
      `${this.url}/${boardId}/appointment_reminder_rules`,
      payload
    );
  }

  updateAppointmentReminderRule(boardId, ruleId, payload) {
    return axios.patch(
      `${this.url}/${boardId}/appointment_reminder_rules/${ruleId}`,
      payload
    );
  }

  deleteAppointmentReminderRule(boardId, ruleId) {
    return axios.delete(
      `${this.url}/${boardId}/appointment_reminder_rules/${ruleId}`
    );
  }

  getCardCadence(boardId, cardId) {
    return axios.get(`${this.url}/${boardId}/cards/by_id/${cardId}/cadence`);
  }

  enrollCardInCadence(boardId, cardId, cadenceId) {
    return axios.post(`${this.url}/${boardId}/cards/by_id/${cardId}/cadence`, {
      enrollment: { cadence_id: cadenceId },
    });
  }

  cancelCardCadence(boardId, cardId) {
    return axios.delete(`${this.url}/${boardId}/cards/by_id/${cardId}/cadence`);
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

  transferCardById(boardId, cardId, payload) {
    return axios.patch(
      `${this.url}/${boardId}/cards/by_id/${cardId}/transfer`,
      {
        transfer: payload,
      }
    );
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
