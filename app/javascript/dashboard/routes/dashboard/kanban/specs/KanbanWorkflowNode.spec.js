import { shallowMount } from '@vue/test-utils';

import KanbanWorkflowNode from '../components/KanbanWorkflowNode.vue';

describe('KanbanWorkflowNode', () => {
  it('keeps the commercial node compact and stable on the canvas', () => {
    const wrapper = shallowMount(KanbanWorkflowNode, {
      props: {
        data: {
          id: 'message',
          kind: 'send_message',
          category: 'CUSTOMER',
          categoryLabel: 'Cliente',
          label: 'Enviar mensagem',
          state: 'draft',
          stateLabel: 'Rascunho',
        },
      },
    });

    expect(
      wrapper.find('[data-testid="kanban-workflow-node-card"]').classes()
    ).toContain('w-[9.5rem]');
    expect(
      wrapper.find('[data-testid="kanban-workflow-node-card"]').classes()
    ).toContain('py-2');
    expect(
      wrapper.find('[data-testid="kanban-workflow-node-card"]').classes()
    ).toContain('border-t-4');
  });
});
