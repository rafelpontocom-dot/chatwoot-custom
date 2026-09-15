<script setup>
import { useI18n } from 'vue-i18n';
import RaevoField from 'dashboard/components-next/raevo/RaevoField.vue';
import { RAEVO_SELECT_CLASS } from 'dashboard/components-next/raevo/raevoControl';

/**
 * Raevo — um campo por tipo de recurso: quem atende, a sala, o equipamento.
 *
 * Era um só «Profissional ou recurso», e uma consulta que precisa de
 * profissional e de sala não tinha como ocupar as duas. Que campos aparecem,
 * quais são obrigatórios e o que já vem escolhido decide `useAppointmentResources`;
 * este componente só os desenha, igual nos três sítios onde se marca.
 *
 * `compact` é o balão de criação rápida: sem rótulo visível, o nome do campo
 * vai para a primeira opção e para o `aria-label`.
 */
const props = defineProps({
  fields: { type: Array, required: true },
  modelValue: { type: Object, required: true },
  compact: { type: Boolean, default: false },
  disabled: { type: Boolean, default: false },
  showErrors: { type: Boolean, default: false },
  testidPrefix: { type: String, default: 'calendar-resource' },
});

const emit = defineEmits(['update:modelValue']);
const { t } = useI18n();

const LABELS = {
  professional: 'CALENDAR.RESOURCE_FIELDS.PROFESSIONAL',
  room: 'CALENDAR.RESOURCE_FIELDS.ROOM',
  equipment: 'CALENDAR.RESOURCE_FIELDS.EQUIPMENT',
  other: 'CALENDAR.RESOURCE_FIELDS.OTHER',
};

const REQUIRED_MESSAGES = {
  professional: 'CALENDAR.RESOURCE_FIELDS.REQUIRED.PROFESSIONAL',
  room: 'CALENDAR.RESOURCE_FIELDS.REQUIRED.ROOM',
  equipment: 'CALENDAR.RESOURCE_FIELDS.REQUIRED.EQUIPMENT',
  other: 'CALENDAR.RESOURCE_FIELDS.REQUIRED.OTHER',
};

const errorFor = field =>
  props.showErrors && field.required && !props.modelValue[field.key]
    ? t(REQUIRED_MESSAGES[field.key])
    : '';

const choose = (key, value) => {
  emit('update:modelValue', { ...props.modelValue, [key]: value });
};
</script>

<template>
  <div :class="compact ? 'grid gap-2' : 'grid gap-3 sm:grid-cols-2'">
    <template v-for="field in fields" :key="field.key">
      <select
        v-if="compact"
        :value="modelValue[field.key]"
        :data-testid="`${testidPrefix}-${field.key}`"
        :aria-label="t(LABELS[field.key])"
        :aria-required="field.required"
        :aria-invalid="!!errorFor(field)"
        :disabled="disabled"
        :class="RAEVO_SELECT_CLASS"
        @change="choose(field.key, $event.target.value)"
      >
        <option value="">
          {{ t(LABELS[field.key]) }}{{ field.required ? ' *' : '' }}
        </option>
        <option
          v-for="option in field.options"
          :key="option.id"
          :value="String(option.id)"
        >
          {{ option.name }}
        </option>
      </select>

      <RaevoField
        v-else
        :label="t(LABELS[field.key])"
        :error="errorFor(field)"
        :required="field.required"
        variant="select"
      >
        <template #default="{ controlClass, fieldId, describedBy }">
          <select
            :id="fieldId"
            :value="modelValue[field.key]"
            :data-testid="`${testidPrefix}-${field.key}`"
            :aria-invalid="!!errorFor(field)"
            :aria-describedby="describedBy"
            :disabled="disabled"
            :class="controlClass"
            @change="choose(field.key, $event.target.value)"
          >
            <option value="">
              {{ t('CALENDAR.RESOURCE_FIELDS.SELECT') }}
            </option>
            <option
              v-for="option in field.options"
              :key="option.id"
              :value="String(option.id)"
            >
              {{ option.name }}
            </option>
          </select>
        </template>
      </RaevoField>
    </template>
  </div>
</template>
