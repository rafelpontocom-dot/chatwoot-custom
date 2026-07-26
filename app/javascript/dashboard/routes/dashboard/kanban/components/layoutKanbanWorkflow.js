const COLUMN_GAP = 272;
const ROW_GAP = 180;
const START_X = 48;
const START_Y = 120;

export const layoutKanbanWorkflow = (nodes, edges) => {
  const nodeIds = new Set(nodes.map(node => node.id));
  const outgoingEdges = new Map(nodes.map(node => [node.id, []]));
  const incomingCounts = new Map(nodes.map(node => [node.id, 0]));

  edges.forEach(edge => {
    if (!nodeIds.has(edge.source) || !nodeIds.has(edge.target)) return;

    outgoingEdges.get(edge.source).push(edge.target);
    incomingCounts.set(edge.target, incomingCounts.get(edge.target) + 1);
  });

  const roots = nodes.filter(node => incomingCounts.get(node.id) === 0);
  const queue = roots.map(node => node.id);
  const levels = new Map(roots.map(node => [node.id, 0]));

  while (queue.length) {
    const nodeId = queue.shift();
    const level = levels.get(nodeId);

    outgoingEdges.get(nodeId).forEach(targetId => {
      levels.set(targetId, Math.max(levels.get(targetId) ?? 0, level + 1));
      incomingCounts.set(targetId, incomingCounts.get(targetId) - 1);
      if (incomingCounts.get(targetId) === 0) queue.push(targetId);
    });
  }

  const rowsByLevel = new Map();
  return nodes.map(node => {
    const level = levels.get(node.id) ?? 0;
    const row = rowsByLevel.get(level) || 0;
    rowsByLevel.set(level, row + 1);

    return {
      ...node,
      position: {
        x: START_X + level * COLUMN_GAP,
        y: START_Y + row * ROW_GAP,
      },
    };
  });
};
