import { computed, ref } from 'vue';

export const useKanbanWorkflowHistory = (limit = 50) => {
  const previousSnapshots = ref([]);
  const nextSnapshots = ref([]);
  const canUndo = computed(() => previousSnapshots.value.length > 0);
  const canRedo = computed(() => nextSnapshots.value.length > 0);

  const record = snapshot => {
    previousSnapshots.value = [...previousSnapshots.value, snapshot].slice(
      -limit
    );
    nextSnapshots.value = [];
  };

  const undo = currentSnapshot => {
    if (!canUndo.value) return null;

    const snapshot = previousSnapshots.value.at(-1);
    previousSnapshots.value = previousSnapshots.value.slice(0, -1);
    nextSnapshots.value = [currentSnapshot, ...nextSnapshots.value];
    return snapshot;
  };

  const redo = currentSnapshot => {
    if (!canRedo.value) return null;

    const [snapshot, ...remainingSnapshots] = nextSnapshots.value;
    nextSnapshots.value = remainingSnapshots;
    previousSnapshots.value = [
      ...previousSnapshots.value,
      currentSnapshot,
    ].slice(-limit);
    return snapshot;
  };

  const reset = () => {
    previousSnapshots.value = [];
    nextSnapshots.value = [];
  };

  return { canUndo, canRedo, record, undo, redo, reset };
};
