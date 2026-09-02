<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import NextButton from 'dashboard/components-next/button/Button.vue';

/**
 * Uma resposta de formulário na oportunidade.
 *
 * Existe em duas situações que parecem a mesma e não são: a resposta que se
 * pode ler, e a que se sabe existir mas não se pode abrir. Esconder a segunda
 * fazia a secretária pedir a anamnese outra vez a quem já a tinha preenchido;
 * mostrar-lhe o título — «Inquérito Pré-Consulta de Obesidade» — contava-lhe o
 * diagnóstico sem abrir uma única resposta. Por isso a linha aparece sempre, e
 * o que varia é quanto diz.
 */
const props = defineProps({
  submission: { type: Object, required: true },
  resolvingAction: { type: [Number, String, Object], default: null },
  pendingActionError: { type: String, default: '' },
});

const emit = defineEmits(['open', 'resolve']);
const { t, locale } = useI18n();

const restrita = computed(() => props.submission.restricted === true);

const titulo = computed(() =>
  restrita.value
    ? t('FORMS.SUBMISSIONS.RESTRICTED_TITLE')
    : props.submission.form_name
);

// «Vencida» leva ícone e palavra, nunca só a cor: quem não distingue vermelho
// de cinzento tem o mesmo direito a saber que a anamnese é de há três anos.
const vencida = computed(() => props.submission.answer_expired === true);

const validade = computed(() => {
  if (!props.submission.valid_until) return '';
  return new Date(props.submission.valid_until).toLocaleDateString(
    String(locale.value).replace('_', '-')
  );
});

// As chaves de tradução são em maiúsculas; o estado vem em minúsculas da API.
const ESTADOS = ['submitted', 'discarded'];
const estadoLabel = computed(() => {
  const estado = props.submission.status;
  return ESTADOS.includes(estado)
    ? t(`FORMS.SUBMISSIONS.STATUS.${estado.toUpperCase()}`)
    : estado;
});
</script>

<template>
  <article
    class="flex items-center justify-between gap-3 rounded border border-n-weak px-3 py-2"
    :data-testid="`kanban-form-submission-${submission.id}`"
  >
    <div class="min-w-0">
      <p
        class="mb-0 flex items-center gap-2 break-words text-sm font-medium text-n-slate-12"
      >
        <i
          v-if="restrita"
          class="i-lucide-lock size-3.5 shrink-0 text-n-slate-10"
          aria-hidden="true"
        />
        {{ titulo }}
      </p>
      <div class="flex flex-wrap items-center gap-2">
        <span class="text-xs text-n-slate-10">{{ estadoLabel }}</span>
        <span
          v-if="vencida"
          class="inline-flex items-center gap-1 rounded-full bg-n-amber-3 px-2 py-0.5 text-xs font-medium text-n-amber-11"
          :data-testid="`kanban-form-submission-expired-${submission.id}`"
        >
          <i class="i-lucide-clock-alert size-3" aria-hidden="true" />
          {{ t('FORMS.SUBMISSIONS.EXPIRED') }}
        </span>
        <span v-else-if="validade" class="text-xs text-n-slate-10">
          {{ t('FORMS.SUBMISSIONS.VALID_UNTIL', { date: validade }) }}
        </span>
      </div>
      <p v-if="restrita" class="mb-0 mt-1 text-xs text-n-slate-10">
        {{ t('FORMS.SUBMISSIONS.RESTRICTED_HINT') }}
      </p>

      <div
        v-for="action in submission.pending_actions || []"
        :key="action.index"
        class="mt-2 flex flex-wrap items-center gap-2 rounded border border-n-amber-6 bg-n-amber-2 px-2 py-1.5"
        :data-testid="`kanban-pending-action-${submission.id}-${action.index}`"
      >
        <span class="text-xs font-medium text-n-amber-11">
          {{ t(`FORMS.SUBMISSION_ACTIONS.KIND.${action.kind}`) }}
        </span>
        <button
          type="button"
          class="rounded px-2 py-0.5 text-xs font-semibold text-n-teal-11 transition hover:bg-n-teal-3"
          :disabled="resolvingAction !== null"
          :data-testid="`kanban-pending-confirm-${submission.id}-${action.index}`"
          @click="emit('resolve', { submission, action, decision: 'confirm' })"
        >
          {{ t('FORMS.SUBMISSION_ACTIONS.PENDING_CONFIRM') }}
        </button>
        <button
          type="button"
          class="rounded px-2 py-0.5 text-xs font-semibold text-n-slate-11 transition hover:bg-n-slate-3"
          :disabled="resolvingAction !== null"
          :data-testid="`kanban-pending-dismiss-${submission.id}-${action.index}`"
          @click="emit('resolve', { submission, action, decision: 'dismiss' })"
        >
          {{ t('FORMS.SUBMISSION_ACTIONS.PENDING_DISMISS') }}
        </button>
      </div>
      <p
        v-if="pendingActionError"
        class="mb-0 mt-2 text-xs text-n-ruby-11"
        role="alert"
      >
        {{ pendingActionError }}
      </p>
    </div>

    <NextButton
      v-if="!restrita"
      type="button"
      sm
      variant="faded"
      color="slate"
      icon="i-lucide-file-text"
      :label="t('FORMS.SUBMISSIONS.OPEN')"
      :data-testid="`kanban-opportunity-open-form-submission-${submission.id}`"
      @click="emit('open', submission)"
    />
  </article>
</template>
