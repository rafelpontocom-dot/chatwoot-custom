import { useKanbanWorkflowHistory } from '../components/useKanbanWorkflowHistory';

describe('useKanbanWorkflowHistory', () => {
  it('restores the previous canvas snapshot and makes the reverted snapshot redoable', () => {
    const history = useKanbanWorkflowHistory();
    const initial = { nodes: [{ id: 'trigger' }], edges: [] };
    const changed = {
      nodes: [{ id: 'trigger' }, { id: 'message' }],
      edges: [{ source: 'trigger', target: 'message' }],
    };

    history.record(initial);

    expect(history.canUndo.value).toBe(true);
    expect(history.undo(changed)).toEqual(initial);
    expect(history.canRedo.value).toBe(true);
    expect(history.redo(initial)).toEqual(changed);
  });

  it('clears redo snapshots when a new canvas change is recorded', () => {
    const history = useKanbanWorkflowHistory();
    const initial = { nodes: [{ id: 'trigger' }], edges: [] };
    const changed = { nodes: [{ id: 'message' }], edges: [] };

    history.record(initial);
    history.undo(changed);
    history.record({ nodes: [{ id: 'wait' }], edges: [] });

    expect(history.canRedo.value).toBe(false);
  });
});
