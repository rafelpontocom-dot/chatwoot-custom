/* global axios */
import ApiClient from './ApiClient';

class FormsAPI extends ApiClient {
  constructor() {
    super('forms', { accountScoped: true });
  }

  getTemplates() {
    return axios.get(`${this.url}/templates`);
  }

  getTemplate(id) {
    return axios.get(`${this.url}/templates/${id}`);
  }

  createTemplate(payload) {
    return axios.post(`${this.url}/templates`, payload);
  }

  updateTemplate(id, payload) {
    return axios.patch(`${this.url}/templates/${id}`, payload);
  }

  publishTemplate(id, schema) {
    return axios.post(`${this.url}/templates/${id}/publish`, {
      form_template: { schema },
    });
  }

  duplicateTemplate(id, payload) {
    return axios.post(`${this.url}/templates/${id}/duplicate`, payload);
  }

  getVersions(id) {
    return axios.get(`${this.url}/templates/${id}/versions`);
  }

  createInvitation(id, payload) {
    return axios.post(`${this.url}/templates/${id}/invitations`, payload);
  }

  getSubmissions() {
    return axios.get(`${this.url}/submissions`);
  }

  getSubmission(id) {
    return axios.get(`${this.url}/submissions/${id}`);
  }

  getCardContext(kanbanCardId) {
    return axios.get(`${this.url}/kanban_cards/${kanbanCardId}`);
  }
}

export default new FormsAPI();
