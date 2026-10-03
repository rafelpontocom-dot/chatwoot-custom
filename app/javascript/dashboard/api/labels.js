/* global axios */
import CacheEnabledApiClient from './CacheEnabledApiClient';

class LabelsAPI extends CacheEnabledApiClient {
  constructor() {
    super('labels', { accountScoped: true });
  }

  // eslint-disable-next-line class-methods-use-this
  get cacheModelName() {
    return 'label';
  }

  reorder(labelIds) {
    return axios.post(`${this.url}/reorder`, { label_ids: labelIds });
  }
}

export default new LabelsAPI();
