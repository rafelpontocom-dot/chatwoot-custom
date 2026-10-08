<script setup>
import { useI18n } from 'vue-i18n';
import RaevoField from 'dashboard/components-next/raevo/RaevoField.vue';
import {
  requiredFieldInputType,
  requiredFieldOptions,
  requiredFieldType,
} from 'dashboard/helper/kanbanRequiredFields';

/**
 * Os campos que uma etapa exige, nos três sítios que os pedem: criar no funil,
 * criar na conversa e mover com campos em falta.
 *
 * Eram três cópias, duas com `<label>` e classe à mão, e as três desenhavam o
 * multiselect como texto livre — que o servidor recusa, por não ser uma das
 * opções. O campo obrigatório que não se consegue preencher volta a fazer da
 * criação um beco sem saída.
 */
const props = defineProps({
  definitions: { type: Array, required: true },
  modelValue: { type: Object, required: true },
  /** prefixo do data-testid de cada controlo, que os specs já localizavam */
  testidPrefix: { type: String, required: true },
});

const emit = defineEmits(['update:modelValue']);
const { t } = useI18n();

const definir = (key, value) =>
  emit('update:modelValue', { ...props.modelValue, [key]: value });

const tipoDe = definition => requiredFieldType(definition);
const eSelect = definition =>
  ['select', 'boolean'].includes(tipoDe(definition));
const eMultipla = definition => tipoDe(definition) === 'multiselect';

// A lista múltipla leva a casca do textarea: com a altura de um controlo de uma
// linha só se via uma opção de cada vez.
const variante = definition => {
  if (eSelect(definition)) return 'select';
  if (eMultipla(definition) || tipoDe(definition) === 'textarea') {
    return 'textarea';
  }

  return 'input';
};

// O booleano viaja como `true`/`false`; o `<option>` só guarda texto.
const escolher = (definition, event) => {
  const opcao = requiredFieldOptions(definition, t).find(
    item => String(item.value) === event.target.value
  );
  definir(definition.key, opcao ? opcao.value : '');
};

const escolherVarias = (definition, event) =>
  definir(
    definition.key,
    Array.from(event.target.selectedOptions).map(option => option.value)
  );
</script>

<template>
  <RaevoField
    v-for="definition in definitions"
    :key="definition.key"
    :label="definition.label || definition.key"
    :variant="variante(definition)"
    :hint="
      eMultipla(definition) ? t('KANBAN.REQUIRED_FIELDS.MULTISELECT_HINT') : ''
    "
  >
    <template #default="{ controlClass, fieldId, describedBy }">
      <select
        v-if="eSelect(definition)"
        :id="fieldId"
        :value="String(modelValue[definition.key] ?? '')"
        :data-testid="`${testidPrefix}${definition.key}`"
        :class="controlClass"
        :aria-describedby="describedBy"
        @change="escolher(definition, $event)"
      >
        <option value="" disabled>
          {{ t('KANBAN.ASSISTED_MOVE.SELECT_VALUE') }}
        </option>
        <option
          v-for="option in requiredFieldOptions(definition, t)"
          :key="String(option.value)"
          :value="String(option.value)"
        >
          {{ option.label }}
        </option>
      </select>
      <select
        v-else-if="eMultipla(definition)"
        :id="fieldId"
        multiple
        :data-testid="`${testidPrefix}${definition.key}`"
        :class="controlClass"
        :aria-describedby="describedBy"
        @change="escolherVarias(definition, $event)"
      >
        <option
          v-for="option in definition.options || []"
          :key="option"
          :value="option"
          :selected="(modelValue[definition.key] || []).includes(option)"
        >
          {{ option }}
        </option>
      </select>
      <textarea
        v-else-if="tipoDe(definition) === 'textarea'"
        :id="fieldId"
        :value="modelValue[definition.key] ?? ''"
        rows="3"
        :data-testid="`${testidPrefix}${definition.key}`"
        :class="controlClass"
        :aria-describedby="describedBy"
        @input="definir(definition.key, $event.target.value)"
      />
      <input
        v-else
        :id="fieldId"
        :value="modelValue[definition.key] ?? ''"
        :type="requiredFieldInputType(definition)"
        :data-testid="`${testidPrefix}${definition.key}`"
        :class="controlClass"
        :aria-describedby="describedBy"
        @input="definir(definition.key, $event.target.value)"
      />
    </template>
  </RaevoField>
</template>
