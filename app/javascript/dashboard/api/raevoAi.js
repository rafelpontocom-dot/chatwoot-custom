/* global axios */
import ApiClient from './ApiClient';

class RaevoAiAPI extends ApiClient {
  constructor() {
    super('raevo_ai/overview', { accountScoped: true });
  }

  getOpportunityTab() {
    return axios.get(`${this.baseUrl()}/raevo_ai/opportunity_tab`);
  }

  updateOpportunityTab(data) {
    return axios.patch(`${this.baseUrl()}/raevo_ai/opportunity_tab`, data);
  }
}

export default new RaevoAiAPI();
