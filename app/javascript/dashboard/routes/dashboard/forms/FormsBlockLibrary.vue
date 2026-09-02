<script setup>
/**
 * A biblioteca do construtor: perguntas, conteúdo e blocos guardados.
 *
 * É a única porta para escolher o que se acrescenta ao formulário. Havia três
 * diálogos a oferecer exatamente as mesmas ações em paralelo — e duas portas
 * para a mesma coisa divergem sozinhas. Aqui a busca filtra as três secções ao
 * mesmo tempo, que é como quem monta o formulário procura: pelo nome do que
 * quer, sem saber em que categoria mora.
 */
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';

defineProps({
  fieldTypes: { type: Array, default: () => [] },
  contentBlockTypes: { type: Array, default: () => [] },
  fieldGroupOptions: { type: Array, default: () => [] },
  customFieldGroups: { type: Array, default: () => [] },
});

const emit = defineEmits([
  'addField',
  'addContent',
  'addGroup',
  'addSavedGroup',
  'deleteSavedGroup',
]);

defineOptions({
  name: 'FormsBlockLibrary',
});

const { t } = useI18n();

const query = ref('');
const detailsRef = ref(null);

const matches = label => {
  const termo = query.value.trim().toLocaleLowerCase();
  if (!termo) return true;

  return String(label).toLocaleLowerCase().includes(termo);
};

/**
 * Chamado quando alguém carrega no «+» de uma secção: abre a biblioteca e leva
 * o foco à busca, em vez de abrir um diálogo por cima do formulário.
 */
const focusSearch = () => {
  if (detailsRef.value) detailsRef.value.open = true;
  document.getElementById('forms-builder-library-search')?.focus();
};

defineExpose({ focusSearch });
</script>

<template>
  <details
    ref="detailsRef"
    class="group mt-3 rounded border border-n-slate-4 bg-n-solid-1"
    open
  >
    <summary
      class="flex min-h-9 cursor-pointer list-none items-center justify-between gap-2 px-2 text-xs font-semibold text-n-slate-11 outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-n-teal-6 [&::-webkit-details-marker]:hidden"
    >
      <span>{{ t('FORMS.BUILDER.LIBRARY') }}</span>
      <span
        class="i-lucide-chevron-down size-3.5 text-n-slate-9 transition group-open:rotate-180"
        aria-hidden="true"
      />
    </summary>
    <div class="border-t border-n-slate-4 p-2">
      <label class="sr-only" for="forms-builder-library-search">
        {{ t('FORMS.BUILDER.SEARCH_LIBRARY') }}
      </label>
      <div class="relative">
        <span
          class="i-lucide-search pointer-events-none absolute left-2.5 top-1/2 size-3.5 -translate-y-1/2 text-n-slate-9"
          aria-hidden="true"
        />
        <input
          id="forms-builder-library-search"
          v-model="query"
          data-test="forms-builder-library-search"
          :placeholder="t('FORMS.BUILDER.SEARCH_LIBRARY')"
          class="min-h-9 w-full rounded border border-n-slate-5 bg-n-solid-1 pl-8 pr-2 text-xs text-n-slate-12 outline-none placeholder:text-n-slate-9 focus:border-n-teal-9 focus:ring-2 focus:ring-n-teal-6"
        />
      </div>
      <div class="mt-3 grid gap-3">
        <section>
          <p
            class="px-1 text-micro font-semibold uppercase tracking-wide text-n-slate-9"
          >
            {{ t('FORMS.BUILDER.QUESTIONS') }}
          </p>
          <div class="mt-1 grid gap-0.5">
            <button
              v-for="type in fieldTypes.filter(item => matches(item.label))"
              :key="type.value"
              type="button"
              class="flex min-h-8 w-full items-center gap-2 rounded px-2 text-left text-xs font-medium text-n-slate-11 transition hover:bg-n-slate-3 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-teal-6"
              :data-test="`forms-builder-library-field-${type.value}`"
              @click="emit('addField', type.value)"
            >
              <span
                class="i-lucide-circle-plus size-3.5 text-n-teal-10"
                aria-hidden="true"
              />
              {{ type.label }}
            </button>
          </div>
        </section>
        <section>
          <p
            class="px-1 text-micro font-semibold uppercase tracking-wide text-n-slate-9"
          >
            {{ t('FORMS.BUILDER.CONTENT') }}
          </p>
          <div class="mt-1 grid gap-0.5">
            <button
              v-for="block in contentBlockTypes.filter(item =>
                matches(item.label)
              )"
              :key="block.value"
              type="button"
              class="flex min-h-8 w-full items-center gap-2 rounded px-2 text-left text-xs font-medium text-n-slate-11 transition hover:bg-n-slate-3 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-teal-6"
              :data-test="`forms-builder-library-content-${block.value}`"
              @click="emit('addContent', block.value)"
            >
              <span
                :class="block.icon"
                class="size-3.5 text-n-teal-10"
                aria-hidden="true"
              />
              {{ block.label }}
            </button>
          </div>
        </section>
        <section>
          <p
            class="px-1 text-micro font-semibold uppercase tracking-wide text-n-slate-9"
          >
            {{ t('FORMS.BUILDER.SAVED_BLOCKS') }}
          </p>
          <div class="mt-1 grid gap-0.5">
            <button
              v-for="group in fieldGroupOptions.filter(item =>
                matches(item.title)
              )"
              :key="group.id"
              type="button"
              class="flex min-h-8 w-full items-center gap-2 rounded px-2 text-left text-xs font-medium text-n-slate-11 transition hover:bg-n-slate-3 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-teal-6"
              :data-test="`forms-builder-library-group-${group.id}`"
              @click="emit('addGroup', group.id)"
            >
              <span
                class="i-lucide-layout-template size-3.5 shrink-0 text-n-teal-10"
                aria-hidden="true"
              />
              <span class="min-w-0 break-words">
                {{ group.title }}
              </span>
            </button>
            <div
              v-for="group in customFieldGroups.filter(item =>
                matches(item.name)
              )"
              :key="group.id"
              class="flex min-h-8 items-center gap-1 rounded pr-1 hover:bg-n-slate-3"
            >
              <button
                type="button"
                class="flex min-h-8 min-w-0 flex-1 items-center gap-2 rounded px-2 text-left text-xs font-medium text-n-slate-11 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-teal-6"
                :data-test="`forms-builder-library-saved-${group.id}`"
                @click="emit('addSavedGroup', group)"
              >
                <span
                  class="i-lucide-bookmark size-3.5 shrink-0 text-n-teal-10"
                  aria-hidden="true"
                />
                <span class="min-w-0 break-words">
                  {{ group.name }}
                </span>
              </button>
              <button
                type="button"
                class="inline-flex p-0 size-6 shrink-0 items-center justify-center rounded text-n-slate-10 transition hover:bg-n-ruby-2 hover:text-n-ruby-11 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-ruby-6"
                :aria-label="
                  t('FORMS.FIELD_GROUPS.DELETE', {
                    name: group.name,
                  })
                "
                :title="t('FORMS.ACTIONS.REMOVE')"
                @click="emit('deleteSavedGroup', group)"
              >
                <span class="i-lucide-trash-2 size-3.5" aria-hidden="true" />
              </button>
            </div>
          </div>
        </section>
      </div>
    </div>
  </details>
</template>
