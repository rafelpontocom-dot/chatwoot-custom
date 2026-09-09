/* global axios */
import ApiClient from './ApiClient';

class RaevoAiAPI extends ApiClient {
  constructor() {
    super('raevo_ai/overview', { accountScoped: true });
  }

  getOpportunityTab() {
    return axios.get(`${this.baseUrl()}/raevo_ai/opportunity_tab`);
  }

  getAssistantDraft() {
    return axios.get(`${this.baseUrl()}/raevo_ai/assistant_draft`);
  }

  getPauseState() {
    return axios.get(`${this.baseUrl()}/raevo_ai/pause`);
  }

  savePauseState(data) {
    return axios.put(`${this.baseUrl()}/raevo_ai/pause`, data);
  }

  getServiceHours() {
    return axios.get(`${this.baseUrl()}/raevo_ai/service_hours`);
  }

  saveServiceHours(data) {
    return axios.put(`${this.baseUrl()}/raevo_ai/service_hours`, data);
  }

  saveAssistantDraft(data) {
    return axios.put(`${this.baseUrl()}/raevo_ai/assistant_draft`, data);
  }

  simulateAssistantDraft(data) {
    return axios.post(
      `${this.baseUrl()}/raevo_ai/assistant_draft/simulate`,
      data
    );
  }

  reviewAssistantDraft(data) {
    return axios.post(
      `${this.baseUrl()}/raevo_ai/assistant_draft/review`,
      data
    );
  }

  publishAssistantDraft(data) {
    return axios.post(
      `${this.baseUrl()}/raevo_ai/assistant_draft/publish`,
      data
    );
  }

  updateOpportunityTab(data) {
    return axios.patch(`${this.baseUrl()}/raevo_ai/opportunity_tab`, data);
  }
}

export default new RaevoAiAPI();
