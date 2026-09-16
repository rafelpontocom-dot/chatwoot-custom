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

  // Importa já os compromissos do Google e volta a enviar as consultas futuras.
  syncGoogleCalendar(resourceId) {
    return axios.post(
      `${this.url}/resources/${resourceId}/google_calendar_connection/sync`
    );
  }

  getFeegowConnection() {
    return axios.get(`${this.url}/feegow_connection`);
  }

  updateFeegowConnection(payload) {
    return axios.put(`${this.url}/feegow_connection`, payload);
  }

  syncFeegowConnection() {
    return axios.post(`${this.url}/feegow_connection/sync`);
  }

  disconnectFeegow() {
    return axios.delete(`${this.url}/feegow_connection`);
  }

  getFeegowProfessionals() {
    return axios.get(`${this.url}/feegow_connection/professionals`);
  }

  getBusyBlocks(params) {
    return axios.get(`${this.url}/busy_blocks`, { params });
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

  getSchedules() {
    return axios.get(`${this.url}/schedules`);
  }

  createSchedule(payload) {
    return axios.post(`${this.url}/schedules`, payload);
  }

  updateSchedule(id, payload) {
    return axios.patch(`${this.url}/schedules/${id}`, payload);
  }

  deleteSchedule(id) {
    return axios.delete(`${this.url}/schedules/${id}`);
  }

  // Troca a semana e as exceções inteiras: { weekly, overrides }.
  updateScheduleRules(id, payload) {
    return axios.put(`${this.url}/schedules/${id}/rules`, payload);
  }

  // Com dry_run devolve só quantas consultas futuras ficariam fora do horário.
  applySchedule(id, payload) {
    return axios.post(`${this.url}/schedules/${id}/apply_to`, payload);
  }

  getResourceWorkingHours(resourceId) {
    return axios.get(`${this.url}/resources/${resourceId}/working_hours`);
  }

  updateResourceWorkingHours(resourceId, payload) {
    return axios.put(
      `${this.url}/resources/${resourceId}/working_hours`,
      payload
    );
  }

  getTeams() {
    return axios.get(`${this.url}/teams`);
  }

  createTeam(payload) {
    return axios.post(`${this.url}/teams`, payload);
  }

  updateTeam(id, payload) {
    return axios.patch(`${this.url}/teams/${id}`, payload);
  }

  deleteTeam(id) {
    return axios.delete(`${this.url}/teams/${id}`);
  }

  getProcedureOwnSchedule(id) {
    return axios.get(`${this.url}/procedures/${id}/own_schedule`);
  }

  updateProcedureOwnSchedule(id, payload) {
    return axios.put(`${this.url}/procedures/${id}/own_schedule`, payload);
  }

  getProcedureAvailabilityPreview(id, params) {
    return axios.get(`${this.url}/procedures/${id}/availability_preview`, {
      params,
    });
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
