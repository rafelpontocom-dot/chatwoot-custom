<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import RaevoField from 'dashboard/components-next/raevo/RaevoField.vue';
import SetupButton from '../shared/SetupButton.vue';
import SetupGroup from '../shared/SetupGroup.vue';
import SetupPill from '../shared/SetupPill.vue';
import SetupRow from '../shared/SetupRow.vue';
import { toSlug } from '../setupHelpers';
import { useProcedureDraft } from './procedureDraft';

const { t } = useI18n();
const { draft } = useProcedureDraft();

const KINDS = ['text', 'phone', 'email', 'cpf', 'textarea', 'select', 'date'];
// fixo → obrigatório → obrigatório · Feegow → opcional → obrigatório…
const REQUIRED_CYCLE = [true, 'feegow', false];

const isAdding = ref(false);
const newQuestion = ref({
  label: '',
  kind: 'text',
  required: false,
  options: '',
});

const pillFor = question => {
  if (question.locked)
    return {
      tone: 'neutral',
      label: t('CALENDAR_SETUP.PROCEDURE.FORM.LOCKED'),
    };
  if (question.required === 'feegow')
    return {
      tone: 'feegow',
      label: t('CALENDAR_SETUP.PROCEDURE.FORM.REQUIRED_FEEGOW'),
    };
  if (question.required)
    return { tone: 'on', label: t('CALENDAR_SETUP.PROCEDURE.FORM.REQUIRED') };
  return {
    tone: 'neutral',
    label: t('CALENDAR_SETUP.PROCEDURE.FORM.OPTIONAL'),
  };
};

const hintFor = question => {
  if (question.key === 'email') return '';
  const known = {
    full_name: 'HINT_FULL_NAME',
    whatsapp: 'HINT_WHATSAPP',
    notes: 'HINT_NOTES',
  }[question.key];
  if (question.key === 'cpf' || question.required === 'feegow') {
    return draft.value.mirrors_feegow
      ? t('CALENDAR_SETUP.PROCEDURE.FORM.HINT_CPF_FEEGOW')
      : t('CALENDAR_SETUP.PROCEDURE.FORM.HINT_CPF_NO_FEEGOW');
  }
  return known
    ? t(`CALENDAR_SETUP.PROCEDURE.FORM.${known}`)
    : t(`CALENDAR_SETUP.PROCEDURE.FORM.KINDS.${question.kind.toUpperCase()}`);
};

const cycleRequired = question => {
  if (question.locked) return;
  const position = REQUIRED_CYCLE.indexOf(question.required);
  question.required = REQUIRED_CYCLE[(position + 1) % REQUIRED_CYCLE.length];
};

const move = (index, offset) => {
  const questions = [...draft.value.questions];
  const [item] = questions.splice(index, 1);
  questions.splice(index + offset, 0, item);
  draft.value.questions = questions;
};

const remove = index => {
  draft.value.questions = draft.value.questions.filter(
    (_, position) => position !== index
  );
};

const add = () => {
  const label = newQuestion.value.label.trim();
  if (!label) return;
  let key =
    toSlug(label)
      .replace(/-/g, '_')
      .replace(/^[^a-z]+/, '') || 'pergunta';
  const taken = new Set(draft.value.questions.map(question => question.key));
  while (taken.has(key)) key = `${key}_2`;
  const question = {
    key,
    label,
    kind: newQuestion.value.kind,
    required: newQuestion.value.required,
  };
  if (question.kind === 'select') {
    question.options = newQuestion.value.options
      .split('\n')
      .map(option => option.trim())
      .filter(Boolean);
  }
  draft.value.questions = [...draft.value.questions, question];
  isAdding.value = false;
  newQuestion.value = { label: '', kind: 'text', required: false, options: '' };
};
</script>

