import { mount } from '@vue/test-utils';
import { createRouter, createMemoryHistory } from 'vue-router';
import SidebarGroupHeader from '../SidebarGroupHeader.vue';

const getterValues = {};
vi.mock('dashboard/composables/store.js', () => ({
  useMapGetter: key => ({ value: getterValues[key] ?? 0 }),
}));

// O router é o verdadeiro de propósito. No merge do 4.18 este componente ficou
// com o `router-link` de um lado e o `href` do outro, sem `to`: um `RouterLink`
// stubado aceitava isso calado, e o real rebentava a barra lateral inteira.
const router = createRouter({
  history: createMemoryHistory(),
  routes: [
    { path: '/', component: { template: '<div />' } },
    { path: '/calendar', name: 'calendar_index', component: {} },
  ],
});

const mountHeader = props =>
  mount(SidebarGroupHeader, {
    props: { label: 'Agenda', ...props },
    global: { plugins: [router], stubs: { Icon: true } },
  });

describe('SidebarGroupHeader', () => {
  it('renders a real link to the destination', () => {
    const wrapper = mountHeader({ to: { name: 'calendar_index' } });

    expect(wrapper.element.tagName).toBe('A');
    expect(wrapper.attributes('href')).toBe('/calendar');
  });

  it('toggles instead of following the link on a plain click', async () => {
    const wrapper = mountHeader({ to: { name: 'calendar_index' } });
    await wrapper.trigger('click');

    expect(wrapper.emitted('toggle')).toHaveLength(1);
  });

  it('leaves a modified click to the browser', async () => {
    const wrapper = mountHeader({ to: { name: 'calendar_index' } });
    await wrapper.trigger('click', { metaKey: true });

    expect(wrapper.emitted('toggle')).toBeUndefined();
  });

  it('renders a button when the group has no destination', () => {
    const wrapper = mountHeader({ to: undefined, expandable: true });

    expect(wrapper.element.tagName).toBe('BUTTON');
    expect(wrapper.attributes('aria-expanded')).toBe('false');
  });

  // RAEVO (08/10, 123jpnbc242): o número ao lado de «Conversas».
  describe('unread count of a group', () => {
    beforeEach(() => {
      getterValues['conversationUnreadCounts/getAllUnreadCount'] = 4;
    });
    afterEach(() => {
      delete getterValues['conversationUnreadCounts/getAllUnreadCount'];
    });

    const conversations = isExpanded =>
      mountHeader({
        label: 'Conversas',
        expandable: true,
        isExpanded,
        getterKeys: { count: 'conversationUnreadCounts/getAllUnreadCount' },
      });

    it('shows the count beside a closed group', () => {
      expect(conversations(false).text()).toContain('4');
    });

    it('leaves the count to the child row when the group is open', () => {
      expect(conversations(true).text()).not.toContain('4');
    });
  });
});
