<script setup>
import { computed, onMounted, ref } from 'vue';
import FluentIcon from 'shared/components/FluentIcon/Index.vue';

const payload = ref(null);
const answers = ref({});
const currentSectionIndex = ref(0);
const isLoading = ref(true);
const isSubmitting = ref(false);
const submitted = ref(false);
const errorMessage = ref('');
const invalidFieldKey = ref('');
const honeypot = ref('');
const requiredMarker = '*';

const appearanceThemes = {
  calm: {
    shell: 'bg-n-slate-2',
    card: 'border-n-slate-4 bg-n-solid-1',
    brandMark: 'bg-n-teal-3 text-n-teal-11',
    eyebrow: 'text-n-teal-11',
    progress: 'accent-n-teal-9',
    submit: 'bg-n-teal-9 hover:bg-n-teal-10 focus-visible:ring-n-teal-6',
  },
  warm: {
    shell: 'bg-n-amber-2',
    card: 'border-n-amber-5 bg-n-solid-1',
    brandMark: 'bg-n-amber-4 text-n-amber-11',
    eyebrow: 'text-n-amber-11',
    progress: 'accent-n-amber-9',
    submit: 'bg-n-amber-9 hover:bg-n-amber-10 focus-visible:ring-n-amber-6',
  },
  contrast: {
    shell: 'bg-n-slate-12',
    card: 'border-n-slate-6 bg-n-solid-1',
    brandMark: 'bg-n-slate-3 text-n-slate-12',
    eyebrow: 'text-n-slate-11',
    progress: 'accent-n-slate-12',
    submit: 'bg-n-slate-12 hover:bg-n-slate-11 focus-visible:ring-n-slate-9',
  },
};

const translations = {
  pt_PT: {
    back: 'Voltar',
    continue: 'Continuar',
    loading: 'A preparar o formulário...',
    submit: 'Enviar formulário',
    submitted: 'Formulário enviado',
    submittedDescription:
      'Recebemos as suas informações. A equipa dará continuidade ao atendimento.',
    unavailable: 'Não foi possível abrir este formulário.',
    required: 'Campo obrigatório',
    step: 'Etapa {current} de {total}',
  },
  'pt-PT': {
    back: 'Voltar',
    continue: 'Continuar',
    loading: 'A preparar o formulário...',
    submit: 'Enviar formulário',
    submitted: 'Formulário enviado',
    submittedDescription:
      'Recebemos as suas informações. A equipa dará continuidade ao atendimento.',
    unavailable: 'Não foi possível abrir este formulário.',
    required: 'Campo obrigatório',
    step: 'Etapa {current} de {total}',
  },
  default: {
    back: 'Voltar',
    continue: 'Continuar',
    loading: 'Preparando o formulário...',
    submit: 'Enviar formulário',
    submitted: 'Formulário enviado',
    submittedDescription:
      'Recebemos suas informações. A equipe dará continuidade ao atendimento.',
    unavailable: 'Não foi possível abrir este formulário.',
    required: 'Campo obrigatório',
    step: 'Etapa {current} de {total}',
  },
};

const copy = computed(
  () => translations[payload.value?.form?.locale] || translations.default
);
const appearance = computed(
  () => appearanceThemes[payload.value?.form?.theme] || appearanceThemes.calm
);
const brandName = computed(
  () => payload.value?.form?.brand_name || payload.value?.form?.name || ''
);
const brandInitial = computed(() => brandName.value.trim().charAt(0) || 'R');
const sections = computed(() => payload.value?.schema?.sections || []);
const currentSection = computed(
  () => sections.value[currentSectionIndex.value]
);
const isLastSection = computed(
  () => currentSectionIndex.value === sections.value.length - 1
);
const progressDescription = computed(() =>
  copy.value.step
    .replace('{current}', currentSectionIndex.value + 1)
    .replace('{total}', sections.value.length)
);
onMounted(async () => {
  try {
    const response = await fetch(window.location.pathname, {
      headers: { Accept: 'application/json' },
    });
    if (!response.ok) throw new Error('form_unavailable');
    payload.value = await response.json();
    document.title = payload.value.form.name;
  } catch {
    errorMessage.value = translations.default.unavailable;
  } finally {
    isLoading.value = false;
  }
});

