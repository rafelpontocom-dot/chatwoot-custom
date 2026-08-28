/* global axios */
import ApiClient from './ApiClient';

class FinanceAPI extends ApiClient {
  constructor() {
    super('finance', { accountScoped: true });
  }

  getModule() {
    return axios.get(`${this.url}/module`);
  }

  updateModule(payload) {
    return axios.patch(`${this.url}/module`, payload);
  }

  getProviderConnections() {
    return axios.get(`${this.url}/provider_connections`);
  }

  createProviderConnection(payload) {
    return axios.post(`${this.url}/provider_connections`, payload);
  }

  updateProviderConnection(id, payload) {
    return axios.patch(`${this.url}/provider_connections/${id}`, payload);
  }

  deleteProviderConnection(id) {
    return axios.delete(`${this.url}/provider_connections/${id}`);
  }

  verifyProviderConnection(id) {
    return axios.post(`${this.url}/provider_connections/${id}/verify`);
  }

  getWebhookDeliveries(providerConnectionId) {
    return axios.get(
      `${this.url}/provider_connections/${providerConnectionId}/webhook_deliveries`
    );
  }

  retryWebhookDelivery(providerConnectionId, id) {
    return axios.post(
      `${this.url}/provider_connections/${providerConnectionId}/webhook_deliveries/${id}/retry`
    );
  }

  getPayments(params = {}) {
    return axios.get(`${this.url}/payments`, { params });
  }

  getPaymentsSummary(params = {}) {
    return axios.get(`${this.url}/payments/summary`, { params });
  }

  getPayment(id) {
    return axios.get(`${this.url}/payments/${id}`);
  }

  createPayment(payload) {
    return axios.post(`${this.url}/payments`, payload);
  }

  cancelPayment(id) {
    return axios.post(`${this.url}/payments/${id}/cancel`);
  }

  markPaymentReceived(id) {
    return axios.post(`${this.url}/payments/${id}/mark_received`);
  }

  requestPaymentRefund(id, description) {
    return axios.post(`${this.url}/payments/${id}/refund`, {
      refund: { description },
    });
  }
}

export default new FinanceAPI();
