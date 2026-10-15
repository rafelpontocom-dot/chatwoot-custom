import { mount } from '@vue/test-utils';
import { createStore } from 'vuex';
import ConversationHeader from '../ConversationHeader.vue';

vi.mock('vue-router', async importOriginal => ({
  ...(await importOriginal()),
  useRoute: () => ({ params: {}, name: '' }),
}));
vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));

// O cabeçalho nativo com o botão verdadeiro do Raevo: se um upgrade levar a
// troca do avatar, clicar no avatar deixa de abrir o contacto e isto falha.
const updateUISettings = vi.fn();
const buildStore = uiSettings =>
  createStore({
    getters: {
      getSelectedChat: () => ({ id: 7, inbox_id: 1 }),
      getCurrentAccountId: () => 1,
      getUISettings: () => uiSettings,
      'contacts/getContact': () => () => ({ id: 3, name: 'Alysson Oliveira' }),
      'inboxes/getInbox': () => () => ({ id: 1, channel_type: 'Channel::Api' }),
      'inboxes/getInboxById': () => () => ({ id: 1 }),
      'inboxes/getInboxes': () => [{ id: 1 }],
    },
    actions: {
      updateUISettings: (_, payload) => updateUISettings(payload.uiSettings),
    },
  });

const mountHeader = (uiSettings = {}) =>
  mount(ConversationHeader, {
    props: {
      chat: { id: 7, inbox_id: 1, meta: { sender: { id: 3 } } },
    },
    global: {
      plugins: [buildStore(uiSettings)],
      mocks: { $t: key => key },
      directives: { tooltip: {} },
      stubs: {
        Avatar: true,
        BackButton: true,
        InboxName: true,
        MoreActions: true,
        SLACardLabel: true,
        ConversationCallButton: true,
        FluentIcon: true,
      },
    },
  });

describe('ConversationHeader — o avatar abre o contacto (123jpnbcxh2)', () => {
  beforeEach(() => updateUISettings.mockClear());

  it('opens the contact panel and closes the copilot when the avatar is clicked', async () => {
    const wrapper = mountHeader({ is_contact_sidebar_open: false });
    const avatar = wrapper.find('[data-testid="raevo-contact-avatar-toggle"]');

    expect(avatar.attributes('aria-expanded')).toBe('false');
    await avatar.trigger('click');

    expect(updateUISettings).toHaveBeenCalledWith(
      expect.objectContaining({
        is_contact_sidebar_open: true,
        is_copilot_panel_open: false,
      })
    );
  });

  it('closes the panel when it is already open', async () => {
    const wrapper = mountHeader({ is_contact_sidebar_open: true });

    await wrapper
      .find('[data-testid="raevo-contact-avatar-toggle"]')
      .trigger('click');

    expect(updateUISettings).toHaveBeenCalledWith(
      expect.objectContaining({ is_contact_sidebar_open: false })
    );
  });
});
