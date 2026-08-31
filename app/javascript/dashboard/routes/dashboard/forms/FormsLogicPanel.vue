<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

import {
  ACTIONS,
  CALCULATE_OPERATORS,
  isUnaryOperator,
  operatorsFor,
} from './logicCatalogue';

/**
 * A lógica de uma pergunta, no formato que o servidor valida.
 *
 * Escreve `schema.logics` — uma lista por pergunta, cada uma com regras
 * `{ condition, action }`. Os operadores oferecidos dependem do tipo da
 * pergunta a que a condição se refere: perguntar «começa com» a uma assinatura
 * não faz sentido, e o `Forms::LogicValidator` recusaria publicar.
 */
const props = defineProps({
  field: { type: Object, default: null },
  fields: { type: Array, default: () => [] },
  logics: { type: Array, default: () => [] },
  variables: { type: Array, default: () => [] },
  endings: { type: Array, default: () => [] },
  hiddenFields: { type: Array, default: () => [] },
});

const emit = defineEmits(['updateLogics', 'updateVariables']);
const { t } = useI18n();

const fieldByKey = computed(() =>
  Object.fromEntries(props.fields.map(item => [item.key, item]))
);

const ownLogic = computed(() =>
  props.logics.find(logic => logic.field_key === props.field?.key)
);

const rules = computed(() => ownLogic.value?.payloads || []);

/** Só perguntas anteriores: uma condição não pode ler o que ainda não foi respondido. */
const conditionOptions = computed(() => {
  const index = props.fields.findIndex(item => item.key === props.field?.key);
  return props.fields.slice(0, index + 1);
});

/**
 * Saltar para trás repetiria perguntas já respondidas, por isso só se oferece
 * o que vem depois — mais os finais, que encerram o preenchimento.
 */
const jumpOptions = computed(() => {
  const index = props.fields.findIndex(item => item.key === props.field?.key);
  const seguintes = props.fields.slice(index + 1).map(item => ({
    key: item.key,
    label: item.label || item.key,
  }));
  const finais = props.endings.map(ending => ({
    key: ending.key,
    label: `${t('FORMS.LOGIC.ACTION.NAVIGATE')} · ${ending.label || ending.key}`,
  }));
  return [...seguintes, ...finais];
});

const operatorsForRef = ref => operatorsFor(fieldByKey.value[ref]?.type);

const optionsForRef = ref => {
  const options = fieldByKey.value[ref]?.options || [];
  return options.map(option =>
    typeof option === 'string' ? option : option.value
  );
};

const writeRules = payloads => {
  const others = props.logics.filter(
    logic => logic.field_key !== props.field.key
  );
  // Sem regras, a entrada sai do schema: uma lista vazia só ocupa espaço na
  // versão publicada e o validador teria de a tolerar.
  const next = payloads.length
    ? [...others, { field_key: props.field.key, payloads }]
    : others;
  emit('updateLogics', next);
};

const addRule = () => {
  const ref = props.field.key;
  const [firstOperator] = operatorsForRef(ref);
  const [firstJump] = jumpOptions.value;
  writeRules([
    ...rules.value,
    {
      condition: { ref, comparison: firstOperator, expected: '' },
      action: { kind: 'navigate', field_key: firstJump?.key || '' },
    },
  ]);
};

const removeRule = index => {
  writeRules(rules.value.filter((_, position) => position !== index));
};

const patchRule = (index, patch) => {
  writeRules(
    rules.value.map((rule, position) => {
      if (position !== index) return rule;
      return {
        ...rule,
        condition: { ...rule.condition, ...(patch.condition || {}) },
        action: patch.action
          ? { ...rule.action, ...patch.action }
          : rule.action,
      };
    })
  );
};

/** Trocar a pergunta da condição invalida o operador anterior. */
const changeRef = (index, ref) => {
  const [firstOperator] = operatorsForRef(ref);
  patchRule(index, {
    condition: { ref, comparison: firstOperator, expected: '' },
  });
};

const changeAction = (index, kind) => {
  const action =
    kind === 'calculate'
      ? {
          kind,
          variable: props.variables[0]?.name || '',
          operator: CALCULATE_OPERATORS[0],
          value: '',
        }
      : { kind, field_key: jumpOptions.value[0]?.key || '' };
  writeRules(
    rules.value.map((rule, position) =>
      position === index ? { ...rule, action } : rule
    )
  );
};

