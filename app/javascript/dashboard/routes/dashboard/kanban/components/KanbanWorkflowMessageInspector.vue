<script setup>
import { computed, nextTick, ref } from 'vue';
import RaevoField from 'dashboard/components-next/raevo/RaevoField.vue';

const props = defineProps({
  node: { type: Object, required: true },
  variables: { type: Array, default: () => [] },
  inboxes: { type: Array, default: () => [] },
  timezones: { type: Array, default: () => [] },
  // O painel pode abrir largo a pedido de quem configura. A largura é do
  // PAINEL, não da janela — por isso vem por prop e não por `sm:`.
  wide: { type: Boolean, default: false },
  // O que a automação respondeu por todos os nós de mensagem.
  messageDefaults: { type: Object, default: () => ({}) },
  t: { type: Function, required: true },
});

const emit = defineEmits(['update', 'attachment', 'remove-attachment']);

// Num painel de largura fixa, um breakpoint de ecrã é sempre a medida errada:
// `sm:grid-cols-2` punha dois selects lado a lado dentro de 320px, ~140px cada,
// em qualquer monitor. Quem manda é o painel.
const spanAll = computed(() => (props.wide ? 'col-span-2' : ''));

const contentInput = ref(null);
const variableMenuOpen = ref(false);
const variableQuery = ref('');
const data = computed(() => props.node.data);

/**
 * O que ESTE nó está a herdar da automação, neste momento.
 *
 * Sem isto a herança é mágica: o campo fica em branco, há um valor a actuar por
 * trás, e quem abre o nó não tem como saber. Um default invisível é pior do que
 * nenhum — foi exatamente assim que o silêncio em branco deixava passar
 * mensagem às 23h, só que ao contrário.
 *
 * Lista apenas o que está mesmo a herdar: o que o nó preenche não aparece.
 */
const ausente = value => value === undefined || value === null || value === '';

const herdadoDaAutomacao = computed(() => {
  const defaults = props.messageDefaults || {};
  const quietHours = defaults.quiet_hours || {};
  const nodeQuiet = data.value.quiet_hours || {};
  const partes = [];

  if (
    (quietHours.start || quietHours.end) &&
    ausente(nodeQuiet.start) &&
    ausente(nodeQuiet.end)
  ) {
    partes.push(
      props.t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.INHERITED_QUIET', {
        start: quietHours.start || '—',
        end: quietHours.end || '—',
      })
    );
  }

  if (
    !ausente(defaults.frequency_limit_hours) &&
    ausente(data.value.frequency_limit_hours)
  ) {
    partes.push(
      props.t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.INHERITED_FREQUENCY', {
        hours: defaults.frequency_limit_hours,
      })
    );
  }

  if (
    !ausente(defaults.opt_in_attribute_key) &&
    ausente(data.value.opt_in_attribute_key)
  ) {
    partes.push(
      props.t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.INHERITED_OPT_IN', {
        key: defaults.opt_in_attribute_key,
      })
    );
  }

  return partes;
});
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
  <section class="grid gap-3" :class="wide ? 'grid-cols-2' : ''">
    <div
      class="rounded-lg border border-n-weak bg-n-surface-2 p-3"
      :class="spanAll"
    >
      <p class="m-0 text-sm font-semibold text-n-slate-12">
        {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODES.MESSAGE') }}
      </p>
      <p class="m-0 mt-1 text-xs text-n-slate-11">
        {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.MESSAGE_VARIABLE_HINT') }}
      </p>
    </div>

    <div :class="wide ? 'contents' : 'grid gap-3'">
      <RaevoField
        :label="t('KANBAN.SETTINGS.SALES.SYSTEM_FIELDS.INBOX')"
        variant="select"
      >
        <template #default="{ controlClass, fieldId }">
          <select
            :id="fieldId"
            v-model="data.inbox_id"
            data-testid="kanban-workflow-message-inbox"
            :class="controlClass"
            @change="emit('update')"
          >
            <option value="">
              {{ t('KANBAN.NO_INBOX') }}
            </option>
            <option v-for="inbox in inboxes" :key="inbox.id" :value="inbox.id">
              {{ inbox.name }}
            </option>
          </select>
        </template>
      </RaevoField>
      <label
        v-if="!data.inbox_id"
        class="grid gap-1 text-xs font-medium text-n-slate-11"
      >
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
      <RaevoField :label="t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.OPT_IN')">
        <template #default="{ controlClass, fieldId }">
          <input
            :id="fieldId"
            v-model="data.opt_in_attribute_key"
            type="text"
            :placeholder="messageDefaults.opt_in_attribute_key || ''"
            :class="controlClass"
            @change="emit('update')"
          />
        </template>
      </RaevoField>
    </div>

    <div
      class="grid gap-2 rounded-lg border border-n-weak bg-n-surface-2 p-3"
      :class="spanAll"
    >
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

    <details
      class="rounded-md border border-n-weak bg-n-surface-2 p-3"
      :class="spanAll"
    >
      <summary class="cursor-pointer text-xs font-medium text-n-slate-12">
        {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.ADVANCED') }}
        <!--
          O resumo vive no `summary` de propósito: fechado é o estado normal
          desta secção, e um aviso que só aparece depois de abrir não avisa
          ninguém.
        -->
        <span
          v-if="herdadoDaAutomacao.length"
          data-testid="kanban-workflow-message-inherited"
          class="mt-1 block font-normal text-n-slate-11"
        >
          {{
            t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.INHERITED', {
              values: herdadoDaAutomacao.join(' · '),
            })
          }}
        </span>
      </summary>
      <div class="mt-3 grid gap-3" :class="wide ? 'grid-cols-2' : ''">
        <label
          class="grid gap-1 text-xs font-medium text-n-slate-11"
          :class="spanAll"
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
            :placeholder="
              messageDefaults.frequency_limit_hours === undefined
                ? ''
                : String(messageDefaults.frequency_limit_hours)
            "
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
