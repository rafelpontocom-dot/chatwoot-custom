<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';

import FormsAPI from 'dashboard/api/forms';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';

defineOptions({
  name: 'FormsSubmissionDetailsDialog',
});

const { t } = useI18n();
const dialog = ref(null);
const submission = ref(null);
const loadError = ref('');

const submissionSections = computed(() => {
  if (!submission.value?.fields) return [];

  return submission.value.fields.reduce((sections, field) => {
    const title =
      field.section_title || t('FORMS.SUBMISSIONS.UNTITLED_SECTION');
    const section = sections.find(item => item.title === title);

    if (section) {
      section.fields.push(field);
      return sections;
    }

    sections.push({ title, fields: [field] });
    return sections;
  }, []);
});

/**
 * O que as regras de cálculo somaram. Fica antes das secções porque é a
 * leitura de topo — uma triagem quer o número antes das respostas que o
 * produziram. Vazio quando o formulário não declara variáveis.
 */
const computedVariables = computed(() =>
  Object.entries(submission.value?.variables || {}).map(([name, value]) => ({
    name,
    value,
  }))
);

const formatAnswer = value => {
  if (Array.isArray(value)) return value.join(', ');
  if (value === true) return t('FORMS.SUBMISSIONS.YES');
  if (value === false) return t('FORMS.SUBMISSIONS.NO');

  return value || t('FORMS.SUBMISSIONS.NO_ANSWER');
};

const open = async submissionId => {
  submission.value = null;
  loadError.value = '';
  dialog.value?.open();

  try {
    const { data } = await FormsAPI.getSubmission(submissionId);
    submission.value = data;
  } catch (error) {
    loadError.value = error.response?.data?.message || t('FORMS.ERROR.LOAD');
  }
};

defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialog"
    width="xl"
    :title="t('FORMS.SUBMISSIONS.DETAIL_TITLE')"
    :show-confirm-button="false"
    :cancel-button-label="t('FORMS.ACTIONS.CLOSE')"
  >
    <p v-if="loadError" class="mb-0 text-sm text-n-ruby-11" role="alert">
      {{ loadError }}
    </p>
    <p
      v-else-if="!submission"
      class="mb-0 py-8 text-center text-sm text-n-slate-10"
    >
      {{ t('KANBAN.OPPORTUNITY_DETAILS.LOADING') }}
    </p>
    <div v-else class="grid max-h-[65vh] gap-4 overflow-y-auto pr-1">
      <section
        v-if="computedVariables.length"
        class="overflow-hidden rounded-lg border border-n-weak bg-n-solid-2"
      >
        <h3
          class="mb-0 border-b border-n-weak px-4 py-3 text-sm font-semibold text-n-slate-12"
        >
          {{ t('FORMS.SUBMISSIONS.VARIABLES') }}
        </h3>
        <dl class="flex flex-wrap gap-x-8 gap-y-3 px-4 py-3">
          <div v-for="variable in computedVariables" :key="variable.name">
            <dt class="text-xs font-medium text-n-slate-10">
              {{ variable.name }}
            </dt>
            <dd class="mb-0 mt-1 text-sm font-semibold text-n-slate-12">
              {{ variable.value }}
            </dd>
          </div>
        </dl>
      </section>
      <section
        v-for="section in submissionSections"
        :key="section.title"
        class="overflow-hidden rounded-lg border border-n-weak bg-n-solid-1"
      >
        <h3
          class="mb-0 border-b border-n-weak px-4 py-3 text-sm font-semibold text-n-slate-12"
        >
          {{ section.title }}
        </h3>
        <dl class="divide-y divide-n-weak px-4">
          <div v-for="field in section.fields" :key="field.key" class="py-3">
            <dt class="text-xs font-medium text-n-slate-10">
              {{ field.label }}
            </dt>
            <dd
              class="mb-0 mt-1 whitespace-pre-wrap break-words text-sm leading-6 text-n-slate-12"
            >
              {{ formatAnswer(submission.answers[field.key]) }}
            </dd>
          </div>
        </dl>
      </section>
      <p
        v-if="!submissionSections.length"
        class="mb-0 py-6 text-center text-sm text-n-slate-10"
      >
        {{ t('FORMS.SUBMISSIONS.NO_ANSWER') }}
      </p>
      <div class="flex justify-end">
        <Button
          variant="faded"
          color="slate"
          :label="t('FORMS.ACTIONS.CLOSE')"
          @click="dialog?.close()"
        />
      </div>
    </div>
  </Dialog>
</template>
