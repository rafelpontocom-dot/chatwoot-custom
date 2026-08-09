<script setup>
defineProps({
  t: { type: Function, required: true },
});
</script>

<template>
  <section class="grid gap-3">
    <div class="rounded-lg border border-n-weak bg-n-surface-2 p-3">
      <p class="m-0 text-sm font-semibold text-n-slate-12">
        {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODES.DUPLICATE_CHECK') }}
      </p>
      <p class="m-0 mt-1 text-xs text-n-slate-11">
        {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.DUPLICATE_CHECK_HINT') }}
      </p>
    </div>
    <div
      class="grid gap-2 rounded-md border border-n-weak bg-n-surface-2 p-3 text-xs text-n-slate-11"
    >
      <p class="m-0">
        {{
          t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.DUPLICATE_CHECK_DUPLICATE')
        }}
      </p>
      <p class="m-0">
        {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.DUPLICATE_CHECK_UNIQUE') }}
      </p>
    </div>
  </section>
</template>
