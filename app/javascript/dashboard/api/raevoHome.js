/* global axios */

import ApiClient from './ApiClient';

class RaevoHomeAPI extends ApiClient {
  constructor() {
    super('raevo_home', { accountScoped: true });
  }

  // A Home manda filtro e ordem; o `get` do cliente base não leva parâmetros.
  // O axios é o global já autenticado, o mesmo que o ApiClient usa.
  get(params = {}) {
    return axios.get(this.url, { params });
  }

  // Só os insights que a pessoa pôs no Início, com os mesmos filtros da tela.
  getInsights(params = {}) {
    return axios.get(`${this.url}/insights`, { params });
  }

  // O Início que um administrador aplica a quem ainda não arrumou o seu.
  saveTeamLayout(layout) {
    return axios.put(`${this.url}/team_layout`, { layout });
  }
}

export default new RaevoHomeAPI();
