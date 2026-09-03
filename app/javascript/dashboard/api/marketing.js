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
}

export default new MarketingAPI();
