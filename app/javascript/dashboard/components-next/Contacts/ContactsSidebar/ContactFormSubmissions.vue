<script setup>
/**
 * A série de respostas da pessoa.
 *
 * A resposta pertence ao contacto; o envio pertence à oportunidade. O conteúdo
 * é histórico da pessoa e sobrevive ao card: uma paciente que volta dois anos
 * depois mantém a trilha. Por isso o card mostra apenas o envio daquele
 * atendimento, e é aqui que a série completa aparece.
 *
 * Nunca se sobrescreve: cada preenchimento é uma linha nova, datada.
 */
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';

import FormsAPI from 'dashboard/api/forms';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const props = defineProps({
  contactId: {
    type: [Number, String],
    required: true,
  },
});

const emit = defineEmits(['openSubmission']);

const { t } = useI18n();

const submissions = ref([]);
const isLoading = ref(false);
const hasError = ref(false);
const abortController = ref(null);
const requestId = ref(0);

const hasSubmissions = computed(() => submissions.value.length > 0);

const isAbortError = error =>
  error?.name === 'AbortError' || error?.name === 'CanceledError';

const abortCurrentRequest = () => {
  abortController.value?.abort();
  abortController.value = null;
};

const formatSubmittedAt = value => {
  if (!value) return '';

  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return String(value);

  return new Intl.DateTimeFormat(undefined, {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(date);
};

const loadSubmissions = async () => {
  if (!props.contactId) return;

  abortCurrentRequest();
  const currentRequestId = requestId.value + 1;
  requestId.value = currentRequestId;
  abortController.value = new AbortController();
  isLoading.value = true;
  hasError.value = false;

  try {
    const { data } = await FormsAPI.getSubmissions(
      { contact_id: props.contactId },
      { signal: abortController.value.signal }
    );

    if (currentRequestId !== requestId.value) return;

    submissions.value = data || [];
  } catch (error) {
    if (isAbortError(error) || currentRequestId !== requestId.value) return;

    hasError.value = true;
    submissions.value = [];
  } finally {
    if (currentRequestId === requestId.value) {
      isLoading.value = false;
      abortController.value = null;
    }
  }
};

watch(() => props.contactId, loadSubmissions);

onMounted(loadSubmissions);

onBeforeUnmount(() => {
  abortCurrentRequest();
  requestId.value += 1;
});
</script>

<template>
  <div
    v-if="isLoading"
    role="status"
    class="flex items-center justify-center py-10 text-n-slate-11"
  >
    <Spinner />
    <span class="sr-only">{{ t('KANBAN.OPPORTUNITY_DETAILS.LOADING') }}</span>
  </div>
  <p
    v-else-if="hasError"
    class="px-6 py-10 text-sm leading-6 text-center text-n-ruby-11"
    role="alert"
  >
    {{ t('CONTACTS_LAYOUT.SIDEBAR.FORMS.ERROR') }}
  </p>
  <ol v-else-if="hasSubmissions" class="mb-0 list-none px-6 py-2">
    <li
      v-for="submission in submissions"
      :key="submission.id"
      class="border-b border-n-weak py-4 last:border-b-0"
      data-testid="contact-form-submission"
    >
      <h3 class="mb-0 text-sm font-medium">
        <button
          type="button"
          class="reset-base w-full cursor-pointer break-words text-left text-n-slate-12 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-teal-6"
          @click="emit('openSubmission', submission.id)"
        >
          {{ submission.form_name }}
        </button>
      </h3>
      <p class="mt-1 mb-0 text-xs text-n-slate-11">
        <time :datetime="submission.submitted_at">
          {{ formatSubmittedAt(submission.submitted_at) }}
        </time>
      </p>
      <p
        v-if="submission.opportunity"
        class="mt-1 mb-0 break-words text-xs text-n-slate-11"
      >
        {{ t('CONTACTS_LAYOUT.SIDEBAR.FORMS.OPPORTUNITY') }}
        {{ submission.opportunity.subject }}
      </p>
    </li>
  </ol>
  <p v-else class="px-6 py-10 text-sm leading-6 text-center text-n-slate-11">
    {{ t('CONTACTS_LAYOUT.SIDEBAR.FORMS.EMPTY_STATE') }}
  </p>
</template>
