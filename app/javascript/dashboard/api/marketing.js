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
}

export default new MarketingAPI();
