import { ref } from 'vue';
import CalendarAPI from 'dashboard/api/calendar';

// Os dados que as telas de configuração partilham. Cada tela recarrega o que
// mudou; a lista de agendas, por exemplo, depende do horário aplicado.
const procedures = ref([]);
const resources = ref([]);
const schedules = ref([]);
const teams = ref([]);
const isLoading = ref(false);
const loadError = ref('');

export const useCalendarSetup = () => {
  const loadResources = async () => {
    const { data } = await CalendarAPI.getResources();
    resources.value = data || [];
  };

  const loadSchedules = async () => {
    const { data } = await CalendarAPI.getSchedules();
    schedules.value = data || [];
  };

  const loadTeams = async () => {
    const { data } = await CalendarAPI.getTeams();
    teams.value = data || [];
  };

  const loadProcedures = async () => {
    const { data } = await CalendarAPI.getProcedures();
    procedures.value = data || [];
  };

  const loadAll = async () => {
    isLoading.value = true;
    loadError.value = '';
    try {
      await Promise.all([
        loadProcedures(),
        loadResources(),
        loadSchedules(),
        loadTeams(),
      ]);
    } catch (error) {
      loadError.value =
        error?.response?.data?.message || error?.message || 'error';
    } finally {
      isLoading.value = false;
    }
  };

  return {
    procedures,
    resources,
    schedules,
    teams,
    isLoading,
    loadError,
    loadAll,
    loadProcedures,
    loadResources,
    loadSchedules,
    loadTeams,
  };
};
