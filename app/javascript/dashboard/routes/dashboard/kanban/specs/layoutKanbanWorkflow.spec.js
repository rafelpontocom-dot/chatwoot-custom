import { layoutKanbanWorkflow } from '../components/layoutKanbanWorkflow';

describe('layoutKanbanWorkflow', () => {
  it('places a linear workflow in ordered columns', () => {
    const nodes = [
      { id: 'trigger', type: 'trigger' },
      { id: 'wait', type: 'delay' },
      { id: 'end', type: 'end' },
    ];
    const edges = [
      { source: 'trigger', target: 'wait' },
      { source: 'wait', target: 'end' },
    ];

    const positionedNodes = layoutKanbanWorkflow(nodes, edges);

    expect(positionedNodes.map(node => node.position)).toEqual([
      { x: 48, y: 120 },
      { x: 320, y: 120 },
      { x: 592, y: 120 },
    ]);
  });

  it('stacks sibling branches in the same column', () => {
    const nodes = [
      { id: 'trigger', type: 'trigger' },
      { id: 'router', type: 'condition' },
      { id: 'qualified', type: 'send_message' },
      { id: 'otherwise', type: 'end' },
    ];
    const edges = [
      { source: 'trigger', target: 'router' },
      { source: 'router', target: 'qualified', sourceHandle: 'qualified' },
      { source: 'router', target: 'otherwise', sourceHandle: 'otherwise' },
    ];

    const positionedNodes = layoutKanbanWorkflow(nodes, edges);

    expect(
      positionedNodes.find(node => node.id === 'qualified').position
    ).toEqual({ x: 592, y: 120 });
    expect(
      positionedNodes.find(node => node.id === 'otherwise').position
    ).toEqual({ x: 592, y: 300 });
  });
});
