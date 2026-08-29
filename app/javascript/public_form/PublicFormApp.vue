<script setup>
import {
  computed,
  nextTick,
  onBeforeUnmount,
  onMounted,
  ref,
  watch,
} from 'vue';
import FluentIcon from 'shared/components/FluentIcon/Index.vue';
import FormRichTextContent from './FormRichTextContent.vue';

const payload = ref(null);
const answers = ref({});
const attachments = ref({});
const currentSectionIndex = ref(0);
const isLoading = ref(true);
const isSubmitting = ref(false);
const submitted = ref(false);
const errorMessage = ref('');
const brandLogoFailed = ref(false);
const invalidFieldKey = ref('');
const honeypot = ref('');
const captchaToken = ref('');
const captchaError = ref('');
const turnstileContainer = ref(null);
const isPrivatePreview = ref(false);
const requiredMarker = '*';
const PREVIEW_STORAGE_PREFIX = 'raevo-form-preview:';
let draftSaveTimer = null;
let isHydratingDraft = false;
let lastSavedDraftSignature = null;
let turnstileWidgetId = null;

const appearanceThemes = {
  calm: {
    shell: 'bg-n-slate-2',
    card: 'border-n-slate-4 bg-n-solid-1',
    brandMark: 'bg-n-teal-3 text-n-teal-11',
    eyebrow: 'text-n-teal-11',
    progressFilled: 'bg-n-teal-9',
    progressEmpty: 'bg-n-slate-4',
    submit: 'bg-n-teal-9 hover:bg-n-teal-10 focus-visible:ring-n-teal-6',
  },
  warm: {
    shell: 'bg-n-amber-2',
    card: 'border-n-amber-5 bg-n-solid-1',
    brandMark: 'bg-n-amber-4 text-n-amber-11',
    eyebrow: 'text-n-amber-11',
    progressFilled: 'bg-n-amber-9',
    progressEmpty: 'bg-n-amber-5',
    submit: 'bg-n-amber-9 hover:bg-n-amber-10 focus-visible:ring-n-amber-6',
  },
  contrast: {
    shell: 'bg-n-slate-12',
    card: 'border-n-slate-6 bg-n-solid-1',
    brandMark: 'bg-n-slate-3 text-n-slate-12',
    eyebrow: 'text-n-slate-11',
    progressFilled: 'bg-n-slate-12',
    progressEmpty: 'bg-n-slate-5',
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
    signatureHint: 'Digite seu nome completo para registrar este aceite.',
    attachmentHint: 'PDF, JPG, PNG ou HEIC. Máximo de 10 MB por arquivo.',
    captchaRequired: 'Conclua a verificação de segurança para enviar.',
    privacyPolicy: 'Política de privacidade',
    preview: 'Prévia privada:',
    previewDescription:
      'Você pode testar a experiência, mas esta prévia não envia respostas.',
    previewSubmit: 'Envio desativado na prévia',
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
    signatureHint: 'Digite o seu nome completo para registar este aceite.',
    attachmentHint: 'PDF, JPG, PNG ou HEIC. Máximo de 10 MB por ficheiro.',
    captchaRequired: 'Conclua a verificação de segurança para enviar.',
    privacyPolicy: 'Política de privacidade',
    preview: 'Prévia privada:',
    previewDescription:
      'Você pode testar a experiência, mas esta prévia não envia respostas.',
    previewSubmit: 'Envio desativado na prévia',
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
    signatureHint: 'Digite seu nome completo para registrar este aceite.',
    attachmentHint: 'PDF, JPG, PNG ou HEIC. Máximo de 10 MB por arquivo.',
    captchaRequired: 'Conclua a verificação de segurança para enviar.',
    privacyPolicy: 'Política de privacidade',
    preview: 'Prévia privada:',
    previewDescription:
      'Você pode testar a experiência, mas esta prévia não envia respostas.',
    previewSubmit: 'Envio desativado na prévia',
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
const brandLogoUrl = computed(() => payload.value?.form?.brand_logo_url || '');
const privacyPolicyUrl = computed(
  () => payload.value?.form?.privacy_policy_url || ''
);
const brandInitial = computed(() => brandName.value.trim().charAt(0) || 'R');
const sections = computed(() => payload.value?.schema?.sections || []);
const currentSection = computed(
  () => sections.value[currentSectionIndex.value]
);
const currentContentBlocks = computed(
  () => currentSection.value?.content_blocks || []
);
const isLastSection = computed(
  () => currentSectionIndex.value === sections.value.length - 1
);
const captchaRequired = computed(
  () => payload.value?.form?.captcha_provider === 'turnstile'
);
const progressDescription = computed(() =>
  copy.value.step
    .replace('{current}', currentSectionIndex.value + 1)
    .replace('{total}', sections.value.length)
);
onBeforeUnmount(() => {
  window.clearTimeout(draftSaveTimer);
  if (turnstileWidgetId !== null && window.turnstile) {
    window.turnstile.remove(turnstileWidgetId);
  }
});

const invitationDraftPath = computed(() => {
  const path = window.location.pathname;
  return /^\/formularios\/convites\/[^/]+$/.test(path)
    ? `${path}/rascunho`
    : '';
});

const draftPayload = () => ({
  answers: answers.value,
  current_section_index: currentSectionIndex.value,
});

const draftSignature = () => JSON.stringify(draftPayload());

const saveDraft = async () => {
  if (!invitationDraftPath.value || isPrivatePreview.value || submitted.value)
    return;
  const signature = draftSignature();
  if (signature === lastSavedDraftSignature) return;

  try {
    const response = await fetch(invitationDraftPath.value, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        Accept: 'application/json',
      },
      body: JSON.stringify({ draft: draftPayload() }),
    });
    if (response.ok) lastSavedDraftSignature = signature;
  } catch {
    // Draft saving is best effort and must not interrupt completion.
  }
};

