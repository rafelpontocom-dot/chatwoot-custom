import { mount } from '@vue/test-utils';
import { ref } from 'vue';
import SidebarGroup from '../SidebarGroup.vue';

const mockPush = vi.fn();
const mockSetExpandedItem = vi.fn();
const expandedItem = ref(null);

vi.mock('../provider', () => ({
  useSidebarContext: () => ({
    expandedItem,
    setExpandedItem: mockSetExpandedItem,
    resolvePath: to => to.path || '',
    resolvePermissions: () => [],
    resolveFeatureFlag: () => '',
    isAllowed: () => true,
    isCollapsed: ref(false),
    isResizing: ref(false),
  }),
  usePopoverState: () => ({
    activePopover: ref(null),
    setActivePopover: vi.fn(),
    closeActivePopover: vi.fn(),
    scheduleClose: vi.fn(),
    cancelClose: vi.fn(),
  }),
}));

vi.mock('vue-router', () => ({
  useRoute: () => ({ name: 'raevo_home', path: '/home', params: {} }),
  useRouter: () => ({ push: mockPush }),
}));

const mountGroup = props =>
  mount(SidebarGroup, {
    props: {
      name: 'Pipeline',
      label: 'Pipeline',
      icon: 'i-lucide-columns-3',
      children: [
        { name: 'Pipeline 7', label: 'RAEVO', to: { path: '/kanban/7' } },
      ],
      ...props,
    },
    global: {
      stubs: {
        Policy: { template: '<li><slot /></li>' },
        SidebarGroupHeader: {
          template:
            '<button type="button" @click="$emit(\'toggle\')">toggle</button>',
        },
        SidebarGroupLeaf: true,
      },
    },
  });

describe('SidebarGroup', () => {
  beforeEach(() => {
    mockPush.mockClear();
    mockSetExpandedItem.mockClear();
    expandedItem.value = null;
  });

  it('expands Pipeline without redirecting to the first board', async () => {
    const wrapper = mountGroup({ navigateOnExpand: false });

    await wrapper.get('button').trigger('click');

    expect(mockSetExpandedItem).toHaveBeenCalledWith('Pipeline');
    expect(mockPush).not.toHaveBeenCalled();
  });
});
