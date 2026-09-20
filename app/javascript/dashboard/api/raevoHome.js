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
}

export default new RaevoHomeAPI();