watch(
  [answers, currentSectionIndex],
  () => {
    if (!payload.value || isHydratingDraft) return;

    window.clearTimeout(draftSaveTimer);
    draftSaveTimer = window.setTimeout(saveDraft, 600);
  },
  { deep: true }
);

function loadTurnstile() {
  if (window.turnstile) return Promise.resolve(window.turnstile);

  return new Promise((resolve, reject) => {
    const existing = document.querySelector('[data-raevo-turnstile]');
    if (existing) {
      existing.addEventListener('load', () => resolve(window.turnstile), {
        once: true,
      });
      existing.addEventListener('error', reject, { once: true });
      return;
    }

    const script = document.createElement('script');
    script.src =
      'https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit';
    script.async = true;
    script.defer = true;
    script.dataset.raevoTurnstile = 'true';
    script.addEventListener('load', () => resolve(window.turnstile), {
      once: true,
    });
    script.addEventListener('error', reject, { once: true });
    document.head.appendChild(script);
  });
}

function privatePreviewPayload() {
  const previewId = window.location.pathname.match(
    /^\/formularios\/previsao\/([^/]+)$/
  )?.[1];
  if (!previewId) return null;

  try {
    const storedPreview = JSON.parse(
      window.localStorage.getItem(`${PREVIEW_STORAGE_PREFIX}${previewId}`)
    );
    if (!storedPreview?.payload || storedPreview.expiresAt < Date.now()) {
      window.localStorage.removeItem(`${PREVIEW_STORAGE_PREFIX}${previewId}`);
      return null;
    }

    return storedPreview.payload;
  } catch {
    return null;
  }
}

async function renderCaptcha() {
  if (!captchaRequired.value || !turnstileContainer.value) return;

  try {
    const turnstile = await loadTurnstile();
    turnstileWidgetId = turnstile.render(turnstileContainer.value, {
      sitekey: payload.value.form.captcha_site_key,
      callback: token => {
        captchaToken.value = token;
        captchaError.value = '';
      },
      'expired-callback': () => {
        captchaToken.value = '';
      },
      'error-callback': () => {
        captchaToken.value = '';
        captchaError.value = copy.value.captchaRequired;
      },
    });
  } catch {
    captchaError.value = copy.value.captchaRequired;
  }
}

