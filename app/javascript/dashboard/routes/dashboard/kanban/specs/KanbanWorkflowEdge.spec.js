import { shallowMount } from '@vue/test-utils';

import KanbanWorkflowEdge from '../components/KanbanWorkflowEdge.vue';

describe('KanbanWorkflowEdge', () => {
  it('shows the named Router output and inserts the next node on that output', async () => {
    const addAfterOption = vi.fn();
    const wrapper = shallowMount(KanbanWorkflowEdge, {
      global: {
        stubs: {
          EdgeLabelRenderer: { template: '<div><slot /></div>' },
        },
      },
      props: {
        id: 'router-qualified-message',
        source: 'router',
        target: 'message',
        sourceHandleId: 'qualified',
        sourceX: 200,
        sourceY: 120,
        targetX: 420,
        targetY: 120,
        sourcePosition: 'right',
        targetPosition: 'left',
        markerEnd: '',
        sourceNode: {
          data: {
            kind: 'condition',
            branches: [{ id: 'qualified', label: 'Qualificado' }],
            addAfterOption,
          },
        },
      },
    });

    expect(wrapper.text()).toContain('Qualificado');

    await wrapper
      .find('[data-testid="kanban-workflow-edge-insert"]')
      .trigger('click');

    expect(addAfterOption).toHaveBeenCalledWith('router', 'qualified');
  });

  it.each([
    ['send_message', 'failed', 'Não enviada'],
    ['wait_until_field', 'failed', 'Data indisponível'],
  ])('shows the %s outcome label on a routed edge', (kind, handle, label) => {
    const wrapper = shallowMount(KanbanWorkflowEdge, {
      global: {
        stubs: {
          EdgeLabelRenderer: { template: '<div><slot /></div>' },
        },
      },
      props: {
        id: `${kind}-${handle}`,
        source: kind,
        target: 'end',
        sourceHandleId: handle,
        sourceX: 200,
        sourceY: 120,
        targetX: 420,
        targetY: 120,
        sourcePosition: 'right',
        targetPosition: 'left',
        markerEnd: '',
        sourceNode: {
          data: {
            kind,
            outputs: [{ id: handle, label }],
          },
        },
      },
    });

    expect(wrapper.text()).toContain(label);
  });

  it('removes a connection through an accessible edge action', async () => {
    const remove = vi.fn();
    const wrapper = shallowMount(KanbanWorkflowEdge, {
      global: {
        stubs: {
          EdgeLabelRenderer: { template: '<div><slot /></div>' },
        },
      },
      props: {
        id: 'trigger-end',
        source: 'trigger',
        target: 'end',
        sourceX: 100,
        sourceY: 100,
        targetX: 300,
        targetY: 100,
        sourcePosition: 'right',
        targetPosition: 'left',
        markerEnd: '',
        data: { remove, removeLabel: 'Remover conexão' },
      },
    });

    await wrapper
      .find('[data-testid="kanban-workflow-edge-remove"]')
      .trigger('click');

    expect(remove).toHaveBeenCalledOnce();
  });

  it('highlights the connection selected by an execution route', () => {
    const wrapper = shallowMount(KanbanWorkflowEdge, {
      global: {
        stubs: {
          EdgeLabelRenderer: { template: '<div><slot /></div>' },
        },
      },
      props: {
        id: 'router-qualified-message',
        source: 'router',
        target: 'message',
        sourceHandleId: 'qualified',
        sourceX: 200,
        sourceY: 120,
        targetX: 420,
        targetY: 120,
        sourcePosition: 'right',
        targetPosition: 'left',
        markerEnd: '',
        data: { active: true },
      },
    });

    expect(wrapper.findComponent({ name: 'BaseEdge' }).classes()).toContain(
      'stroke-n-brand'
    );
  });
});
