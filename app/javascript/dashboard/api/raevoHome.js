import ApiClient from './ApiClient';

class RaevoHomeAPI extends ApiClient {
  constructor() {
    super('raevo_home', { accountScoped: true });
  }
}

export default new RaevoHomeAPI();
