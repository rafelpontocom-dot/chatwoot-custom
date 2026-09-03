/* global axios */
import ApiClient from './ApiClient';

class MarketingAPI extends ApiClient {
  constructor() {
    super('marketing', { accountScoped: true });
  }

  getModule() {
    return axios.get(`${this.url}/module`);
  }

  updateModule(payload) {
    return axios.patch(`${this.url}/module`, payload);
  }

  getTouchpoints(params = {}) {
    return axios.get(`${this.url}/touchpoints`, { params });
  }

  getSummary(params = {}) {
    return axios.get(`${this.url}/touchpoints/summary`, { params });
  }

  getIntakeSources() {
    return axios.get(`${this.url}/intake_sources`);
  }

  createIntakeSource(payload) {
    return axios.post(`${this.url}/intake_sources`, payload);
  }

  rotateIntakeSource(id) {
    return axios.post(`${this.url}/intake_sources/${id}/rotate`);
  }

  deactivateIntakeSource(id) {
    return axios.delete(`${this.url}/intake_sources/${id}`);
  }

  getConnections() {
    return axios.get(`${this.url}/connections`);
  }

  connectionAuthorizationUrl() {
    return axios.post(`${this.url}/connections/authorization_url`);
  }

  disconnect(id) {
    return axios.delete(`${this.url}/connections/${id}`);
  }

  syncPages(id) {
    return axios.post(`${this.url}/connections/${id}/sync_pages`);
  }

  subscribePage(id, pageId, subscribed) {
    return axios.post(`${this.url}/connections/${id}/subscribe_page`, {
      page_id: pageId,
      subscribed,
    });
  }

  syncLeadForms(id, pageId) {
    return axios.post(`${this.url}/connections/${id}/sync_lead_forms`, {
      page_id: pageId,
    });
  }

  getLeadForms() {
    return axios.get(`${this.url}/lead_forms`);
  }

  updateLeadForm(id, payload) {
    return axios.patch(`${this.url}/lead_forms/${id}`, payload);
  }
}

export default new MarketingAPI();
