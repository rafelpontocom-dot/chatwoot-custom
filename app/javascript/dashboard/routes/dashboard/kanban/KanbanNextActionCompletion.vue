<script setup>
import { computed, nextTick, onMounted, ref, useId, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import NextButton from 'dashboard/components-next/button/Button.vue';
import RaevoField from 'dashboard/components-next/raevo/RaevoField.vue';
import RaevoStamp from 'dashboard/components-next/raevo/RaevoStamp.vue';

// RAEVO (09/10, 123jpnbcb5h) — concluir a próxima ação em dois passos, como na
// maquete aprovada: «Como foi?» (o resultado fica no histórico) e, logo a seguir,
// a próxima ação já aberta. Quem grava é a ficha; aqui só se pergunta.
// 'schedule' é o mesmo formulário do passo 2, aberto do estado vazio, sem nada
// concluído antes.
const props = defineProps({
  /** 'result' | 'next' | 'schedule' */
  step: { type: String, required: true },
  actionLabel: { type: String, default: '' },
  actionNote: { type: String, default: '' },
  actionType: { type: String, default: '' },
  typeOptions: { type: Array, default: () => [] },
  saving: { type: Boolean, default: false },
  error: { type: String, default: '' },
});

const emit = defineEmits(['cancel', 'confirm', 'saveNext', 'skipNext']);

const { t } = useI18n();
const grupoId = useId();

const atalhos = computed(() => [
  {
    chave: 'answered',
    label: t('KANBAN.OPPORTUNITY_DETAILS.COMPLETE_FLOW.QUICK_ANSWERED'),
  },
  {
    chave: 'not_answered',
    label: t('KANBAN.OPPORTUNITY_DETAILS.COMPLETE_FLOW.QUICK_NOT_ANSWERED'),
  },
  {
    chave: 'call_back',
    label: t('KANBAN.OPPORTUNITY_DETAILS.COMPLETE_FLOW.QUICK_CALL_BACK'),
  },
]);
const atalho = ref('');
const resultado = ref('');
const rotuloDoAtalho = chave =>
  atalhos.value.find(item => item.chave === chave)?.label || '';
const prefixoDe = chave => {
  const rotulo = rotuloDoAtalho(chave);
  return rotulo ? `${rotulo}. ` : '';
};
// O atalho escreve o começo do resultado; o resto do texto fica como estava.
const escolherAtalho = chave => {
  const anterior = prefixoDe(atalho.value);
  const resto =
    anterior && resultado.value.startsWith(anterior)
      ? resultado.value.slice(anterior.length)
      : resultado.value;
  atalho.value = atalho.value === chave ? '' : chave;
  resultado.value = `${prefixoDe(atalho.value)}${resto}`;
};

const concluida = computed(() => {
  const base = props.actionType
    ? t('KANBAN.OPPORTUNITY_DETAILS.COMPLETE_FLOW.DONE', {
        type: props.actionType,
      })
    : t('KANBAN.OPPORTUNITY_DETAILS.COMPLETE_FLOW.DONE_UNTYPED');
  const escolhido = rotuloDoAtalho(atalho.value);
  return escolhido ? `${base} · ${escolhido}` : base;
});

const proximoTipo = ref('');
const proximaData = ref('');
const proximaObservacao = ref('');

const passo = computed(() => {
  if (props.step === 'schedule') return null;
  return props.step === 'result' ? 1 : 2;
});

// O foco segue o passo: quem abriu com o teclado não fica no botão que sumiu.
const campoResultado = ref(null);
const campoTipo = ref(null);
const focarPasso = async () => {
  await nextTick();
  (props.step === 'result' ? campoResultado : campoTipo).value?.focus();
};
onMounted(focarPasso);
watch(() => props.step, focarPasso);
</script>

<template>
  <section
    data-testid="kanban-next-action-completion"
    :data-step="step"
    class="grid gap-3"
    :aria-busy="saving"
  >
    <p v-if="passo" class="mb-0 text-end text-xs text-n-slate-11">
      {{ t('KANBAN.OPPORTUNITY_DETAILS.COMPLETE_FLOW.STEP', { n: passo }) }}
    </p>

    <template v-if="step === 'result'">
      <div
        class="flex items-start gap-2 rounded-md border border-n-weak bg-n-alpha-1 px-2.5 py-2"
      >
        <i
          aria-hidden="true"
          class="i-lucide-calendar-clock mt-0.5 size-4 shrink-0 text-n-slate-11"
        />
        <div class="grid min-w-0 gap-0.5">
          <span
            data-testid="kanban-completion-action"
            class="break-words text-sm font-medium text-n-slate-12"
          >
            {{ actionLabel }}
          </span>
          <span v-if="actionNote" class="break-words text-xs text-n-slate-11">
            {{ actionNote }}
          </span>
        </div>
      </div>

      <div class="grid gap-1.5">
        <span :id="grupoId" class="text-sm font-medium text-n-slate-12">
          {{ t('KANBAN.OPPORTUNITY_DETAILS.COMPLETE_FLOW.HOW_WAS_IT') }}
        </span>
        <div
          role="group"
          :aria-labelledby="grupoId"
          class="flex flex-wrap gap-1.5"
        >
          <NextButton
            v-for="item in atalhos"
            :key="item.chave"
            type="button"
            sm
            :variant="atalho === item.chave ? 'solid' : 'outline'"
            :color="atalho === item.chave ? 'blue' : 'slate'"
            :icon="atalho === item.chave ? 'i-lucide-check' : ''"
            :label="item.label"
            :aria-pressed="atalho === item.chave"
            :data-testid="`kanban-completion-quick-${item.chave}`"
            :disabled="saving"
            @click="escolherAtalho(item.chave)"
          />
        </div>
      </div>

      <RaevoField
        :label="t('KANBAN.OPPORTUNITY_DETAILS.COMPLETE_FLOW.RESULT')"
        :hint="t('KANBAN.OPPORTUNITY_DETAILS.COMPLETE_FLOW.RESULT_HINT')"
        variant="textarea"
      >
        <template #default="{ controlClass, fieldId }">
          <textarea
            :id="fieldId"
            ref="campoResultado"
            v-model="resultado"
            rows="3"
            data-testid="kanban-completion-result"
            :class="controlClass"
            :disabled="saving"
          />
        </template>
      </RaevoField>
    </template>

    <template v-else>
      <div v-if="step === 'next'" role="status" class="justify-self-start">
        <RaevoStamp
          variant="success"
          data-testid="kanban-completion-done"
          :label="concluida"
        />
      </div>

      <div class="grid gap-3 sm:grid-cols-2">
        <RaevoField
          :label="t('KANBAN.OPPORTUNITY_DETAILS.NEXT_ACTION_TYPE')"
          variant="select"
        >
          <template #default="{ controlClass, fieldId }">
            <select
              :id="fieldId"
              ref="campoTipo"
              v-model="proximoTipo"
              data-testid="kanban-completion-next-type"
              :class="controlClass"
              :disabled="saving"
            >
              <option
                v-for="option in typeOptions"
                :key="option.value || 'none'"
                :value="option.value"
              >
                {{ option.label }}
              </option>
            </select>
          </template>
        </RaevoField>
        <RaevoField :label="t('KANBAN.OPPORTUNITY_DETAILS.NEXT_ACTION_AT')">
          <template #default="{ controlClass, fieldId }">
            <input
              :id="fieldId"
              v-model="proximaData"
              type="datetime-local"
              data-testid="kanban-completion-next-at"
              :class="controlClass"
              :disabled="saving"
            />
          </template>
        </RaevoField>
      </div>
      <RaevoField
        :label="t('KANBAN.OPPORTUNITY_DETAILS.NEXT_ACTION_NOTE')"
        variant="textarea"
      >
        <template #default="{ controlClass, fieldId }">
          <textarea
            :id="fieldId"
            v-model="proximaObservacao"
            rows="2"
            data-testid="kanban-completion-next-note"
            :class="controlClass"
            :disabled="saving"
          />
        </template>
      </RaevoField>
    </template>

    <p
      v-if="error"
      role="alert"
      data-testid="kanban-completion-error"
      class="mb-0 flex items-start gap-2 rounded-md bg-n-ruby-2 px-2.5 py-2 text-xs text-n-ruby-11"
    >
      <i
        aria-hidden="true"
        class="i-lucide-circle-alert mt-px size-3.5 shrink-0"
      />
      {{ error }}
    </p>

    <!-- No telemóvel a ação principal fica por cima e os dois ocupam a largura. -->
    <div
      v-if="step === 'result'"
      class="flex flex-col-reverse gap-2 sm:flex-row sm:justify-end"
    >
      <NextButton
        type="button"
        sm
        outline
        slate
        data-testid="kanban-completion-cancel"
        :label="t('KANBAN.OPPORTUNITY_DETAILS.COMPLETE_FLOW.CANCEL')"
        :disabled="saving"
        @click="emit('cancel')"
      />
      <NextButton
        type="button"
        sm
        data-testid="kanban-completion-confirm"
        :label="
          saving
            ? t('KANBAN.OPPORTUNITY_DETAILS.COMPLETE_FLOW.CONCLUDING')
            : error
              ? t('KANBAN.OPPORTUNITY_DETAILS.COMPLETE_FLOW.RETRY')
              : t('KANBAN.OPPORTUNITY_DETAILS.COMPLETE_FLOW.CONFIRM')
        "
        :is-loading="saving"
        :disabled="saving"
        @click="emit('confirm', resultado.trim())"
      />
    </div>
    <div
      v-else
      class="flex flex-col-reverse gap-2 sm:flex-row sm:items-center sm:justify-between"
    >
      <NextButton
        v-if="step === 'next'"
        type="button"
        sm
        outline
        slate
        data-testid="kanban-completion-skip"
        :label="t('KANBAN.OPPORTUNITY_DETAILS.COMPLETE_FLOW.NO_NEXT')"
        :disabled="saving"
        @click="emit('skipNext')"
      />
      <NextButton
        v-else
        type="button"
        sm
        outline
        slate
        data-testid="kanban-completion-cancel"
        :label="t('KANBAN.OPPORTUNITY_DETAILS.COMPLETE_FLOW.CANCEL')"
        :disabled="saving"
        @click="emit('cancel')"
      />
      <NextButton
        type="button"
        sm
        data-testid="kanban-completion-save-next"
        :label="t('KANBAN.OPPORTUNITY_DETAILS.COMPLETE_FLOW.SAVE_NEXT')"
        :disabled="saving || !proximaData"
        :is-loading="saving"
        @click="
          emit('saveNext', {
            type: proximoTipo,
            at: proximaData,
            note: proximaObservacao.trim(),
          })
        "
      />
    </div>
  </section>
</template>
