import { shallowMount } from '@vue/test-utils';
import { computed, nextTick, ref } from 'vue';
import ComposeConversation from '../ComposeConversation.vue';

const dispatch = vi.fn();
const contactsNoStore = ref({});

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));

vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({ dispatch }),
  useMapGetter: name => {
    if (name === 'contacts/getContactById')
      return computed(() => id => contactsNoStore.value[id]);
    if (name === 'inboxes/getInboxes')
      return computed(() => [{ id: 7, name: 'WhatsApp da clínica' }]);
    return computed(() => ({}));
  },
}));

vi.mock('dashboard/composables/useUISettings', () => ({
  useUISettings: () => ({ fetchSignatureFlagFromUISettings: vi.fn() }),
}));

vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

const fetchContactableInboxes = vi.fn();
vi.mock(
  'dashboard/components-next/NewConversation/helpers/composeConversationHelper',
  () => ({
    createContactSearcher: () => vi.fn(),
    createNewContact: vi.fn(),
    fetchContactableInboxes: (...args) => fetchContactableInboxes(...args),
    processContactableInboxes: inboxes => inboxes,
    mergeInboxDetails: inboxes => inboxes,
  })
);

const mountCompose = (props = {}) =>
  shallowMount(ComposeConversation, {
    props,
    global: { stubs: { Popover: { template: '<div><slot /></div>' } } },
  });

describe('ComposeConversation', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    contactsNoStore.value = {};
    fetchContactableInboxes.mockResolvedValue([{ id: 7, sourceId: 'x' }]);
  });

  // O balão do funil abre o compositor sem passar por Contatos, então o contato
  // não está no store. Sem isto o «Para:» ficava em branco — e com `contactId`
  // fixo o campo de busca está desligado, logo não havia como escolher ninguém.
  it('fetches the contact when it is not in the store yet', () => {
    mountCompose({ contactId: '42' });

    expect(dispatch).toHaveBeenCalledWith('contacts/show', { id: '42' });
  });

  it('does not fetch again when the contact is already in the store', () => {
    contactsNoStore.value = { 42: { id: 42, name: 'Pedro' } };
    mountCompose({ contactId: '42' });

    expect(dispatch).not.toHaveBeenCalledWith('contacts/show', { id: '42' });
  });

  // Oportunidade que nunca teve conversa tem contato sem vínculo nenhum: pelos
  // vínculos a lista vinha vazia e a tela dizia que não havia caixa disponível.
  it('offers the inboxes the contact can be reached on, not the ones it already has', async () => {
    contactsNoStore.value = {
      42: { id: 42, name: 'Pedro', contactInboxes: [] },
    };
    const wrapper = mountCompose({ contactId: '42' });
    await nextTick();
    await nextTick();

    expect(fetchContactableInboxes).toHaveBeenCalledWith(42);
    expect(wrapper.vm.selectedContact.contactInboxes).toEqual([
      { id: 7, sourceId: 'x' },
    ]);
  });

  it('keeps the contact selected when the reachable inboxes cannot be loaded', async () => {
    fetchContactableInboxes.mockRejectedValue(new Error('offline'));
    contactsNoStore.value = {
      42: { id: 42, name: 'Pedro', contactInboxes: [] },
    };
    const wrapper = mountCompose({ contactId: '42' });
    await nextTick();
    await nextTick();

    expect(wrapper.vm.selectedContact.name).toBe('Pedro');
  });
});
