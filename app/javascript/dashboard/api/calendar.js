/* global axios */
import ApiClient from './ApiClient';

class CalendarAPI extends ApiClient {
  constructor() {
    super('calendar', { accountScoped: true });
  }

  getAppointments(params) {
    return axios.get(`${this.url}/appointments`, { params });
  }

  getAppointment(id) {
    return axios.get(`${this.url}/appointments/${id}`);
  }

  getAvailability(params) {
    return axios.get(`${this.url}/appointments/availability`, { params });
  }

  getProcedures() {
    return axios.get(`${this.url}/procedures`);
  }

  getResources() {
    return axios.get(`${this.url}/resources`);
  }

  createProcedure(payload) {
    return axios.post(`${this.url}/procedures`, payload);
  }

  updateProcedure(id, payload) {
    return axios.patch(`${this.url}/procedures/${id}`, payload);
  }

  createResource(payload) {
    return axios.post(`${this.url}/resources`, payload);
  }

  getAvailabilityRules(resourceId) {
    return axios.get(`${this.url}/resources/${resourceId}/availability_rules`);
  }

  createAvailabilityRule(resourceId, payload) {
    return axios.post(
      `${this.url}/resources/${resourceId}/availability_rules`,
      payload
    );
  }

  updateAvailabilityRule(resourceId, ruleId, payload) {
    return axios.patch(
      `${this.url}/resources/${resourceId}/availability_rules/${ruleId}`,
      payload
    );
  }

  deleteAvailabilityRule(resourceId, ruleId) {
    return axios.delete(
      `${this.url}/resources/${resourceId}/availability_rules/${ruleId}`
    );
  }

  createAppointment(payload) {
    return axios.post(`${this.url}/appointments`, payload);
  }

  updateAppointment(id, payload) {
    return axios.patch(`${this.url}/appointments/${id}`, payload);
  }

  rescheduleAppointment(id, payload) {
    return axios.post(`${this.url}/appointments/${id}/reschedule`, payload);
  }
}

export default new CalendarAPI();
