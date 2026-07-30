<script setup>
import { Background } from '@vue-flow/background';
import { Controls } from '@vue-flow/controls';
import { MiniMap } from '@vue-flow/minimap';
import { VueFlow } from '@vue-flow/core';

import '@vue-flow/controls/dist/style.css';
import '@vue-flow/core/dist/style.css';
import '@vue-flow/minimap/dist/style.css';

defineProps({
  nodes: { type: Array, required: true },
  edges: { type: Array, required: true },
  nodeTypes: { type: Object, required: true },
  edgeTypes: { type: Object, required: true },
  canvasLabel: { type: String, required: true },
  showMiniMap: { type: Boolean, default: false },
});

const emit = defineEmits([
  'update:nodes',
  'update:edges',
  'connect',
  'node-drag-start',
  'edge-click',
  'node-click',
  'drop',
]);
</script>

<template>
  <div
    data-testid="kanban-workflow-canvas"
    role="region"
    class="relative h-full min-h-[42rem] flex-1"
    :aria-label="canvasLabel"
  >
    <slot name="toolbar" />
    <slot name="mobile-palette" />
    <div
      class="h-full min-h-[42rem] overflow-hidden bg-n-surface-2"
      @dragover.prevent
      @drop="emit('drop', $event)"
    >
      <VueFlow
        :nodes="nodes"
        :edges="edges"
        :node-types="nodeTypes"
        :edge-types="edgeTypes"
        :min-zoom="0.4"
        :max-zoom="1.8"
        :fit-view-options="{ maxZoom: 1 }"
        class="bg-n-surface-2"
        fit-view-on-init
        @update:nodes="emit('update:nodes', $event)"
        @update:edges="emit('update:edges', $event)"
        @connect="emit('connect', $event)"
        @node-drag-start="emit('node-drag-start', $event)"
        @edge-click="emit('edge-click', $event)"
        @node-click="emit('node-click', $event)"
      >
        <Background pattern-color="var(--color-n-slate-5)" :gap="16" />
        <Controls :show-interactive="false" />
        <MiniMap
          v-if="showMiniMap"
          data-testid="kanban-workflow-minimap"
          pannable
          zoomable
        />
      </VueFlow>
    </div>
    <slot />
  </div>
</template>
