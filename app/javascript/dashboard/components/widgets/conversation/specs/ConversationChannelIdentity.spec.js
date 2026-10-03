import { shallowMount } from '@vue/test-utils';
import { ref } from 'vue';
import ConversationCard from '../ConversationCard.vue';
import ConversationCardExpanded from 'dashboard/components-next/Conversation/ConversationCard/ConversationCardExpanded.vue';
import HistoryCard from 'dashboard/components-next/Conversation/ConversationCard/ConversationCard.vue';
import InboxCard from 'dashboard/components-next/Inbox/InboxCard.vue';
import SearchConversation from 'dashboard/modules/search/components/SearchResultConversationItem.vue';
import SearchMessage from 'dashboard/modules/search/components/SearchResultMessageItem.vue';
import ChannelIcon from 'dashboard/components-next/icon/ChannelIcon.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

vi.mock('vue-router', () => ({
  useRouter: () => ({ push: vi.fn() }),
  useRoute: () => ({ params: { accountId: 3 } }),
}));

const searchInbox = ref(null);
vi.mock('dashboard/composables/useInbox', () => ({
  useInbox: () => ({ inbox: searchInbox }),
}));

const contact = { name: 'Pedro Raevo', availability_status: 'offline' };
const chat = {
  id: 1,
  labels: [],
  messages: [],
  unread_count: 0,
  timestamp: 1700000000,
  created_at: 1700000000,
};
const inbox = {
  id: 1,
  name: 'WhatsApp da clinica',
  channel_type: 'Channel::Api',
  avatar_url: '/clinic-channel.png',
};
const camelInbox = {
  id: inbox.id,
  name: inbox.name,
  channelType: inbox.channel_type,
  avatarUrl: inbox.avatar_url,
};

const layouts = [
  [
    'condensed without inbox name',
    ConversationCard,
    { chat, currentContact: contact, inbox },
  ],
  [
    'condensed with inbox name',
    ConversationCard,
    { chat, currentContact: contact, inbox, showInboxName: true },
  ],
  [
    'expanded without inbox name',
    ConversationCardExpanded,
    { chat, currentContact: contact, inbox },
  ],
  [
    'expanded in an inbox view',
    ConversationCardExpanded,
    {
      chat,
      currentContact: contact,
      inbox,
      showInboxName: true,
      isInboxView: true,
    },
  ],
  [
    'contact history',
    HistoryCard,
    { conversation: chat, contact, stateInbox: camelInbox, accountLabels: [] },
  ],
  [
    'notification',
    InboxCard,
    {
      stateInbox: camelInbox,
      inboxItem: { primaryActor: { meta: { sender: contact } } },
    },
  ],
  ['conversation search', SearchConversation, { id: 1, accountId: 3, inbox }],
  ['message search', SearchMessage, { id: 1, accountId: 3, inboxId: inbox.id }],
];

const mountLayout = (component, props) =>
  shallowMount(component, {
    props,
    global: {
      directives: { 'dompurify-html': () => {} },
      stubs: {
        ChannelIcon: false,
        InboxName: false,
        CardLayout: { template: '<div><slot /></div>' },
        'router-link': { template: '<a><slot /></a>' },
        'fluent-icon': true,
      },
    },
  });

describe.each(layouts)(
  'conversation channel identity: %s',
  (_name, component, props) => {
    beforeEach(() => {
      searchInbox.value = camelInbox;
    });

    it('renders the image configured on the inbox instead of the API glyph', () => {
      const wrapper = mountLayout(component, props);

      expect(wrapper.find('img').attributes('src')).toBe(inbox.avatar_url);
    });

    it('falls back to the channel glyph when the image fails', async () => {
      const wrapper = mountLayout(component, props);
      await wrapper.find('img').trigger('error');

      expect(wrapper.find('img').exists()).toBe(false);
      expect(
        wrapper.findComponent(ChannelIcon).findComponent(Icon).props('icon')
      ).toBe('i-woot-api');
    });
  }
);
