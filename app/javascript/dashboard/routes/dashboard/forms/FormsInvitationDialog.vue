<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import FormsAPI from 'dashboard/api/forms';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import { copyTextToClipboard } from 'shared/helpers/clipboard';

const props = defineProps({
  contact: { type: Object, required: true },
  kanbanCardId: { type: [Number, String], required: true },
  canSendToConversation: { type: Boolean, default: false },
});

const emit = defineEmits(['created', 'send']);

const { t } = useI18n();
const dialog = ref(null);
const templates = ref([]);
const templateId = ref('');
const expiresAt = ref('');
const maxUses = ref('1');
const invitationUrl = ref('');
const isLoading = ref(false);
const isSaving = ref(false);
const error = ref('');
const copied = ref(false);
const publishedTemplates = computed(() =>
  templates.value.filter(
    template =>
      ['commercial', 'sensitive_health'].includes(
        template.access_classification
      ) && template.active_version
  )
);
const selectedTemplate = computed(() =>
  publishedTemplates.value.find(
    template => String(template.id) === String(templateId.value)
  )
);
const selectedTemplateIsSensitiveHealth = computed(
  () => selectedTemplate.value?.access_classification === 'sensitive_health'
);
const canCreate = computed(
  () => templateId.value && Number(maxUses.value) > 0 && !isSaving.value
);

watch(selectedTemplateIsSensitiveHealth, isSensitiveHealth => {
  if (isSensitiveHealth) maxUses.value = '1';
});

const open = async () => {
  templateId.value = '';
  expiresAt.value = '';
  maxUses.value = '1';
  invitationUrl.value = '';
  error.value = '';
  copied.value = false;
  dialog.value?.open();
  isLoading.value = true;
  try {
    const { data } = await FormsAPI.getTemplates();
    templates.value = data;
    templateId.value = String(publishedTemplates.value[0]?.id || '');
  } catch (loadError) {
    error.value = loadError.response?.data?.message || t('FORMS.ERROR.LOAD');
  } finally {
    isLoading.value = false;
  }
};

async function createInvitation() {
  if (!canCreate.value) return;

  isSaving.value = true;
  error.value = '';
  try {
    const { data } = await FormsAPI.createInvitation(templateId.value, {
      invitation: {
        contact_id: props.contact.id,
        kanban_card_id: Number(props.kanbanCardId),
        expires_at: expiresAt.value || null,
        max_uses: selectedTemplateIsSensitiveHealth.value
          ? 1
          : Number(maxUses.value),
      },
    });
    invitationUrl.value = `${window.location.origin}/formularios/convites/${data.token}`;
    emit('created', data);
  } catch (saveError) {
    error.value = saveError.response?.data?.message || t('FORMS.ERROR.SAVE');
  } finally {
    isSaving.value = false;
  }
}

async function copyInvitationUrl() {
  if (!invitationUrl.value) return;

  await copyTextToClipboard(invitationUrl.value);
  copied.value = true;
  window.setTimeout(() => {
    copied.value = false;
  }, 2000);
}

function sendInvitationUrl() {
  if (!invitationUrl.value || !props.canSendToConversation) return;

  emit('send', invitationUrl.value);
}

defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialog"
    width="md"
    :title="t('FORMS.INVITATION.TITLE')"
    :description="t('FORMS.INVITATION.DESCRIPTION')"
    :confirm-button-label="t('FORMS.INVITATION.CREATE')"
    :disable-confirm-button="!canCreate || isLoading"
    :is-loading="isSaving"
    @confirm="createInvitation"
  >
    <p
      v-if="error"
      role="alert"
      class="rounded border border-n-ruby-6 bg-n-ruby-2 px-3 py-2 text-sm text-n-ruby-11"
    >
      {{ error }}
    </p>
    <p v-else-if="isLoading" class="text-sm text-n-slate-10">
      {{ t('KANBAN.OPPORTUNITY_DETAILS.LOADING') }}
    </p>
    <template v-else-if="!invitationUrl">
      <p v-if="!publishedTemplates.length" class="text-sm text-n-slate-10">
        {{ t('FORMS.INVITATION.EMPTY') }}
      </p>
      <template v-else>
        <label class="grid gap-1.5 text-sm font-medium text-n-slate-11">
          {{ t('FORMS.INVITATION.TEMPLATE') }}
          <select
            v-model="templateId"
            class="min-h-10 rounded border border-n-slate-5 bg-n-solid-1 px-3 text-n-slate-12 outline-none focus:border-n-teal-9 focus:ring-2 focus:ring-n-teal-6"
          >
            <option
              v-for="template in publishedTemplates"
              :key="template.id"
              :value="String(template.id)"
            >
              {{ template.name }}
            </option>
          </select>
        </label>
        <p
          v-if="selectedTemplateIsSensitiveHealth"
          class="mt-3 rounded border border-n-amber-6 bg-n-amber-2 px-3 py-2 text-sm text-n-amber-11"
        >
          {{ t('FORMS.INVITATION.SENSITIVE_HEALTH_NOTICE') }}
        </p>
        <div class="mt-4 grid gap-4 sm:grid-cols-2">
          <label class="grid gap-1.5 text-sm font-medium text-n-slate-11">
            {{ t('FORMS.INVITATION.EXPIRES_AT') }}
            <input
              v-model="expiresAt"
              type="datetime-local"
              class="min-h-10 rounded border border-n-slate-5 bg-n-solid-1 px-3 text-n-slate-12 outline-none focus:border-n-teal-9 focus:ring-2 focus:ring-n-teal-6"
            />
          </label>
          <label class="grid gap-1.5 text-sm font-medium text-n-slate-11">
            {{ t('FORMS.INVITATION.MAX_USES') }}
            <input
              v-model="maxUses"
              min="1"
              max="100"
              type="number"
              :disabled="selectedTemplateIsSensitiveHealth"
              class="min-h-10 rounded border border-n-slate-5 bg-n-solid-1 px-3 text-n-slate-12 outline-none focus:border-n-teal-9 focus:ring-2 focus:ring-n-teal-6"
            />
          </label>
        </div>
      </template>
    </template>
    <div v-else class="grid gap-3">
      <input
        :value="invitationUrl"
        readonly
        class="min-h-10 rounded border border-n-slate-5 bg-n-slate-2 px-3 text-sm text-n-slate-12 outline-none"
      />
      <Button
        size="sm"
        variant="faded"
        color="slate"
        :label="
          copied ? t('FORMS.INVITATION.COPIED') : t('FORMS.INVITATION.COPY')
        "
        @click="copyInvitationUrl"
      />
      <Button
        v-if="canSendToConversation"
        size="sm"
        :label="t('FORMS.INVITATION.SEND')"
        icon="i-lucide-send"
        @click="sendInvitationUrl"
      />
    </div>
  </Dialog>
</template>
