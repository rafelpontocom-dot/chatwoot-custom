<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

/**
 * O que acontece quando uma resposta chega.
 *
 * Escreve `schema.submission_actions`, na forma que o
 * `Forms::SubmissionActionsValidator` aceita. A lista de tipos é curta e
 * fechada de propósito: não é um construtor de fluxos.
 *
 * O modo é a decisão que interessa. Mover uma oportunidade sozinha pode ser o
 * que a clínica quer, ou uma surpresa no meio de uma negociação — por isso a
 * escolha é por ação, e não uma preferência global.
 */
const props = defineProps({
  actions: { type: Array, default: () => [] },
  stages: { type: Array, default: () => [] },
  isSensitiveHealth: { type: Boolean, default: false },
});

const emit = defineEmits(['update']);
const KINDS = ['move_stage', 'apply_label', 'notify', 'webhook'];
const MODES = ['automatic', 'review'];
// Ninguém confirma uma chamada HTTP em nome de outro sistema.
const ALWAYS_AUTOMATIC = ['webhook'];

const { t } = useI18n();

const modesFor = kind =>
  ALWAYS_AUTOMATIC.includes(kind) ? ['automatic'] : MODES;

const controlClass =
  'reset-base mb-0 min-h-9 w-full rounded border border-solid border-n-slate-5 bg-n-solid-1 px-2.5 text-sm text-n-slate-12 outline-none focus:border-n-teal-7';

const escrever = actions => emit('update', actions);

const adicionar = () => {
  escrever([
    ...props.actions,
    {
      kind: 'move_stage',
      mode: 'automatic',
      kanban_stage_id: props.stages[0]?.id,
    },
  ]);
};

const remover = index =>
  escrever(props.actions.filter((_, posicao) => posicao !== index));

const alterar = (index, patch) =>
  escrever(
    props.actions.map((action, posicao) =>
      posicao === index ? { ...action, ...patch } : action
    )
  );

/** Trocar o tipo leva consigo os campos do tipo anterior, que não servem. */
const trocarTipo = (index, kind) => {
  const base = { kind, mode: modesFor(kind)[0] };
  if (kind === 'move_stage') base.kanban_stage_id = props.stages[0]?.id;
  if (kind === 'apply_label') base.label = '';
  if (kind === 'webhook') base.url = '';
  escrever(
    props.actions.map((action, posicao) => (posicao === index ? base : action))
  );
};

const podeConfigurar = computed(() => !props.isSensitiveHealth);
</script>

<template>
  <section class="grid gap-2" data-test="forms-submission-actions">
    <div>
      <h4 class="text-sm font-semibold text-n-slate-12">
        {{ t('FORMS.SUBMISSION_ACTIONS.TITLE') }}
      </h4>
      <p class="mt-1 text-sm leading-6 text-n-slate-10">
        {{ t('FORMS.SUBMISSION_ACTIONS.HELP') }}
      </p>
    </div>

    <p
      v-if="!podeConfigurar"
      class="mb-0 rounded border border-n-amber-6 bg-n-amber-2 px-3 py-2 text-sm text-n-amber-11"
      data-test="forms-actions-clinical-notice"
    >
      {{ t('FORMS.SUBMISSION_ACTIONS.CLINICAL') }}
    </p>

    <template v-else>
      <div
        v-for="(action, index) in actions"
        :key="index"
        class="grid gap-2 rounded border border-n-slate-4 bg-n-solid-2 p-3 md:grid-cols-2"
        data-test="forms-submission-action"
      >
        <select
          :class="controlClass"
          :value="action.kind"
          data-test="forms-action-kind"
          @change="trocarTipo(index, $event.target.value)"
        >
          <option v-for="kind in KINDS" :key="kind" :value="kind">
            {{ t(`FORMS.SUBMISSION_ACTIONS.KIND.${kind}`) }}
          </option>
        </select>

        <select
          :class="controlClass"
          :value="action.mode"
          :disabled="modesFor(action.kind).length === 1"
          data-test="forms-action-mode"
          @change="alterar(index, { mode: $event.target.value })"
        >
          <option
            v-for="mode in modesFor(action.kind)"
            :key="mode"
            :value="mode"
          >
            {{ t(`FORMS.SUBMISSION_ACTIONS.MODE.${mode}`) }}
          </option>
        </select>

        <label
          v-if="action.kind === 'move_stage'"
          class="grid gap-1.5 text-sm font-medium text-n-slate-11 md:col-span-2"
        >
          {{ t('FORMS.SUBMISSION_ACTIONS.STAGE') }}
          <select
            :class="controlClass"
            :value="action.kanban_stage_id"
            data-test="forms-action-stage"
            @change="
              alterar(index, { kanban_stage_id: Number($event.target.value) })
            "
          >
            <option v-for="stage in stages" :key="stage.id" :value="stage.id">
              {{ stage.name }}
            </option>
          </select>
        </label>

        <label
          v-else-if="action.kind === 'apply_label'"
          class="grid gap-1.5 text-sm font-medium text-n-slate-11 md:col-span-2"
        >
          {{ t('FORMS.SUBMISSION_ACTIONS.LABEL') }}
          <input
            :class="controlClass"
            :value="action.label"
            type="text"
            data-test="forms-action-label"
            @input="alterar(index, { label: $event.target.value })"
          />
        </label>

        <label
          v-else-if="action.kind === 'webhook'"
          class="grid gap-1.5 text-sm font-medium text-n-slate-11 md:col-span-2"
        >
          {{ t('FORMS.SUBMISSION_ACTIONS.URL') }}
          <input
            :class="controlClass"
            :value="action.url"
            type="url"
            :placeholder="t('FORMS.SUBMISSION_ACTIONS.URL_PLACEHOLDER')"
            data-test="forms-action-url"
            @input="alterar(index, { url: $event.target.value })"
          />
        </label>

        <div class="md:col-span-2 md:text-end">
          <button
            type="button"
            class="rounded px-2 py-1 text-xs font-semibold text-n-ruby-11 transition hover:bg-n-ruby-3"
            data-test="forms-action-remove"
            @click="remover(index)"
          >
            {{ t('FORMS.SUBMISSION_ACTIONS.REMOVE') }}
          </button>
        </div>
      </div>

      <p v-if="!actions.length" class="mb-0 text-sm text-n-slate-10">
        {{ t('FORMS.SUBMISSION_ACTIONS.NONE') }}
      </p>

      <button
        type="button"
        class="min-h-9 w-full rounded border border-dashed border-n-slate-5 text-sm font-semibold text-n-slate-11 transition hover:border-n-teal-7 hover:text-n-teal-11"
        data-test="forms-action-add"
        @click="adicionar"
      >
        {{ t('FORMS.SUBMISSION_ACTIONS.ADD') }}
      </button>
    </template>
  </section>
</template>
