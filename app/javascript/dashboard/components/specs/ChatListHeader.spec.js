import { shallowMount } from '@vue/test-utils';
import ChatListHeader from '../ChatListHeader.vue';

vi.mock('dashboard/composables/useUISettings', () => ({
  useUISettings: () => ({
    uiSettings: { value: {} },
    updateUISettings: vi.fn(),
  }),
}));

const mountHeader = () =>
  shallowMount(ChatListHeader, {
    props: {
      pageTitle: 'Conversations',
      hasAppliedFilters: false,
      hasActiveFolders: false,
      activeStatus: 'open',
      isOnExpandedLayout: false,
      conversationStats: {},
      isListLoading: false,
    },
    global: {
      stubs: {
        RouterLink: {
          name: 'RouterLink',
          props: ['to'],
          template: '<a><slot /></a>',
        },
        ConversationBasicFilter: true,
        SwitchLayout: true,
        NextButton: true,
      },
    },
  });

describe('ChatListHeader', () => {
  it('offers a conversation search shortcut that opens native search', () => {
    const wrapper = mountHeader();
    const searchLink = wrapper.find('[data-testid="conversation-search"]');

    expect(searchLink.exists()).toBe(true);
    expect(searchLink.attributes('aria-label')).toBe(
      'Search for People, Chats, Saved Replies ..'
    );
    expect(wrapper.findComponent({ name: 'RouterLink' }).props('to')).toEqual({
      name: 'search',
      params: { tab: 'conversations' },
    });
  });
});
