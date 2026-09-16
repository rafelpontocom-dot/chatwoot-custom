<script setup>
// Linha de lista: nome e legenda à esquerda, ação ou selo à direita; separador
// entre linhas e nenhum depois da última.
defineProps({
  title: { type: String, required: true },
  hint: { type: String, default: '' },
  clickable: { type: Boolean, default: false },
});

defineEmits(['select']);
</script>

<template>
  <div
    class="flex flex-wrap items-center justify-between gap-3 border-b border-solid border-n-weak py-2.5 last:border-b-0"
  >
    <button
      v-if="clickable"
      type="button"
      class="grid min-w-0 flex-1 gap-0.5 rounded-md p-0 text-left outline-none focus-visible:ring-2 focus-visible:ring-n-brand/40"
      @click="$emit('select')"
    >
      <strong class="text-ui font-semibold text-n-slate-12 hover:text-n-brand">
        {{ title }}
      </strong>
      <small v-if="hint" class="text-xs text-n-slate-10">{{ hint }}</small>
    </button>
    <span v-else class="grid min-w-0 gap-0.5">
      <strong class="text-ui font-semibold text-n-slate-12">{{ title }}</strong>
      <small v-if="hint" class="text-xs text-n-slate-10">{{ hint }}</small>
    </span>
    <span class="flex flex-wrap items-center gap-1.5">
      <slot />
    </span>
  </div>
</template>