function fieldId(field) {
  return `form-field-${field.key}`;
}

function optionValue(option) {
  return typeof option === 'object' ? option.value : option;
}

function optionLabel(option) {
  return typeof option === 'object' ? option.label || option.value : option;
}

function isRequiredMissing(field) {
  if (!field.required) return false;
  const value = answers.value[field.key];
  return (
    value === undefined ||
    value === null ||
    value === '' ||
    value === false ||
    (Array.isArray(value) && value.length === 0)
  );
}

function conditionMatches(answer, conditionValue) {
  if (
    typeof answer === 'boolean' &&
    ['true', 'false'].includes(conditionValue)
  ) {
    return answer === (conditionValue === 'true');
  }

  return answer === conditionValue;
}

function isFieldVisible(field) {
  const condition = field.visible_when;
  if (!condition) return true;

  return (
    condition.operator === 'equals' &&
    conditionMatches(answers.value[condition.field], condition.value)
  );
}

function visibleFields(section) {
  return section?.fields?.filter(isFieldVisible) || [];
}

function validateCurrentSection() {
  const invalid = visibleFields(currentSection.value).find(isRequiredMissing);
  if (!invalid) return true;

  invalidFieldKey.value = invalid.key;
  errorMessage.value = `${invalid.label}: ${copy.value.required.toLowerCase()}`;
  document.getElementById(fieldId(invalid))?.focus();
  return false;
}

function continueForm() {
  if (!validateCurrentSection()) return;
  errorMessage.value = '';
  invalidFieldKey.value = '';
  currentSectionIndex.value += 1;
}

function goBack() {
  errorMessage.value = '';
  invalidFieldKey.value = '';
  currentSectionIndex.value -= 1;
}

async function submitForm() {
  if (!validateCurrentSection()) return;

  isSubmitting.value = true;
  errorMessage.value = '';
  invalidFieldKey.value = '';
  try {
    const response = await fetch(`${window.location.pathname}/respostas`, {
      method: 'POST',
      headers: {
        Accept: 'application/json',
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        submission: { answers: answers.value, website: honeypot.value },
      }),
    });
    const body = await response.json();
    if (!response.ok) throw new Error(body.message || 'submission_failed');
    submitted.value = true;
  } catch (error) {
    errorMessage.value = error.message || copy.value.unavailable;
  } finally {
    isSubmitting.value = false;
  }
}
</script>

