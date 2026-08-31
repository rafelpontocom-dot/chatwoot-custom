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

  uploadTemplateLogo(id, file) {
    const payload = new FormData();
    payload.append('form_template[brand_logo]', file);
    return axios.post(`${this.url}/templates/${id}/logo`, payload);
  }

  removeTemplateLogo(id) {
    return axios.delete(`${this.url}/templates/${id}/logo`);
  }

  uploadTemplateContentImage(id, file) {
    const payload = new FormData();
    payload.append('form_template[content_image]', file);
    return axios.post(`${this.url}/templates/${id}/content_images`, payload);
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

  revokeInvitation(id) {
    return axios.post(`${this.url}/invitations/${id}/revoke`);
  }

  getFieldGroups() {
    return axios.get(`${this.url}/field_groups`);
  }

  createFieldGroup(payload) {
    return axios.post(`${this.url}/field_groups`, payload);
  }

  deleteFieldGroup(id) {
    return axios.delete(`${this.url}/field_groups/${id}`);
  }

  getSubmissions() {
    return axios.get(`${this.url}/submissions`);
  }

  getSubmission(id) {
    return axios.get(`${this.url}/submissions/${id}`);
  }

  downloadSubmissionExport(id) {
    return axios.get(`${this.url}/submissions/${id}/export`, {
      responseType: 'blob',
    });
  }

  downloadSubmissionAttachment(submissionId, attachmentId) {
    return axios.get(
      `${this.url}/submissions/${submissionId}/attachments/${attachmentId}`,
      { responseType: 'blob' }
    );
  }

  resolvePendingAction(submissionId, index, decision) {
    return axios.post(
      `${this.url}/submissions/${submissionId}/resolve_pending_action`,
      { index, decision }
    );
  }

  getCardContext(kanbanCardId) {
    return axios.get(`${this.url}/kanban_cards/${kanbanCardId}`);
  }
}

export default new FormsAPI();
