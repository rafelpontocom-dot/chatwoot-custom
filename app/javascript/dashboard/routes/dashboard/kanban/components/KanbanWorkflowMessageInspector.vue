<script setup>
import { computed, nextTick, ref } from 'vue';

const props = defineProps({
  node: { type: Object, required: true },
  variables: { type: Array, default: () => [] },
  timezones: { type: Array, default: () => [] },
  t: { type: Function, required: true },
});

const emit = defineEmits(['update', 'attachment', 'remove-attachment']);
const contentInput = ref(null);
const variableMenuOpen = ref(false);
const variableQuery = ref('');
const data = computed(() => props.node.data);
const attachment = computed(() => data.value.message_attachment || {});
const attachmentUrl = computed(() => {
  if (!attachment.value.signed_id || !attachment.value.filename) return '';

  return `/rails/active_storage/blobs/redirect/${encodeURIComponent(attachment.value.signed_id)}/${encodeURIComponent(attachment.value.filename)}`;
});
const preview = computed(() =>
  (data.value.content || '')
    .replaceAll(
      '{{contact_name}}',
      props.t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.PREVIEW_CONTACT')
    )
    .replaceAll(
      '{{opportunity_subject}}',
      props.t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.PREVIEW_OPPORTUNITY')
    )
    .replaceAll(
      '{{opportunity_amount}}',
      props.t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.PREVIEW_AMOUNT')
    )
    .replaceAll(
      '{{finance_payment_link}}',
      props.t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.PREVIEW_PAYMENT_LINK')
    )
    .replaceAll(
      '{{finance_payment_amount}}',
      props.t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.PREVIEW_PAYMENT_AMOUNT')
    )
    .replaceAll(
      '{{finance_payment_due_on}}',
      props.t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.PREVIEW_PAYMENT_DUE_ON')
    )
);
const filteredVariables = computed(() => {
  const query = variableQuery.value.trim().toLocaleLowerCase();
  if (!query) return props.variables;

  return props.variables.filter(variable =>
    `${variable.label} ${variable.token}`.toLocaleLowerCase().includes(query)
  );
});

const insert = value => {
  const input = contentInput.value;
  const content = data.value.content || '';
  const start = input?.selectionStart ?? content.length;
  const end = input?.selectionEnd ?? content.length;
  data.value.content = `${content.slice(0, start)}${value}${content.slice(end)}`;
  variableMenuOpen.value = false;
  variableQuery.value = '';
  emit('update');

  nextTick(() => {
    input?.focus();
    input?.setSelectionRange(start + value.length, start + value.length);
  });
};
</script>