<template>
  <section
    data-test="public-form-shell"
    class="min-h-screen w-full px-4 py-8 transition-colors duration-200 motion-reduce:transition-none sm:px-6 sm:py-12"
    :class="appearance.shell"
  >
    <div class="mx-auto w-full max-w-2xl">
      <header v-if="payload" class="mb-5 flex items-center gap-3 px-1 sm:mb-6">
        <div
          class="flex size-11 shrink-0 items-center justify-center rounded-md text-base font-semibold"
          :class="appearance.brandMark"
          aria-hidden="true"
        >
          {{ brandInitial }}
        </div>
        <div class="min-w-0">
          <p
            data-test="public-form-brand"
            class="truncate text-sm font-semibold text-n-slate-12"
          >
            {{ brandName }}
          </p>
          <p class="mt-0.5 text-xs text-n-slate-10">{{ payload.form.name }}</p>
        </div>
      </header>

      <div
        class="w-full rounded-lg border p-6 shadow-sm sm:p-9"
        :class="appearance.card"
      >
        <div
          v-if="isLoading"
          aria-live="polite"
          class="py-16 text-center text-n-slate-10"
        >
          {{ copy.loading }}
        </div>

        <div
          v-else-if="errorMessage && !payload"
          role="alert"
          class="py-16 text-center text-n-ruby-10"
        >
          {{ errorMessage }}
        </div>

        <div
          v-else-if="submitted"
          aria-live="polite"
          class="mx-auto max-w-md py-12 text-center"
        >
          <div
            class="mx-auto flex size-12 items-center justify-center rounded-full bg-n-teal-3 text-lg font-semibold text-n-teal-11"
          >
            <FluentIcon icon="checkmark" size="24" aria-hidden="true" />
          </div>
          <h1 class="mt-5 text-xl font-semibold text-n-slate-12">
            {{ copy.submitted }}
          </h1>
          <p class="mt-2 text-sm leading-6 text-n-slate-10">
            {{ copy.submittedDescription }}
          </p>
        </div>

        <form
          v-else-if="currentSection"
          novalidate
          @submit.prevent="isLastSection ? submitForm() : continueForm()"
        >
          <div
            aria-hidden="true"
            class="absolute -left-[10000px] size-px overflow-hidden"
          >
            <input
              v-model="honeypot"
              name="website"
              tabindex="-1"
              autocomplete="off"
            />
          </div>
          <header>
            <p
              class="text-xs font-medium uppercase tracking-wide"
              :class="appearance.eyebrow"
            >
              {{ progressDescription }}
            </p>
            <h1
              class="mt-2 text-2xl font-semibold leading-tight text-n-slate-12 sm:text-3xl"
            >
              {{ currentSection.title || payload.form.name }}
            </h1>
            <p
              v-if="
                currentSection.description ||
                (currentSectionIndex === 0 && payload.form.description)
              "
              class="mt-3 text-sm leading-6 text-n-slate-10"
            >
              {{ currentSection.description || payload.form.description }}
            </p>
          </header>

          <div class="mt-7 flex items-center gap-3" aria-hidden="true">
            <progress
              class="h-1.5 w-full overflow-hidden rounded-full"
              :class="appearance.progress"
              :value="currentSectionIndex + 1"
              :max="sections.length"
            />
          </div>

          <p
            v-if="errorMessage"
            role="alert"
            class="mt-5 rounded border border-n-ruby-6 bg-n-ruby-2 px-3 py-2 text-sm text-n-ruby-11"
          >
            {{ errorMessage }}
          </p>

          <div class="mt-8 space-y-6">
            <div
              v-for="field in visibleFields(currentSection)"
              :key="field.key"
            >
              <label
                v-if="field.type === 'checkbox' || field.type === 'consent'"
                class="flex min-h-11 items-start gap-3 rounded border border-n-slate-5 px-3 py-3 text-sm text-n-slate-11 transition focus-within:border-n-teal-9 focus-within:ring-2 focus-within:ring-n-teal-6"
              >
                <input
                  :id="fieldId(field)"
                  v-model="answers[field.key]"
                  type="checkbox"
                  :required="field.required"
                  :aria-invalid="invalidFieldKey === field.key"
                  :aria-describedby="
                    field.help_text ? `${fieldId(field)}-help` : undefined
                  "
                  class="mt-0.5 size-4 accent-n-teal-9"
                />
                <span>
                  {{ field.label }}
                  <span
                    v-if="field.required"
                    class="text-n-ruby-10"
                    aria-hidden="true"
                  >
                    {{ requiredMarker }}
                  </span>
                  <span
                    v-if="field.help_text"
                    :id="`${fieldId(field)}-help`"
                    class="mt-1 block text-xs font-normal leading-5 text-n-slate-10"
                  >
                    {{ field.help_text }}
                  </span>
                </span>
              </label>

              <template v-else>
                <label
                  :for="fieldId(field)"
                  class="mb-2 block text-sm font-medium text-n-slate-12"
                >
                  {{ field.label }}
                  <span
                    v-if="field.required"
                    class="text-n-ruby-10"
                    aria-hidden="true"
                  >
                    {{ requiredMarker }}
                  </span>
                </label>
                <p
                  v-if="field.help_text"
                  :id="`${fieldId(field)}-help`"
                  class="-mt-1 mb-2 text-sm leading-5 text-n-slate-10"
                >
                  {{ field.help_text }}
                </p>

                <textarea
                  v-if="field.type === 'textarea'"
                  :id="fieldId(field)"
                  v-model="answers[field.key]"
                  :required="field.required"
                  :aria-invalid="invalidFieldKey === field.key"
                  :aria-describedby="
                    field.help_text ? `${fieldId(field)}-help` : undefined
                  "
                  rows="4"
                  class="w-full rounded border border-n-slate-5 bg-n-solid-1 px-3 py-2 text-base text-n-slate-12 outline-none transition focus:border-n-teal-9 focus:ring-2 focus:ring-n-teal-6"
                />

                <select
                  v-else-if="
                    field.type === 'select' || field.type === 'multi_select'
                  "
                  :id="fieldId(field)"
                  v-model="answers[field.key]"
                  :multiple="field.type === 'multi_select'"
                  :required="field.required"
                  :aria-invalid="invalidFieldKey === field.key"
                  :aria-describedby="
                    field.help_text ? `${fieldId(field)}-help` : undefined
                  "
                  class="min-h-11 w-full rounded border border-n-slate-5 bg-n-solid-1 px-3 py-2 text-base text-n-slate-12 outline-none transition focus:border-n-teal-9 focus:ring-2 focus:ring-n-teal-6"
                >
                  <option v-if="field.type === 'select'" value="" disabled />
                  <option
                    v-for="option in field.options"
                    :key="optionValue(option)"
                    :value="optionValue(option)"
                  >
                    {{ optionLabel(option) }}
                  </option>
                </select>

                <input
                  v-else
                  :id="fieldId(field)"
                  v-model="answers[field.key]"
                  :type="
                    field.type === 'currency'
                      ? 'number'
                      : field.type === 'phone'
                        ? 'tel'
                        : field.type === 'datetime'
                          ? 'datetime-local'
                          : field.type
                  "
                  :required="field.required"
                  :aria-invalid="invalidFieldKey === field.key"
                  :aria-describedby="
                    field.help_text ? `${fieldId(field)}-help` : undefined
                  "
                  :step="field.type === 'currency' ? '0.01' : undefined"
                  class="min-h-11 w-full rounded border border-n-slate-5 bg-n-solid-1 px-3 py-2 text-base text-n-slate-12 outline-none transition focus:border-n-teal-9 focus:ring-2 focus:ring-n-teal-6"
                />
              </template>
              <p
                v-if="invalidFieldKey === field.key"
                class="mt-1.5 text-sm text-n-ruby-11"
              >
                {{ copy.required }}
              </p>
            </div>
          </div>

          <footer
            class="mt-9 flex items-center justify-between gap-3 border-t border-n-slate-4 pt-5"
          >
            <button
              v-if="currentSectionIndex > 0"
              type="button"
              class="min-h-11 px-3 text-sm font-medium text-n-slate-11 underline underline-offset-4 focus-visible:rounded focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-teal-6"
              @click="goBack"
            >
              {{ copy.back }}
            </button>
            <span v-else />
            <button
              type="submit"
              :disabled="isSubmitting"
              class="min-h-11 rounded px-5 text-sm font-medium text-n-solid-1 transition duration-200 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-offset-2 motion-reduce:transition-none disabled:cursor-not-allowed disabled:opacity-60"
              :class="appearance.submit"
            >
              {{ isLastSection ? copy.submit : copy.continue }}
            </button>
          </footer>
        </form>
      </div>
    </div>
  </section>
</template>