<template>
  <SetupGroup
    :title="t('CALENDAR_SETUP.PROCEDURE.FORM.GROUP')"
    :hint="t('CALENDAR_SETUP.PROCEDURE.FORM.GROUP_HINT')"
    flush
    data-testid="calendar-procedure-tab-form"
  >
    <SetupRow
      v-for="(question, index) in draft.questions"
      :key="question.key"
      :title="question.label"
      :hint="hintFor(question)"
      :data-testid="`calendar-procedure-question-${question.key}`"
    >
      <button
        type="button"
        class="rounded-full p-0 outline-none focus-visible:ring-2 focus-visible:ring-n-brand/40 disabled:cursor-default disabled:opacity-100"
        :disabled="question.locked"
        :title="t('CALENDAR_SETUP.PROCEDURE.FORM.TOGGLE_REQUIRED')"
        :aria-label="
          t('CALENDAR_SETUP.PROCEDURE.FORM.TOGGLE_REQUIRED_OF', {
            label: question.label,
          })
        "
        @click="cycleRequired(question)"
      >
        <SetupPill v-bind="pillFor(question)" />
      </button>
      <button
        v-for="action in [
          {
            icon: 'i-lucide-arrow-up',
            label: 'MOVE_UP',
            offset: -1,
            hidden: index === 0,
          },
          {
            icon: 'i-lucide-arrow-down',
            label: 'MOVE_DOWN',
            offset: 1,
            hidden: index === draft.questions.length - 1,
          },
        ]"
        :key="action.label"
        type="button"
        class="flex size-7 items-center justify-center rounded-full p-0 text-n-slate-10 outline-none hover:bg-n-alpha-2 hover:text-n-slate-12 focus-visible:ring-2 focus-visible:ring-n-brand/40"
        :class="action.hidden && 'invisible'"
        :aria-label="t(`CALENDAR_SETUP.PROCEDURE.FORM.${action.label}`)"
        :title="t(`CALENDAR_SETUP.PROCEDURE.FORM.${action.label}`)"
        @click="move(index, action.offset)"
      >
        <i :class="action.icon" class="size-3.5" aria-hidden="true" />
      </button>
      <button
        type="button"
        class="flex size-7 items-center justify-center rounded-full p-0 text-n-slate-10 outline-none hover:bg-n-alpha-2 hover:text-n-ruby-11 focus-visible:ring-2 focus-visible:ring-n-brand/40"
        :class="question.locked && 'invisible'"
        :aria-label="t('CALENDAR_SETUP.COMMON.REMOVE')"
        :title="t('CALENDAR_SETUP.COMMON.REMOVE')"
        @click="remove(index)"
      >
        <i class="i-lucide-trash-2 size-3.5" aria-hidden="true" />
      </button>
    </SetupRow>

    <div
      v-if="isAdding"
      class="mt-2.5 grid gap-3 rounded-lg border border-solid border-n-weak bg-n-surface-2 p-3"
    >
      <div class="grid gap-3 md:grid-cols-[minmax(0,2fr)_minmax(0,1fr)]">
        <RaevoField compact :label="t('CALENDAR_SETUP.PROCEDURE.FORM.LABEL')">
          <template #default="{ controlClass, fieldId }">
            <input
              :id="fieldId"
              v-model="newQuestion.label"
              type="text"
              :class="controlClass"
              data-testid="calendar-question-label"
            />
          </template>
        </RaevoField>
        <RaevoField
          compact
          variant="select"
          :label="t('CALENDAR_SETUP.PROCEDURE.FORM.KIND')"
        >
          <template #default="{ controlClass, fieldId }">
            <select
              :id="fieldId"
              v-model="newQuestion.kind"
              :class="controlClass"
            >
              <option v-for="kind in KINDS" :key="kind" :value="kind">
                {{
                  t(`CALENDAR_SETUP.PROCEDURE.FORM.KINDS.${kind.toUpperCase()}`)
                }}
              </option>
            </select>
          </template>
        </RaevoField>
      </div>
      <RaevoField
        v-if="newQuestion.kind === 'select'"
        compact
        variant="textarea"
        :label="t('CALENDAR_SETUP.PROCEDURE.FORM.OPTIONS')"
      >
        <template #default="{ controlClass, fieldId }">
          <textarea
            :id="fieldId"
            v-model="newQuestion.options"
            rows="3"
            :class="controlClass"
          />
        </template>
      </RaevoField>
      <label class="flex items-center gap-2 text-ui text-n-slate-12">
        <input v-model="newQuestion.required" type="checkbox" class="mb-0" />
        {{ t('CALENDAR_SETUP.PROCEDURE.FORM.REQUIRED_CHECK') }}
      </label>
      <div class="flex justify-end gap-2">
        <SetupButton
          size="sm"
          :label="t('CALENDAR_SETUP.COMMON.CANCEL')"
          @click="isAdding = false"
        />
        <SetupButton
          size="sm"
          variant="primary"
          :label="t('CALENDAR_SETUP.PROCEDURE.FORM.ADD_CONFIRM')"
          :disabled="!newQuestion.label.trim()"
          data-testid="calendar-question-add"
          @click="add"
        />
      </div>
    </div>
    <div v-else class="mt-2.5">
      <SetupButton
        variant="dashed"
        :label="t('CALENDAR_SETUP.PROCEDURE.FORM.ADD')"
        data-testid="calendar-question-open"
        @click="isAdding = true"
      />
    </div>
  </SetupGroup>
</template>
