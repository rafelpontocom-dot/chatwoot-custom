import { mount } from '@vue/test-utils';
import { defineComponent, nextTick, ref } from 'vue';
import { useUnreadTabTitle } from '../useUnreadTabTitle';

const unreadCount = ref(0);

vi.mock('dashboard/composables/store', () => ({
  useMapGetter: () => unreadCount,
}));

const Host = defineComponent({
  setup() {
    useUnreadTabTitle();
  },
  template: '<div />',
});

describe('useUnreadTabTitle', () => {
  let wrapper;

  beforeEach(() => {
    document.title = 'RAEVO CRM';
    unreadCount.value = 0;
  });

  afterEach(() => wrapper?.unmount());

  it('updates the count and restores the title when there are no unread conversations', async () => {
    wrapper = mount(Host);
    expect(document.title).toBe('RAEVO CRM');

    unreadCount.value = 3;
    await nextTick();
    expect(document.title).toBe('(3) RAEVO CRM');

    unreadCount.value = 0;
    await nextTick();
    expect(document.title).toBe('RAEVO CRM');
  });

  it('caps the displayed count', () => {
    unreadCount.value = 100;
    wrapper = mount(Host);

    expect(document.title).toBe('(99+) RAEVO CRM');
  });

  it('restores the original title when leaving the dashboard', () => {
    unreadCount.value = 7;
    wrapper = mount(Host);
    wrapper.unmount();

    expect(document.title).toBe('RAEVO CRM');
  });

  it('does not accumulate count prefixes when reentering the dashboard', () => {
    unreadCount.value = 3;
    wrapper = mount(Host);
    wrapper.unmount();

    unreadCount.value = 5;
    wrapper = mount(Host);

    expect(document.title).toBe('(5) RAEVO CRM');
  });
});
