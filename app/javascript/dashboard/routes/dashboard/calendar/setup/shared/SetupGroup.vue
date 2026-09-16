<script setup>
// Grupo das configurações da agenda, como no mockup aprovado: caixa com borda,
// cabeçalho com título à esquerda e legenda (ou ação) à direita.
defineProps({
  title: { type: String, required: true },
  hint: { type: String, default: '' },
  // Linhas encostadas umas às outras (lista), em vez de campos com espaço.
  flush: { type: Boolean, default: false },
  tone: { type: String, default: 'surface' },
});
</script>

<template>
  <section
    class="rounded-xl border border-solid border-n-weak"
    :class="tone === 'muted' ? 'bg-n-surface-2' : 'bg-n-solid-1'"
  >
    <header
      class="flex flex-wrap items-center justify-between gap-2.5 border-b border-solid border-n-weak px-3.5 py-[11px]"
    >
      <h3 class="mb-0 text-ui font-semibold text-n-slate-12">{{ title }}</h3>
      <slot name="aside">
        <small v-if="hint" class="text-xs text-n-slate-10">{{ hint }}</small>
      </slot>
    </header>
    <div class="grid px-3.5 py-3" :class="flush ? 'gap-0' : 'gap-3'">
      <slot />
    </div>
  </section>
</template>
