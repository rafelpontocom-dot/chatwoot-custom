import { shallowMount } from '@vue/test-utils';
import { computed, nextTick, ref } from 'vue';
import ComposeConversation from '../ComposeConversation.vue';

const dispatch = vi.fn();
const store = ref({});

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));

vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({ dispatch }),
  useMapGetter: name => {
    // O getter verdadeiro devolve `{}` para um id que não conhece, nunca
    // `undefined`. Um duplo que devolvia `undefined` deixou passar em produção
    // um `if (!contato)` que nunca era verdadeiro: a busca ia com id indefinido,
    // dava 404, e a tela dizia que não havia caixa de entrada disponível.
    if (name === 'contacts/getContactById')
      return computed(() => id => store.value[id] || {});
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

const abrir = async wrapper => {
  wrapper.vm.onPopoverShow();
  await nextTick();
  await nextTick();
  await nextTick();
};

describe('ComposeConversation', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    store.value = {};
    fetchContactableInboxes.mockResolvedValue([{ id: 7, sourceId: 'x' }]);
    dispatch.mockImplementation((action, { id } = {}) => {
      if (action === 'contacts/show')
        store.value[id] = { id: Number(id), name: 'Pedro', contactInboxes: [] };
      return Promise.resolve();
    });
  });

  // Num funil com 23 oportunidades sem conversa há 23 compositores montados.
  it('asks for nothing until the composer is opened', () => {
    mountCompose({ contactId: '42' });

    expect(dispatch).not.toHaveBeenCalled();
    expect(fetchContactableInboxes).not.toHaveBeenCalled();
  });

  it('fetches the contact the store does not know, and never with an undefined id', async () => {
    const wrapper = mountCompose({ contactId: '42' });
    await abrir(wrapper);

    expect(dispatch).toHaveBeenCalledWith('contacts/show', { id: '42' });
    expect(fetchContactableInboxes).toHaveBeenCalledWith(42);
    expect(fetchContactableInboxes).not.toHaveBeenCalledWith(undefined);
  });

  it('does not fetch the contact again when the store already has it', async () => {
    store.value[42] = { id: 42, name: 'Pedro', contactInboxes: [] };
    const wrapper = mountCompose({ contactId: '42' });
    await abrir(wrapper);

    expect(dispatch).not.toHaveBeenCalledWith('contacts/show', { id: '42' });
    expect(fetchContactableInboxes).toHaveBeenCalledWith(42);
  });

  // Oportunidade que nunca teve conversa tem contato sem vínculo nenhum: pelos
  // vínculos a lista vinha vazia e a tela dizia que não havia caixa disponível.
  it('offers the inboxes the contact can be reached on, not the ones it already has', async () => {
    const wrapper = mountCompose({ contactId: '42' });
    await abrir(wrapper);

    expect(wrapper.vm.selectedContact.contactInboxes).toEqual([
      { id: 7, sourceId: 'x' },
    ]);
  });

  it('keeps the contact selected when the reachable inboxes cannot be loaded', async () => {
    fetchContactableInboxes.mockRejectedValue(new Error('offline'));
    const wrapper = mountCompose({ contactId: '42' });
    await abrir(wrapper);

    expect(wrapper.vm.selectedContact.name).toBe('Pedro');
  });
});
