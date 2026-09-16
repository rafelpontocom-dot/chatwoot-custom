<script setup>
// Cabeçalho do painel: título de 17px e legenda à esquerda, ações à direita,
// quebrando para baixo quando não cabe.
defineProps({
  title: { type: String, required: true },
  description: { type: String, default: '' },
});
</script>

<template>
  <div class="flex flex-wrap items-start justify-between gap-3">
    <div class="grid min-w-0 gap-[3px]">
      <slot name="before" />
      <h2 class="mb-0 text-lg font-semibold tracking-tight text-n-slate-12">
        {{ title }}
      </h2>
      <p v-if="description" class="mb-0 text-ui text-n-slate-10">
        {{ description }}
      </p>
    </div>
    <div class="flex flex-wrap items-center gap-2">
      <slot />
    </div>
  </div>
</template>
