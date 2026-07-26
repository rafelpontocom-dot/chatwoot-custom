const edgeId = ({ source, sourceHandle, target }) =>
  `${source}-${sourceHandle || 'default'}-${target}`;

export const useKanbanWorkflowCanvas = ({ nodes, edges }) => {
  const connectNodes = connection => {
    const edge = { ...connection, id: edgeId(connection) };
    if (edges.value.some(item => item.id === edge.id)) return;

    edges.value = [...edges.value, edge];
  };

  const insertNodeAfter = ({ node, sourceId, sourceHandle = null }) => {
    if (!sourceId) return;

    const sourceEdge = edges.value.find(
      edge =>
        edge.source === sourceId &&
        (sourceHandle ? edge.sourceHandle === sourceHandle : !edge.sourceHandle)
    );
    const sourceConnection = {
      source: sourceId,
      sourceHandle: sourceHandle || undefined,
      target: node.id,
    };

    if (!sourceEdge) {
      connectNodes(sourceConnection);
      return;
    }

    edges.value = edges.value.filter(edge => edge.id !== sourceEdge.id);
    connectNodes(sourceConnection);
    connectNodes({
      source: node.id,
      target: sourceEdge.target,
      targetHandle: sourceEdge.targetHandle,
    });
  };

  const removeEdge = edgeIdToRemove => {
    edges.value = edges.value.filter(edge => edge.id !== edgeIdToRemove);
  };

  const removeNode = nodeId => {
    nodes.value = nodes.value.filter(node => node.id !== nodeId);
    edges.value = edges.value.filter(
      edge => edge.source !== nodeId && edge.target !== nodeId
    );
  };

  return { connectNodes, insertNodeAfter, removeEdge, removeNode };
};
