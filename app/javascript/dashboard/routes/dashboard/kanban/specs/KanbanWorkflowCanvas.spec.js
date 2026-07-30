import { shallowMount } from '@vue/test-utils';

import KanbanWorkflowCanvas from '../components/KanbanWorkflowCanvas.vue';

describe('KanbanWorkflowCanvas', () => {
  it('does not enlarge a small workflow beyond its authored node scale', () => {
    const wrapper = shallowMount(KanbanWorkflowCanvas, {
      props: {
        nodes: [],
        edges: [],
        nodeTypes: {},
        edgeTypes: {},
        canvasLabel: 'Editor de automacoes',
      },
      global: {
        stubs: {
          VueFlow: {
            props: ['fitViewOptions'],
            template:
              '<div data-testid="vue-flow" :data-fit-view-max-zoom="fitViewOptions.maxZoom" />',
          },
        },
      },
    });

    expect(
      wrapper
        .find('[data-testid="vue-flow"]')
        .attributes('data-fit-view-max-zoom')
    ).toBe('1');
  });
});