onMounted(async () => {
  try {
    const previewPayload = privatePreviewPayload();
    if (previewPayload) {
      payload.value = previewPayload;
      isPrivatePreview.value = true;
    } else {
      const response = await fetch(window.location.pathname, {
        headers: { Accept: 'application/json' },
      });
      if (!response.ok) throw new Error('form_unavailable');
      payload.value = await response.json();
      if (payload.value.draft) {
        isHydratingDraft = true;
        answers.value = payload.value.draft.answers || {};
        currentSectionIndex.value = Math.min(
          Math.max(Number(payload.value.draft.current_section_index) || 0, 0),
          Math.max(sections.value.length - 1, 0)
        );
        lastSavedDraftSignature = draftSignature();
        await nextTick();
        isHydratingDraft = false;
      }
    }
    brandLogoFailed.value = false;
    document.title = payload.value.form.name;
    await nextTick();
    renderCaptcha();
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
  if (field.type === 'attachment') {
    return !attachments.value[field.key]?.length;
  }

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

function contentText(block) {
  return typeof block.content === 'string' ? block.content : '';
}

function isRichTextDocument(block) {
  return typeof block.content === 'object' && block.content !== null;
}

function selectedAttachments(field) {
  return attachments.value[field.key] || [];
}

function setAttachments(field, event) {
  attachments.value[field.key] = Array.from(event.target.files || []);
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

const appendAnswers = formData => {
  Object.entries(answers.value).forEach(([key, value]) => {
    if (Array.isArray(value)) {
      value.forEach(item =>
        formData.append(`submission[answers][${key}][]`, item)
      );
      return;
    }

    formData.append(`submission[answers][${key}]`, value);
  });
};

const appendAttachments = formData => {
  Object.entries(attachments.value).forEach(([key, files]) => {
    files.forEach(file =>
      formData.append(`submission[attachments][${key}][]`, file)
    );
  });
};

async function submitForm() {
  if (!validateCurrentSection()) return;
  if (isPrivatePreview.value) {
    errorMessage.value = copy.value.previewDescription;
    return;
  }
  if (captchaRequired.value && !captchaToken.value) {
    errorMessage.value = captchaError.value || copy.value.captchaRequired;
    return;
  }

  isSubmitting.value = true;
  errorMessage.value = '';
  invalidFieldKey.value = '';
  try {
    const formData = new FormData();
    appendAnswers(formData);
    formData.append('submission[website]', honeypot.value);
    formData.append('submission[captcha_token]', captchaToken.value);
    appendAttachments(formData);
    const response = await fetch(`${window.location.pathname}/respostas`, {
      method: 'POST',
      headers: { Accept: 'application/json' },
      body: formData,
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
        <img
          v-if="brandLogoUrl && !brandLogoFailed"
          :src="brandLogoUrl"
          :alt="brandName"
          class="size-11 shrink-0 rounded-md border border-n-slate-4 bg-n-solid-1 object-contain p-1"
          @error="brandLogoFailed = true"
        />
        <div
          v-else
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
          <p
            v-if="isPrivatePreview"
            data-test="public-form-preview-notice"
            class="mt-5 rounded border border-n-teal-6 bg-n-teal-2 px-3 py-2 text-sm text-n-teal-11"
          >
            <span class="font-semibold">{{ copy.preview }}</span>
            {{ copy.previewDescription }}
          </p>
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

          <div
            data-test="public-form-progress"
            class="mt-7 flex gap-1.5"
            role="progressbar"
            :aria-label="progressDescription"
            aria-valuemin="1"
            :aria-valuenow="currentSectionIndex + 1"
            :aria-valuemax="sections.length"
          >
            <span
              v-for="step in sections.length"
              :key="step"
              class="h-1.5 flex-1 rounded-full"
              :class="
                step <= currentSectionIndex + 1
                  ? appearance.progressFilled
                  : appearance.progressEmpty
              "
              aria-hidden="true"
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
            <template v-for="block in currentContentBlocks" :key="block.id">
              <h2
                v-if="block.type === 'heading'"
                data-test="public-form-content-heading"
                class="text-xl font-semibold leading-tight text-n-slate-12"
              >
                {{ contentText(block) }}
              </h2>
              <p
                v-else-if="
                  block.type === 'rich_text' && !isRichTextDocument(block)
                "
                data-test="public-form-content-text"
                class="whitespace-pre-line text-sm leading-6 text-n-slate-11"
              >
                {{ contentText(block) }}
              </p>
              <FormRichTextContent
                v-else-if="block.type === 'rich_text'"
                data-test="public-form-content-text"
                :content="block.content"
              />
              <figure v-else-if="block.type === 'image'" class="space-y-2">
                <img
                  data-test="public-form-content-image"
                  :src="block.url"
                  :alt="block.alt || ''"
                  class="max-h-80 w-full rounded object-cover"
                />
                <figcaption
                  v-if="block.caption"
                  class="text-xs leading-5 text-n-slate-10"
                >
                  {{ block.caption }}
                </figcaption>
              </figure>
              <hr
                v-else-if="block.type === 'divider'"
                class="border-0 border-t border-n-slate-4"
              />
            </template>
            <div
              data-test="public-form-fields"
              class="grid gap-6"
              :class="
                currentSection.layout === 'two_columns'
                  ? 'sm:grid-cols-2'
                  : 'grid-cols-1'
              "
            >
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
                    v-if="field.help_text && field.type !== 'signature'"
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

                  <div v-else-if="field.type === 'attachment'">
                    <input
                      :id="fieldId(field)"
                      type="file"
                      multiple
                      accept=".pdf,.jpg,.jpeg,.png,.heic,.heif,application/pdf,image/jpeg,image/png,image/heic,image/heif"
                      :required="field.required"
                      :aria-invalid="invalidFieldKey === field.key"
                      :aria-describedby="`${fieldId(field)}-attachment-help`"
                      class="block min-h-11 w-full cursor-pointer rounded border border-dashed border-n-slate-6 bg-n-slate-2 px-3 py-2 text-sm text-n-slate-11 file:mr-3 file:rounded file:border-0 file:bg-n-teal-3 file:px-3 file:py-1.5 file:text-sm file:font-medium file:text-n-teal-11 hover:file:bg-n-teal-4 focus:outline-none focus:ring-2 focus:ring-n-teal-6"
                      @change="setAttachments(field, $event)"
                    />
                    <p
                      :id="`${fieldId(field)}-attachment-help`"
                      class="mt-2 text-sm leading-5 text-n-slate-10"
                    >
                      {{ field.help_text || copy.attachmentHint }}
                    </p>
                    <ul
                      v-if="selectedAttachments(field).length"
                      class="mt-3 space-y-1 text-sm text-n-slate-11"
                      :aria-label="field.label"
                    >
                      <li
                        v-for="file in selectedAttachments(field)"
                        :key="`${file.name}-${file.lastModified}`"
                        class="flex items-center gap-2"
                      >
                        <FluentIcon
                          icon="document"
                          size="16"
                          aria-hidden="true"
                        />
                        <span class="min-w-0 break-all">{{ file.name }}</span>
                      </li>
                    </ul>
                  </div>

                  <template v-else-if="field.type === 'signature'">
                    <input
                      :id="fieldId(field)"
                      v-model="answers[field.key]"
                      type="text"
                      autocomplete="name"
                      :required="field.required"
                      :aria-invalid="invalidFieldKey === field.key"
                      :aria-describedby="`${fieldId(field)}-signature-help`"
                      class="min-h-11 w-full border-x-0 border-b border-t-0 border-n-slate-8 bg-transparent px-1 py-2 font-serif text-xl italic text-n-slate-12 outline-none transition focus:border-n-teal-9 focus:ring-0"
                    />
                    <p
                      :id="`${fieldId(field)}-signature-help`"
                      class="mt-2 text-sm leading-5 text-n-slate-10"
                    >
                      {{ field.help_text || copy.signatureHint }}
                    </p>
                  </template>

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
          </div>

          <div
            v-if="captchaRequired"
            data-test="public-form-captcha"
            class="mt-6"
          >
            <div ref="turnstileContainer" />
            <p
              v-if="captchaError"
              role="alert"
              class="mt-2 text-sm text-n-ruby-11"
            >
              {{ captchaError }}
            </p>
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
              :disabled="isSubmitting || (isPrivatePreview && isLastSection)"
              class="min-h-11 rounded px-5 text-sm font-medium text-n-solid-1 transition duration-200 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-offset-2 motion-reduce:transition-none disabled:cursor-not-allowed disabled:opacity-60"
              :class="appearance.submit"
            >
              {{
                isLastSection && isPrivatePreview
                  ? copy.previewSubmit
                  : isLastSection
                    ? copy.submit
                    : copy.continue
              }}
            </button>
          </footer>
          <a
            v-if="privacyPolicyUrl"
            data-test="public-form-privacy-policy"
            :href="privacyPolicyUrl"
            target="_blank"
            rel="noopener noreferrer"
            class="mt-5 inline-flex text-sm font-medium text-n-teal-11 underline underline-offset-4 outline-none focus-visible:ring-2 focus-visible:ring-n-teal-6"
          >
            {{ copy.privacyPolicy }}
          </a>
        </form>
      </div>
    </div>
  </section>
</template>
