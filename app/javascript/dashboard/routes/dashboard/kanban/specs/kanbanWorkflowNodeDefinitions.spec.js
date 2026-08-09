import {
  getKanbanWorkflowNodeDefinition,
  getKanbanWorkflowPaletteGroups,
} from '../components/kanbanWorkflowNodeDefinitions';

describe('kanban workflow node definitions', () => {
  const t = key => key;

  it('keeps the Router and path distributor distinct in the decision palette', () => {
    const groups = getKanbanWorkflowPaletteGroups(t);
    const decisionGroup = groups.find(group => group.key === 'DECISION');

    expect(decisionGroup.nodes).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ type: 'condition' }),
        expect.objectContaining({ type: 'filter' }),
        expect.objectContaining({ type: 'round_robin' }),
      ])
    );
    expect(getKanbanWorkflowNodeDefinition('condition')).toEqual(
      expect.objectContaining({
        icon: 'i-lucide-git-branch',
        category: 'DECISION',
      })
    );
    expect(getKanbanWorkflowNodeDefinition('round_robin')).toEqual(
      expect.objectContaining({
        icon: 'i-lucide-waypoints',
        category: 'DECISION',
      })
    );
    expect(getKanbanWorkflowNodeDefinition('filter')).toEqual(
      expect.objectContaining({
        icon: 'i-lucide-filter',
        category: 'DECISION',
      })
    );
  });

  it('does not make the trigger or terminal node addable from the palette', () => {
    const groups = getKanbanWorkflowPaletteGroups(t);
    const paletteTypes = groups.flatMap(group =>
      group.nodes.map(node => node.type)
    );

    expect(paletteTypes).not.toContain('trigger');
    expect(paletteTypes).not.toContain('end');
  });

  it('keeps inactivity waiting distinct from waiting for a response', () => {
    const groups = getKanbanWorkflowPaletteGroups(t);
    const timeGroup = groups.find(group => group.key === 'TIME');

    expect(timeGroup.nodes).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ type: 'wait_for_response' }),
        expect.objectContaining({ type: 'wait_for_inactivity' }),
      ])
    );
    expect(getKanbanWorkflowNodeDefinition('wait_for_inactivity')).toEqual(
      expect.objectContaining({
        icon: 'i-lucide-timer-off',
        category: 'TIME',
      })
    );
  });

  it('lists a random interval wait for distributing commercial sends', () => {
    const groups = getKanbanWorkflowPaletteGroups(t);
    const timeGroup = groups.find(group => group.key === 'TIME');

    expect(timeGroup.nodes).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ type: 'random_delay' }),
      ])
    );
    expect(getKanbanWorkflowNodeDefinition('random_delay')).toEqual(
      expect.objectContaining({
        icon: 'i-lucide-shuffle',
        category: 'TIME',
      })
    );
  });

  it('lists duplicate checking as a decision with two explicit paths', () => {
    const groups = getKanbanWorkflowPaletteGroups(t);
    const decisionGroup = groups.find(group => group.key === 'DECISION');

    expect(decisionGroup.nodes).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          type: 'duplicate_check',
          icon: 'i-lucide-copy-check',
        }),
      ])
    );
  });

  it('marks a human handoff as a terminal customer node', () => {
    expect(getKanbanWorkflowNodeDefinition('human_handoff')).toEqual(
      expect.objectContaining({
        icon: 'i-lucide-user-round-check',
        category: 'CUSTOMER',
        terminal: true,
      })
    );
  });

  it('lists next-action completion as an opportunity node', () => {
    expect(getKanbanWorkflowNodeDefinition('complete_next_action')).toEqual(
      expect.objectContaining({
        icon: 'i-lucide-circle-check-big',
        category: 'OPPORTUNITY',
      })
    );
  });

  it('lists creation of a linked opportunity as a non-terminal opportunity node', () => {
    const groups = getKanbanWorkflowPaletteGroups(t);
    const opportunityGroup = groups.find(group => group.key === 'OPPORTUNITY');

    expect(opportunityGroup.nodes).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          type: 'create_opportunity',
          icon: 'i-lucide-circle-plus',
        }),
      ])
    );
    expect(getKanbanWorkflowNodeDefinition('create_opportunity')).toEqual(
      expect.objectContaining({ category: 'OPPORTUNITY', terminal: false })
    );
  });

  it('lists a concise internal audit node in the operation palette', () => {
    const groups = getKanbanWorkflowPaletteGroups(t);
    const operationGroup = groups.find(group => group.key === 'OPERATION');

    expect(operationGroup.nodes).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          type: 'audit_log',
          icon: 'i-lucide-notebook-pen',
        }),
      ])
    );
  });

  it('lists a team notification as a non-terminal operation node', () => {
    const groups = getKanbanWorkflowPaletteGroups(t);
    const operationGroup = groups.find(group => group.key === 'OPERATION');

    expect(operationGroup.nodes).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          type: 'notify_team',
          icon: 'i-lucide-bell-ring',
        }),
      ])
    );
    expect(getKanbanWorkflowNodeDefinition('notify_team')).toEqual(
      expect.objectContaining({ category: 'OPERATION', terminal: false })
    );
  });

  it('lists contact updates separately from customer messaging', () => {
    expect(getKanbanWorkflowNodeDefinition('update_contact')).toEqual(
      expect.objectContaining({
        icon: 'i-lucide-contact-round',
        category: 'CUSTOMER',
      })
    );
  });

  it('lists message eligibility as a decision node', () => {
    expect(getKanbanWorkflowNodeDefinition('message_eligibility')).toEqual(
      expect.objectContaining({
        icon: 'i-lucide-shield-check',
        category: 'DECISION',
      })
    );
  });
});