const addVariable = () => {
  const usados = new Set(props.variables.map(variable => variable.name));
  // Sufixo pelo primeiro livre, sem fechar sobre uma variável de laço.
  let suffix = 1;
  while (usados.has(suffix === 1 ? 'variavel' : `variavel_${suffix}`))
    suffix += 1;
  const name = suffix === 1 ? 'variavel' : `variavel_${suffix}`;
  emit('updateVariables', [
    ...props.variables,
    { name, kind: 'number', initial: '0' },
  ]);
};

const removeVariable = name => {
  emit(
    'updateVariables',
    props.variables.filter(variable => variable.name !== name)
  );
};

const controlClass =
  'reset-base mb-0 h-9 w-full rounded-lg border border-solid border-n-weak bg-n-solid-1 px-2.5 text-sm text-n-slate-12 outline-none focus:border-n-teal-7';
</script>

<template>
  <div class="grid gap-4" data-test="forms-logic-panel">
    <section class="grid gap-1.5">
      <h4 class="text-sm font-semibold text-n-slate-12">
        {{ t('FORMS.LOGIC.HIDDEN_FIELDS') }}
      </h4>
      <p class="mb-0 text-xs text-n-slate-10">
        {{ t('FORMS.LOGIC.HIDDEN_FIELDS_HELP') }}
      </p>
      <div class="flex flex-wrap gap-1.5">
        <span
          v-for="hidden in hiddenFields"
          :key="hidden.key || hidden"
          class="rounded-full bg-n-slate-3 px-2.5 py-0.5 text-xs font-medium text-n-slate-11"
        >
          {{ hidden.key || hidden }}
        </span>
      </div>
    </section>

    <section class="grid gap-1.5 border-t border-n-weak pt-4">
      <div class="flex items-center justify-between gap-2">
        <h4 class="text-sm font-semibold text-n-slate-12">
          {{ t('FORMS.LOGIC.VARIABLES') }}
        </h4>
        <button
          type="button"
          class="rounded px-2 py-1 text-xs font-semibold text-n-teal-11 hover:bg-n-teal-3"
          data-test="forms-logic-add-variable"
          @click="addVariable"
        >
          {{ t('FORMS.LOGIC.ADD_VARIABLE') }}
        </button>
      </div>
      <p class="mb-0 text-xs text-n-slate-10">
        {{ t('FORMS.LOGIC.VARIABLES_HELP') }}
      </p>
      <div
        v-for="variable in variables"
        :key="variable.name"
        class="flex items-center gap-2"
      >
        <span
          class="flex-1 truncate rounded-full bg-n-teal-3 px-2.5 py-0.5 text-xs font-semibold text-n-teal-11"
        >
          {{ variable.name }}&nbsp;·&nbsp;{{ variable.initial }}
        </span>
        <button
          type="button"
          class="rounded px-1.5 py-1 text-xs text-n-ruby-11 hover:bg-n-ruby-3"
          :aria-label="t('FORMS.LOGIC.REMOVE_VARIABLE')"
          @click="removeVariable(variable.name)"
        >
          <span class="i-lucide-x size-3.5" aria-hidden="true" />
        </button>
      </div>
    </section>

    <section class="grid gap-1.5 border-t border-n-weak pt-4">
      <h4 class="text-sm font-semibold text-n-slate-12">
        {{ t('FORMS.LOGIC.RULES') }}
      </h4>
      <p class="mb-0 text-xs text-n-slate-10">
        {{ t('FORMS.LOGIC.RULES_HELP') }}
      </p>

      <p v-if="!field" class="mb-0 text-sm text-n-slate-10">
        {{ t('FORMS.LOGIC.SELECT_QUESTION') }}
      </p>

      <template v-else>
        <div
          v-for="(rule, index) in rules"
          :key="index"
          class="grid gap-2 rounded-lg border border-n-weak bg-n-solid-2 p-2.5"
          data-test="forms-logic-rule"
        >
          <div class="grid grid-cols-[3.5rem_minmax(0,1fr)] items-center gap-2">
            <span
              class="text-micro font-bold uppercase tracking-wide text-n-teal-11"
            >
              {{ t('FORMS.LOGIC.WHEN') }}
            </span>
            <select
              :class="controlClass"
              :value="rule.condition.ref"
              data-test="forms-logic-ref"
              @change="changeRef(index, $event.target.value)"
            >
              <option
                v-for="item in conditionOptions"
                :key="item.key"
                :value="item.key"
              >
                {{ item.label || item.key }}
              </option>
            </select>
          </div>
          <div class="grid grid-cols-[3.5rem_minmax(0,1fr)] items-center gap-2">
            <span />
            <div
              class="grid gap-2"
              :class="
                isUnaryOperator(rule.condition.comparison) ? '' : 'grid-cols-2'
              "
            >
              <select
                :class="controlClass"
                :value="rule.condition.comparison"
                data-test="forms-logic-operator"
                @change="
                  patchRule(index, {
                    condition: { comparison: $event.target.value },
                  })
                "
              >
                <option
                  v-for="operator in operatorsForRef(rule.condition.ref)"
                  :key="operator"
                  :value="operator"
                >
                  {{ t(`FORMS.LOGIC.OP.${operator}`) }}
                </option>
              </select>
              <!-- «está vazia» e «foi respondida» não têm valor a comparar. -->
              <select
                v-if="
                  !isUnaryOperator(rule.condition.comparison) &&
                  optionsForRef(rule.condition.ref).length
                "
                :class="controlClass"
                :value="rule.condition.expected"
                data-test="forms-logic-expected"
                @change="
                  patchRule(index, {
                    condition: { expected: $event.target.value },
                  })
                "
              >
                <option
                  v-for="option in optionsForRef(rule.condition.ref)"
                  :key="option"
                  :value="option"
                >
                  {{ option }}
                </option>
              </select>
              <input
                v-else-if="!isUnaryOperator(rule.condition.comparison)"
                :class="controlClass"
                :value="rule.condition.expected"
                :placeholder="t('FORMS.LOGIC.VALUE')"
                data-test="forms-logic-expected"
                @input="
                  patchRule(index, {
                    condition: { expected: $event.target.value },
                  })
                "
              />
            </div>
          </div>

          <div class="grid grid-cols-[3.5rem_minmax(0,1fr)] items-center gap-2">
            <span
              class="text-micro font-bold uppercase tracking-wide text-n-teal-11"
            >
              {{ t('FORMS.LOGIC.THEN') }}
            </span>
            <select
              :class="controlClass"
              :value="rule.action.kind"
              data-test="forms-logic-action"
              @change="changeAction(index, $event.target.value)"
            >
              <option v-for="action in ACTIONS" :key="action" :value="action">
                {{ t(`FORMS.LOGIC.ACTION.${action.toUpperCase()}`) }}
              </option>
            </select>
          </div>

          <div class="grid grid-cols-[3.5rem_minmax(0,1fr)] items-center gap-2">
            <span />
            <select
              v-if="rule.action.kind === 'navigate'"
              :class="controlClass"
              :value="rule.action.field_key"
              data-test="forms-logic-target"
              @change="
                patchRule(index, { action: { field_key: $event.target.value } })
              "
            >
              <option
                v-for="option in jumpOptions"
                :key="option.key"
                :value="option.key"
              >
                {{ option.label }}
              </option>
            </select>
            <div v-else class="grid grid-cols-3 gap-2">
              <select
                :class="controlClass"
                :value="rule.action.variable"
                data-test="forms-logic-variable"
                @change="
                  patchRule(index, {
                    action: { variable: $event.target.value },
                  })
                "
              >
                <option
                  v-for="variable in variables"
                  :key="variable.name"
                  :value="variable.name"
                >
                  {{ variable.name }}
                </option>
              </select>
              <select
                :class="controlClass"
                :value="rule.action.operator"
                @change="
                  patchRule(index, {
                    action: { operator: $event.target.value },
                  })
                "
              >
                <option
                  v-for="operator in CALCULATE_OPERATORS"
                  :key="operator"
                  :value="operator"
                >
                  {{ t(`FORMS.LOGIC.CALC.${operator}`) }}
                </option>
              </select>
              <input
                :class="controlClass"
                :value="rule.action.value"
                :placeholder="t('FORMS.LOGIC.VALUE')"
                @input="
                  patchRule(index, { action: { value: $event.target.value } })
                "
              />
            </div>
          </div>

          <div class="text-right">
            <button
              type="button"
              class="rounded px-2 py-1 text-xs font-semibold text-n-ruby-11 hover:bg-n-ruby-3"
              data-test="forms-logic-remove-rule"
              @click="removeRule(index)"
            >
              {{ t('FORMS.LOGIC.REMOVE_RULE') }}
            </button>
          </div>
        </div>

        <p v-if="!rules.length" class="mb-0 text-sm text-n-slate-10">
          {{ t('FORMS.LOGIC.NO_RULES') }}
        </p>

        <button
          type="button"
          class="mt-1 min-h-9 w-full rounded-lg border border-dashed border-n-weak text-sm font-semibold text-n-slate-11 hover:border-n-teal-7 hover:text-n-teal-11"
          data-test="forms-logic-add-rule"
          @click="addRule"
        >
          {{ t('FORMS.LOGIC.ADD_RULE') }}
        </button>
      </template>
    </section>
  </div>
</template>
