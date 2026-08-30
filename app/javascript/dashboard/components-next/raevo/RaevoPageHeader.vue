<script setup>
/**
 * Raevo · Sereno — cabeçalho de página.
 *
 * No Sereno o título NÃO mora na barra do topo: mora num card branco dentro do
 * corpo, com rótulo minúsculo acima, selo ao lado e a linha de filtros embaixo.
 * Este componente é esse padrão. Use em toda tela nova.
 *
 * Ver docs/raevo-design-system.md §5.
 */
defineProps({
  /** Rótulo minúsculo em caixa alta acima do título. */
  eyebrow: { type: String, default: '' },
  title: { type: String, required: true },
  /** Selo azul ao lado do título — uma contagem, um período. */
  badge: { type: String, default: '' },
  subtitle: { type: String, default: '' },
});
</script>

<template>
  <header
    class="flex flex-col gap-3.5 rounded-xl border border-n-weak bg-n-solid-1 p-4"
  >
    <div class="flex items-start gap-3.5">
      <div class="min-w-0">
        <span
          v-if="eyebrow"
          class="mb-1.5 block text-[9px] font-bold uppercase tracking-[0.16em] text-n-slate-10"
        >
          {{ eyebrow }}
        </span>
        <h1
          class="flex items-center gap-2.5 text-lg font-extrabold tracking-tight text-n-slate-12"
        >
          {{ title }}
          <span
            v-if="badge"
            class="rounded-full bg-n-blue-3 px-2.5 py-0.5 text-[10px] font-bold text-n-blue-11"
          >
            {{ badge }}
          </span>
        </h1>
        <p v-if="subtitle" class="mt-1 text-xs text-n-slate-10">
          {{ subtitle }}
        </p>
      </div>
      <div v-if="$slots.actions" class="ms-auto flex shrink-0 gap-2">
        <slot name="actions" />
      </div>
    </div>

    <div v-if="$slots.filters" class="flex flex-wrap items-center gap-2">
      <slot name="filters" />
    </div>

    <div v-if="$slots.tabs" class="flex items-center gap-4">
      <slot name="tabs" />
    </div>
  </header>
</template>
