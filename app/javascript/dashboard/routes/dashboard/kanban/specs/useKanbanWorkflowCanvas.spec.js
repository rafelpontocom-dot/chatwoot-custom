import { ref } from 'vue';

import { useKanbanWorkflowCanvas } from '../components/useKanbanWorkflowCanvas';

describe('useKanbanWorkflowCanvas', () => {
  it('inserts a node into a named Router output without losing its handle', () => {
    const nodes = ref([
      { id: 'router', type: 'condition' },
      { id: 'end', type: 'end' },
    ]);
    const edges = ref([
      {
        id: 'router-qualified-end',
        source: 'router',
        sourceHandle: 'qualified',
        target: 'end',
      },
    ]);
    const canvas = useKanbanWorkflowCanvas({ nodes, edges });

    canvas.insertNodeAfter({
      node: { id: 'message', type: 'send_message' },
      sourceId: 'router',
      sourceHandle: 'qualified',
    });

    expect(edges.value).toEqual([
      expect.objectContaining({
        source: 'router',
        sourceHandle: 'qualified',
        target: 'message',
      }),
      expect.objectContaining({ source: 'message', target: 'end' }),
    ]);
  });

  it('removes a node together with all of its connections', () => {
    const nodes = ref([
      { id: 'trigger', type: 'trigger' },
      { id: 'message', type: 'send_message' },
      { id: 'end', type: 'end' },
    ]);
    const edges = ref([
      { id: 'trigger-message', source: 'trigger', target: 'message' },
      { id: 'message-end', source: 'message', target: 'end' },
    ]);
    const canvas = useKanbanWorkflowCanvas({ nodes, edges });

    canvas.removeNode('message');

    expect(nodes.value.map(node => node.id)).toEqual(['trigger', 'end']);
    expect(edges.value).toEqual([]);
  });
});
