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

  getProcedures() {
    return axios.get(`${this.url}/procedures`);
  }

  getResources() {
    return axios.get(`${this.url}/resources`);
  }

  createProcedure(payload) {
    return axios.post(`${this.url}/procedures`, payload);
  }

  createResource(payload) {
    return axios.post(`${this.url}/resources`, payload);
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