<template>
  <!-- eslint-disable vue/html-closing-bracket-newline, vue/multiline-html-element-content-newline -->
  <section class="grid gap-3">
    <div class="rounded-lg border border-n-weak bg-n-surface-2 p-3">
      <p class="m-0 text-sm font-semibold text-n-slate-12">
        {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODES.MESSAGE') }}
      </p>
      <p class="m-0 mt-1 text-xs text-n-slate-11">
        {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.MESSAGE_VARIABLE_HINT') }}
      </p>
    </div>

    <div class="grid gap-3 sm:grid-cols-2">
      <label class="grid gap-1 text-xs font-medium text-n-slate-11">
        {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.CHANNEL') }}
        <select
          v-model="data.channel"
          class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
          @change="emit('update')"
        >
          <option value="whatsapp">
            {{ t('KANBAN.SETTINGS.AUTOMATIONS.BIRTHDAY.WHATSAPP') }}
          </option>
          <option value="email">
            {{ t('KANBAN.SETTINGS.AUTOMATIONS.BIRTHDAY.EMAIL') }}
          </option>
        </select>
      </label>
      <label class="grid gap-1 text-xs font-medium text-n-slate-11">
        {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.OPT_IN') }}
        <input
          v-model="data.opt_in_attribute_key"
          type="text"
          class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
          @change="emit('update')"
        />
      </label>
    </div>

    <div class="grid gap-2 rounded-lg border border-n-weak bg-n-surface-2 p-3">
      <label class="grid gap-1 text-xs font-medium text-n-slate-11">
        {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.MESSAGE') }}
        <textarea
          ref="contentInput"
          v-model="data.content"
          rows="5"
          class="min-h-28 resize-y rounded-md border border-n-weak bg-n-surface-1 px-3 py-2 text-sm text-n-slate-12 outline-none focus:border-n-brand"
          :placeholder="
            t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.MESSAGE_PLACEHOLDER')
          "
          @change="emit('update')"
        />
      </label>
      <div class="flex flex-wrap items-center gap-1">
        <button
          v-for="emoji in ['🙂', '👋', '✅', '📅']"
          :key="emoji"
          :data-testid="
            emoji === '🙂' ? 'kanban-message-emoji-button' : undefined
          "
          type="button"
          class="flex p-0 size-8 items-center justify-center rounded-md text-sm hover:bg-n-surface-1 focus:outline-none focus:ring-2 focus:ring-n-brand"
          :aria-label="t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.INSERT_EMOJI')"
          @click="insert(emoji)"
        >
          {{ emoji }}
        </button>
        <div class="relative">
          <button
            type="button"
            data-testid="kanban-message-variable-button"
            class="flex p-0 size-8 items-center justify-center rounded-md text-n-slate-10 hover:bg-n-surface-1 hover:text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand"
            :aria-label="
              t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.INSERT_VARIABLE')
            "
            @click="variableMenuOpen = !variableMenuOpen"
          >
            <i class="i-lucide-braces size-4" aria-hidden="true" />
          </button>
          <div
            v-if="variableMenuOpen"
            data-testid="kanban-message-variable-menu"
            class="absolute bottom-full left-0 z-20 grid max-h-72 w-72 gap-1 overflow-y-auto rounded-md border border-n-weak bg-n-surface-1 p-1 shadow-xl"
          >
            <input
              v-model="variableQuery"
              type="search"
              class="h-8 rounded border border-n-weak bg-n-surface-2 px-2 text-sm text-n-slate-12 outline-none focus:border-n-brand"
              :placeholder="
                t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.SEARCH_VARIABLE')
              "
            />
            <button
              v-for="variable in filteredVariables"
              :key="variable.token"
              data-testid="kanban-message-variable-option"
              type="button"
              class="grid gap-0.5 rounded px-2 py-1.5 text-left hover:bg-n-surface-2 focus:outline-none focus:ring-2 focus:ring-n-brand"
              @click="insert(variable.token)"
            >
              <span class="text-sm font-medium text-n-slate-12">{{
                variable.label
              }}</span
              ><span class="font-mono text-xs text-n-slate-10">{{
                variable.token
              }}</span>
            </button>
          </div>
        </div>
        <label
          class="flex size-8 cursor-pointer items-center justify-center rounded-md text-n-slate-10 hover:bg-n-surface-1 focus-within:ring-2 focus-within:ring-n-brand"
          :aria-label="t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.UPLOAD_IMAGE')"
          ><i class="i-lucide-image-plus size-4" aria-hidden="true" /><input
            class="sr-only"
            type="file"
            accept="image/png,image/jpeg,image/webp,image/gif"
            @change="emit('attachment', $event)"
        /></label>
      </div>
    </div>

    <div
      data-testid="kanban-message-preview"
      class="grid gap-2 rounded-lg border border-n-weak bg-n-surface-2 p-3"
    >
      <p class="m-0 text-xs font-medium text-n-slate-11">
        {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.PREVIEW') }}
      </p>
      <img
        v-if="attachmentUrl"
        :src="attachmentUrl"
        :alt="t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.ATTACHMENT_PREVIEW')"
        class="max-h-56 w-auto rounded-md object-cover"
      />
      <div
        class="max-w-[85%] rounded-lg rounded-tl-sm bg-n-brand px-3 py-2 text-sm text-white"
      >
        {{ preview || t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.PREVIEW_EMPTY') }}
      </div>
      <button
        v-if="attachmentUrl"
        type="button"
        class="w-fit text-xs font-medium text-n-ruby-11 hover:underline focus:outline-none focus:ring-2 focus:ring-n-brand"
        @click="emit('remove-attachment')"
      >
        {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.REMOVE_IMAGE') }}
      </button>
    </div>

    <details class="rounded-md border border-n-weak bg-n-surface-2 p-3">
      <summary class="cursor-pointer text-xs font-medium text-n-slate-12">
        {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.ADVANCED') }}
      </summary>
      <div class="mt-3 grid gap-3">
        <label class="grid gap-1 text-xs font-medium text-n-slate-11"
          >{{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.MESSAGE_FAILURE_POLICY')
          }}<select
            v-model="data.failure_mode"
            data-testid="kanban-workflow-message-failure-mode"
            class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
            @change="emit('update')"
          >
            <option value="stop">
              {{
                t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.MESSAGE_FAILURE_STOP')
              }}
            </option>
            <option value="route">
              {{
                t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.MESSAGE_FAILURE_ROUTE')
              }}
            </option>
          </select></label
        >
        <template v-if="data.channel === 'whatsapp'"
          ><label class="grid gap-1 text-xs font-medium text-n-slate-11"
            >{{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.TEMPLATE_NAME')
            }}<input
              v-model="data.whatsapp_template_params.name"
              type="text"
              class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
              @change="emit('update')"
          /></label>
          <div class="grid grid-cols-2 gap-2">
            <label class="grid gap-1 text-xs font-medium text-n-slate-11"
              >{{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.TEMPLATE_LANGUAGE')
              }}<input
                v-model="data.whatsapp_template_params.language"
                type="text"
                class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                @change="emit('update')" /></label
            ><label class="grid gap-1 text-xs font-medium text-n-slate-11"
              >{{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.TEMPLATE_CATEGORY')
              }}<input
                v-model="data.whatsapp_template_params.category"
                type="text"
                class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                @change="emit('update')"
            /></label>
          </div>
          <label class="grid gap-1 text-xs font-medium text-n-slate-11"
            >{{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.TEMPLATE_NAMESPACE')
            }}<input
              v-model="data.whatsapp_template_params.namespace"
              type="text"
              class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
              @change="emit('update')" /></label
        ></template>
        <label class="grid gap-1 text-xs font-medium text-n-slate-11"
          >{{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.FREQUENCY_LIMIT')
          }}<input
            v-model="data.frequency_limit_hours"
            type="number"
            min="1"
            max="720"
            class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
            @change="emit('update')"
        /></label>
        <div class="grid grid-cols-2 gap-2">
          <label class="grid gap-1 text-xs font-medium text-n-slate-11"
            >{{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.QUIET_START')
            }}<input
              v-model="data.quiet_hours.start"
              type="time"
              class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
              @change="emit('update')" /></label
          ><label class="grid gap-1 text-xs font-medium text-n-slate-11"
            >{{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.QUIET_END')
            }}<input
              v-model="data.quiet_hours.end"
              type="time"
              class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
              @change="emit('update')"
          /></label>
        </div>
        <label class="grid gap-1 text-xs font-medium text-n-slate-11"
          >{{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.QUIET_TIMEZONE')
          }}<select
            v-model="data.quiet_hours.timezone"
            class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
            @change="emit('update')"
          >
            <option
              v-for="timezone in timezones"
              :key="timezone.value"
              :value="timezone.value"
            >
              {{ timezone.label }}
            </option>
          </select></label
        >
      </div>
    </details>
  </section>
</template>
