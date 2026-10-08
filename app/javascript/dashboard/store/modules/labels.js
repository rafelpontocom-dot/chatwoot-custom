import * as MutationHelpers from 'shared/helpers/vuex/mutationHelpers';
import types from '../mutation-types';
import LabelsAPI from '../../api/labels';
import AnalyticsHelper from '../../helper/AnalyticsHelper';
import { LABEL_EVENTS } from '../../helper/AnalyticsHelper/events';

// A ordem manual vale em todo o lado onde as etiquetas se listam. Sem posição,
// a etiqueta vai para o fim e desempata por nome — que é a ordem de sempre para
// a conta que nunca reordenou.
const compareLabels = (a, b) => {
  const positionDiff = (a.position ?? Infinity) - (b.position ?? Infinity);
  if (positionDiff) return positionDiff;
  return a.title.localeCompare(b.title);
};

export const state = {
  records: [],
  uiFlags: {
    isFetching: false,
    isFetchingItem: false,
    isCreating: false,
    isDeleting: false,
  },
};

export const getters = {
  getLabels(_state) {
    return _state.records;
  },
  getUIFlags(_state) {
    return _state.uiFlags;
  },
  getLabelsOnSidebar(_state) {
    return _state.records
      .filter(record => record.show_on_sidebar)
      .sort(compareLabels);
  },
  getLabelById: _state => id => {
    return _state.records.find(record => record.id === Number(id)) || {};
  },
};

export const actions = {
  revalidate: async function revalidate({ commit }, { newKey }) {
    try {
      const isExistingKeyValid = await LabelsAPI.validateCacheKey(newKey);
      if (!isExistingKeyValid) {
        const response = await LabelsAPI.refetchAndCommit(newKey);
        commit(types.SET_LABELS, response.data.payload);
      }
    } catch (error) {
      // Ignore error
    }
  },

  get: async function getLabels({ commit }) {
    commit(types.SET_LABEL_UI_FLAG, { isFetching: true });
    try {
      const response = await LabelsAPI.get(true);
      commit(types.SET_LABELS, response.data.payload.sort(compareLabels));
    } catch (error) {
      // Ignore error
    } finally {
      commit(types.SET_LABEL_UI_FLAG, { isFetching: false });
    }
  },

  create: async function createLabels({ commit }, cannedObj) {
    commit(types.SET_LABEL_UI_FLAG, { isCreating: true });
    try {
      const response = await LabelsAPI.create(cannedObj);
      AnalyticsHelper.track(LABEL_EVENTS.CREATE);
      commit(types.ADD_LABEL, response.data);
    } catch (error) {
      const errorMessage = error?.response?.data?.message;
      // O código deixa o ecrã dizer na língua de quem usa porque falhou.
      throw Object.assign(new Error(errorMessage), {
        code: error?.response?.data?.code,
      });
    } finally {
      commit(types.SET_LABEL_UI_FLAG, { isCreating: false });
    }
  },

  update: async function updateLabels({ commit }, { id, ...updateObj }) {
    commit(types.SET_LABEL_UI_FLAG, { isUpdating: true });
    try {
      const response = await LabelsAPI.update(id, updateObj);
      AnalyticsHelper.track(LABEL_EVENTS.UPDATE);
      commit(types.EDIT_LABEL, response.data);
    } catch (error) {
      throw Object.assign(new Error(error), {
        code: error?.response?.data?.code,
      });
    } finally {
      commit(types.SET_LABEL_UI_FLAG, { isUpdating: false });
    }
  },

  reorder: async function reorderLabels(
    { commit, state: { records: previous } },
    labelIds
  ) {
    // RAEVO (08/10, 123jpnbc243): a etiqueta arrastada fica logo no sítio novo;
    // se o servidor não gravar, volta ao antigo e quem chamou mostra o erro.
    const byId = new Map(previous.map(label => [label.id, label]));
    commit(
      types.SET_LABELS,
      labelIds.map(id => byId.get(id))
    );
    commit(types.SET_LABEL_UI_FLAG, { isUpdating: true });
    try {
      await LabelsAPI.reorder(labelIds).catch(error => {
        commit(types.SET_LABELS, previous);
        throw error;
      });
      // A cópia local das etiquetas só se renova pelo aviso em tempo real, e
      // `cache_keys` é servido de cache até 5 minutos: sem isto, recarregar a
      // página devolvia a ordem antiga a quem acabou de a mudar.
      const response = await LabelsAPI.refetchAndCommit();
      commit(types.SET_LABELS, response.data.payload);
    } finally {
      commit(types.SET_LABEL_UI_FLAG, { isUpdating: false });
    }
  },

  delete: async function deleteLabels({ commit }, id) {
    commit(types.SET_LABEL_UI_FLAG, { isDeleting: true });
    try {
      await LabelsAPI.delete(id);
      AnalyticsHelper.track(LABEL_EVENTS.DELETED);
      commit(types.DELETE_LABEL, id);
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_LABEL_UI_FLAG, { isDeleting: false });
    }
  },
};

export const mutations = {
  [types.SET_LABEL_UI_FLAG](_state, data) {
    _state.uiFlags = {
      ..._state.uiFlags,
      ...data,
    };
  },

  [types.SET_LABELS]: MutationHelpers.set,
  [types.ADD_LABEL]: MutationHelpers.create,
  [types.EDIT_LABEL]: MutationHelpers.update,
  [types.DELETE_LABEL]: MutationHelpers.destroy,
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
