import { mount, flushPromises } from '@vue/test-utils';
import { ref } from 'vue';
import RaevoConversationSearch from '../RaevoConversationSearch.vue';

const dispatch = vi.fn();
const contactRecords = ref([]);
const messageRecords = ref([]);
const uiFlags = ref({ contact: { isFetching: false }, message: {} });

vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({ dispatch }),
  useMapGetter: name =>
    ({
      'conversationSearch/getContactRecords': contactRecords,
      'conversationSearch/getMessageRecords': messageRecords,
      'conversationSearch/getUIFlags': uiFlags,
      getCurrentAccountId: ref(1),
    })[name],
}));
vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, params) => (params ? `${key}:${JSON.stringify(params)}` : key),
  }),
}));

const montar = () =>
  mount(RaevoConversationSearch, {
    global: {
      stubs: {
        ComposeConversation: {
          template: '<div><slot name="trigger" :is-open="false" /></div>',
        },
        Button: { template: '<button />' },
        SearchResultContactsList: {
          props: ['contacts', 'query', 'isFetching'],
          template:
            '<ul data-testid="contacts"><li v-for="c in contacts" :key="c.id">{{ c.name }}</li></ul>',
        },
        SearchResultMessagesList: {
          props: ['messages', 'query', 'isFetching'],
          template:
            '<ul data-testid="messages"><li v-for="m in messages" :key="m.id">{{ m.content }}</li></ul>',
        },
      },
    },
  });

const escrever = async (wrapper, texto) => {
  await wrapper
    .get('[data-testid="raevo-conversation-search-input"]')
    .setValue(texto);
  vi.advanceTimersByTime(400);
  await flushPromises();
};

describe('RaevoConversationSearch (123jpnbd8y6, proposta B)', () => {
  beforeEach(() => {
    vi.useFakeTimers();
    dispatch.mockClear();
    contactRecords.value = [];
    messageRecords.value = [];
    uiFlags.value = { contact: { isFetching: false }, message: {} };
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('opens with the field and the compose button, and no results', () => {
    const wrapper = montar();

    expect(
      wrapper.find('[data-testid="raevo-conversation-search-input"]').exists()
    ).toBe(true);
    expect(
      wrapper.find('[data-testid="raevo-conversation-search-compose"]').exists()
    ).toBe(true);
    expect(
      wrapper.find('[data-testid="raevo-conversation-search-results"]').exists()
    ).toBe(false);
  });

  it('does not search a single character', async () => {
    const wrapper = montar();

    await escrever(wrapper, 'a');

    expect(dispatch).not.toHaveBeenCalled();
    expect(
      wrapper.find('[data-testid="raevo-conversation-search-results"]').exists()
    ).toBe(false);
  });

  it('searches contacts and messages once the typing settles', async () => {
    const wrapper = montar();

    await escrever(wrapper, 'maria');

    expect(dispatch).toHaveBeenCalledWith('conversationSearch/contactSearch', {
      q: 'maria',
      page: 1,
    });
    expect(dispatch).toHaveBeenCalledWith('conversationSearch/messageSearch', {
      q: 'maria',
      page: 1,
    });
  });

  // O pedido do Pedro: nome e telefone sempre no topo. Quem procura «Maria»
  // quer a pessoa, não a frase onde o nome calhou de aparecer.
  it('puts contacts above messages', async () => {
    contactRecords.value = [{ id: 1, name: 'Maria Silva' }];
    messageRecords.value = [{ id: 9, content: 'quero agendar, Maria' }];
    const wrapper = montar();

    await escrever(wrapper, 'maria');

    const listas = wrapper.findAll('[data-testid]');
    const ordem = listas
      .map(node => node.attributes('data-testid'))
      .filter(id => ['contacts', 'messages'].includes(id));

    expect(ordem).toEqual(['contacts', 'messages']);
  });

  it('says so when the query finds nothing', async () => {
    const wrapper = montar();

    await escrever(wrapper, 'zzz');

    expect(wrapper.text()).toContain('RAEVO_CONVERSATION.SEARCH.EMPTY');
  });

  it('tells the list when it is searching, and when it stops', async () => {
    const wrapper = montar();

    await escrever(wrapper, 'maria');
    await escrever(wrapper, '');

    const eventos = wrapper.emitted('update:searching').map(([value]) => value);
    expect(eventos).toEqual([false, true, false]);
  });

  it('clears the results when the field is emptied', async () => {
    const wrapper = montar();

    await escrever(wrapper, 'maria');
    dispatch.mockClear();
    await wrapper
      .get('[data-testid="raevo-conversation-search-clear"]')
      .trigger('click');

    expect(dispatch).toHaveBeenCalledWith(
      'conversationSearch/clearSearchResults'
    );
  });
});
