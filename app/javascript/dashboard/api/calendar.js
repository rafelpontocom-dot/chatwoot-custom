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

  getBookingPage() {
    return axios.get(`${this.url}/booking_page`);
  }

  updateBookingPage(payload) {
    return axios.patch(`${this.url}/booking_page`, payload);
  }

  getBookingLinks() {
    return axios.get(`${this.url}/booking_links`);
  }

  createBookingLink(payload) {
    return axios.post(`${this.url}/booking_links`, payload);
  }

  createProcedure(payload) {
    return axios.post(`${this.url}/procedures`, payload);
  }

  updateProcedure(id, payload) {
    return axios.patch(`${this.url}/procedures/${id}`, payload);
  }

  // Arquiva: consulta já marcada é histórico clínico e não pode desaparecer.
  archiveProcedure(id) {
    return axios.delete(`${this.url}/procedures/${id}`);
  }

  createResource(payload) {
    return axios.post(`${this.url}/resources`, payload);
  }

  updateResource(id, payload) {
    return axios.patch(`${this.url}/resources/${id}`, payload);
  }

  archiveResource(id) {
    return axios.delete(`${this.url}/resources/${id}`);
  }

  getGoogleCalendarConnection(resourceId) {
    return axios.get(
      `${this.url}/resources/${resourceId}/google_calendar_connection`
    );
  }

  getGoogleCalendarAuthorizationUrl(resourceId) {
    return axios.post(
      `${this.url}/resources/${resourceId}/google_calendar_connection/authorization_url`
    );
  }

  disconnectGoogleCalendar(resourceId) {
    return axios.delete(
      `${this.url}/resources/${resourceId}/google_calendar_connection`
    );
  }

  retryGoogleCalendar(resourceId) {
    return axios.post(
      `${this.url}/resources/${resourceId}/google_calendar_connection/retry`
    );
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
