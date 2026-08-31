<script setup>
import { computed, nextTick, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { debounce } from '@chatwoot/utils';
import camelcaseKeys from 'camelcase-keys';
import calendarAPI from 'dashboard/api/calendar';
import ContactAPI from 'dashboard/api/contacts';
import {
  RAEVO_CONTROL_CLASS,
  RAEVO_SELECT_CLASS,
} from 'dashboard/components-next/raevo/raevoControl';

/**
 * Raevo — balão de criação rápida, no formato do Google Calendar.
 *
 * Clicar num horário vazio abria o diálogo inteiro. O Google abre um balão
 * ancorado no clique, com o mínimo, e manda para "Mais opções" quem precisa do
 * resto. Aqui o mínimo é paciente e procedimento: sem eles a API não marca, e o
 * profissional é escolhido sozinho quando o procedimento só admite um.
 */
const props = defineProps({
  startsAt: { type: Date, default: null },
  procedures: { type: Array, default: () => [] },
  resources: { type: Array, default: () => [] },
  anchor: { type: Object, default: null },
});

const emit = defineEmits(['close', 'created', 'openFullDialog']);
const { t } = useI18n();

const contactQuery = ref('');
const contactResults = ref([]);
const selectedContact = ref(null);
const isSearching = ref(false);
const procedureId = ref('');
const resourceId = ref('');
const isSaving = ref(false);
const error = ref('');
const buscaInput = ref(null);

const selectedProcedure = computed(() =>
  props.procedures.find(item => String(item.id) === procedureId.value)
);

/** Recursos que o procedimento admite; se só houver um, não se pergunta. */
const allowedResources = computed(() => {
  const permitidos = selectedProcedure.value?.resource_ids || [];
  if (!permitidos.length) return props.resources;
  return props.resources.filter(item => permitidos.includes(item.id));
});

const needsResourceChoice = computed(() => allowedResources.value.length > 1);

const timeLabel = computed(() => {
  if (!props.startsAt) return '';
  const fim = new Date(props.startsAt);
  fim.setMinutes(
    fim.getMinutes() + (selectedProcedure.value?.duration_minutes || 30)
  );
  const dia = new Intl.DateTimeFormat(undefined, {
    weekday: 'long',
    day: 'numeric',
    month: 'long',
  });
  const hora = new Intl.DateTimeFormat(undefined, {
    hour: '2-digit',
    minute: '2-digit',
  });
  return `${dia.format(props.startsAt)} · ${hora.format(props.startsAt)} – ${hora.format(fim)}`;
});

const canSave = computed(
  () => !!selectedContact.value && !!procedureId.value && !isSaving.value
);

const searchContacts = async termo => {
  const alvo = termo.trim();
  if (alvo.length < 3) {
    contactResults.value = [];
    return;
  }
  isSearching.value = true;
  try {
    const { data } = await ContactAPI.search(alvo, 1, 'name', '');
    contactResults.value = camelcaseKeys(data?.payload || [], { deep: true });
  } catch {
    contactResults.value = [];
  } finally {
    isSearching.value = false;
  }
};

const debouncedSearch = debounce(searchContacts, 250, false);

const onContactInput = () => {
  selectedContact.value = null;
  debouncedSearch(contactQuery.value);
};

const pickContact = contact => {
  selectedContact.value = contact;
  contactQuery.value =
    contact.name || contact.email || contact.phoneNumber || '';
  contactResults.value = [];
};

watch(
  () => allowedResources.value,
  lista => {
    if (lista.length === 1) resourceId.value = String(lista[0].id);
  },
  { immediate: true }
);

watch(
  () => props.startsAt,
  async valor => {
    if (!valor) return;
    contactQuery.value = '';
    contactResults.value = [];
    selectedContact.value = null;
    error.value = '';
    await nextTick();
    buscaInput.value?.focus();
  },
  { immediate: true }
);

const save = async () => {
  if (!canSave.value) return;
  const alvo = resourceId.value || allowedResources.value[0]?.id;
  if (!alvo) {
    error.value = t('CALENDAR.QUICK.NO_RESOURCE');
    return;
  }

  isSaving.value = true;
  error.value = '';
  try {
    await calendarAPI.createAppointment({
      contact_id: Number(selectedContact.value.id),
      procedure_id: Number(procedureId.value),
      resource_ids: [Number(alvo)],
      starts_at: props.startsAt.toISOString(),
      timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
    });
    emit('created');
    emit('close');
  } catch (saveError) {
    error.value =
      saveError?.response?.data?.message || t('CALENDAR.QUICK.ERROR');
  } finally {
    isSaving.value = false;
  }
};

const estilo = computed(() => {
  if (!props.anchor) return {};
  return { top: `${props.anchor.top}px`, left: `${props.anchor.left}px` };
});
</script>

<template>
  <div
    v-if="startsAt"
    data-testid="calendar-quick-create"
    class="fixed z-50 w-80 rounded-xl border border-n-weak bg-n-solid-1 p-4 shadow-lg"
    :style="estilo"
    role="dialog"
    :aria-label="t('CALENDAR.QUICK.TITLE')"
    @keydown.escape.stop="emit('close')"
  >
    <div class="mb-3 flex items-start justify-between gap-2">
      <p class="mb-0 text-xs font-medium text-n-slate-11">{{ timeLabel }}</p>
      <button
        type="button"
        data-testid="calendar-quick-close"
        class="-mt-1 flex size-7 flex-shrink-0 items-center justify-center rounded-full text-n-slate-10 outline-none hover:bg-n-alpha-2 focus-visible:ring-2 focus-visible:ring-n-brand"
        :aria-label="t('GENERAL.CLOSE')"
        @click="emit('close')"
      >
        <i class="i-lucide-x size-4" aria-hidden="true" />
      </button>
    </div>

    <label class="sr-only" for="calendar-quick-contact">
      {{ t('CALENDAR.QUICK.CONTACT') }}
    </label>
    <input
      id="calendar-quick-contact"
      ref="buscaInput"
      v-model="contactQuery"
      type="search"
      data-testid="calendar-quick-contact"
      :placeholder="t('CALENDAR.QUICK.CONTACT')"
      :class="RAEVO_CONTROL_CLASS"
      @input="onContactInput"
    />
    <p v-if="isSearching" class="mb-0 mt-1 text-xs text-n-slate-10">
      {{ t('CALENDAR.QUICK.SEARCHING') }}
    </p>
    <div v-else-if="contactResults.length" class="mt-1 grid gap-0.5">
      <button
        v-for="contact in contactResults.slice(0, 4)"
        :key="contact.id"
        type="button"
        :data-testid="`calendar-quick-contact-${contact.id}`"
        class="truncate rounded-lg px-2 py-1.5 text-left text-sm text-n-slate-12 outline-none hover:bg-n-alpha-2 focus-visible:ring-2 focus-visible:ring-n-brand"
        @click="pickContact(contact)"
      >
        {{ contact.name || contact.email || contact.phoneNumber }}
      </button>
    </div>

    <label class="sr-only" for="calendar-quick-procedure">
      {{ t('CALENDAR.QUICK.PROCEDURE') }}
    </label>
    <select
      id="calendar-quick-procedure"
      v-model="procedureId"
      data-testid="calendar-quick-procedure"
      class="mt-2"
      :class="RAEVO_SELECT_CLASS"
    >
      <option value="">{{ t('CALENDAR.QUICK.PROCEDURE') }}</option>
      <option
        v-for="procedure in procedures"
        :key="procedure.id"
        :value="String(procedure.id)"
      >
        {{ procedure.name }}
      </option>
    </select>

    <select
      v-if="needsResourceChoice"
      v-model="resourceId"
      data-testid="calendar-quick-resource"
      class="mt-2"
      :class="RAEVO_SELECT_CLASS"
      :aria-label="t('CALENDAR.QUICK.RESOURCE')"
    >
      <option value="">{{ t('CALENDAR.QUICK.RESOURCE') }}</option>
      <option
        v-for="resource in allowedResources"
        :key="resource.id"
        :value="String(resource.id)"
      >
        {{ resource.name }}
      </option>
    </select>

    <p v-if="error" class="mb-0 mt-2 text-xs text-n-ruby-11" role="alert">
      {{ error }}
    </p>

    <div class="mt-3 flex items-center justify-end gap-2">
      <button
        type="button"
        data-testid="calendar-quick-more"
        class="rounded-full px-3 py-2 text-sm font-medium text-n-brand outline-none hover:bg-n-blue-3 focus-visible:ring-2 focus-visible:ring-n-brand"
        @click="emit('openFullDialog')"
      >
        {{ t('CALENDAR.QUICK.MORE_OPTIONS') }}
      </button>
      <button
        type="button"
        data-testid="calendar-quick-save"
        class="rounded-full bg-n-brand px-4 py-2 text-sm font-semibold text-white outline-none hover:bg-n-blue-10 focus-visible:ring-2 focus-visible:ring-n-brand disabled:cursor-not-allowed disabled:opacity-50"
        :disabled="!canSave"
        @click="save"
      >
        {{ t('CALENDAR.QUICK.SAVE') }}
      </button>
    </div>
  </div>
</template>
