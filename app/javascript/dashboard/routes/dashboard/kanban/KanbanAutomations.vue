<script setup>
import { computed, onMounted, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import camelcaseKeys from 'camelcase-keys';

import { useAlert } from 'dashboard/composables';
import { useMapGetter } from 'dashboard/composables/store';
import KanbanBoardsAPI from 'dashboard/api/kanbanBoards';
import Button from 'dashboard/components-next/button/Button.vue';
import KanbanWorkflowBuilder from './components/KanbanWorkflowBuilder.vue';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const agents = useMapGetter('agents/getAgents');

const boardId = computed(() => Number(route.params.boardId));
const activeTab = ref('flows');
const isLoading = ref(false);
const isSaving = ref(false);
const error = ref('');
const rules = ref([]);
const cadences = ref([]);
const appointmentReminders = ref([]);
const settings = ref({});
const selectedRuleId = ref(null);
const showEditor = ref(false);

const blankAction = () => ({
  actionName: 'move_stage',
  stageId: '',
  ownerId: '',
  fieldKey: '',
  fieldValue: '',
  nextActionType: '',
  nextActionAt: '',
  nextActionNote: '',
});

const form = reactive({
  name: '',
  description: '',
  eventName: 'kanban.card.stage_changed',
  active: true,
  stageId: '',
  ownerId: '',
  fieldKey: '',
  fieldOperator: 'equals',
  fieldValue: '',
  actions: [blankAction()],
  flowDefinition: {},
});

const eventOptions = computed(() => [
  {
    value: 'kanban.card.created',
    label: t('KANBAN.SETTINGS.AUTOMATIONS.EVENTS.CREATED'),
  },
  {
    value: 'kanban.card.stage_changed',
    label: t('KANBAN.SETTINGS.AUTOMATIONS.EVENTS.STAGE_CHANGED'),
  },
  {
    value: 'kanban.card.next_action_completed',
    label: t('KANBAN.SETTINGS.AUTOMATIONS.EVENTS.NEXT_ACTION_COMPLETED'),
  },
  {
    value: 'kanban.card.won',
    label: t('KANBAN.SETTINGS.AUTOMATIONS.EVENTS.WON'),
  },
  {
    value: 'kanban.card.lost',
    label: t('KANBAN.SETTINGS.AUTOMATIONS.EVENTS.LOST'),
  },
]);

const automationTabs = computed(() => [
  { key: 'flows', label: t('KANBAN.AUTOMATIONS_WORKSPACE.TABS.FLOWS') },
  {
    key: 'cadences',
    label: t('KANBAN.AUTOMATIONS_WORKSPACE.TABS.CADENCES'),
  },
  {
    key: 'reminders',
    label: t('KANBAN.AUTOMATIONS_WORKSPACE.TABS.REMINDERS'),
  },
]);

const stages = computed(() => settings.value.stages || []);
const customFields = computed(
  () => settings.value.customFieldDefinitions || []
);
const nextActionTypes = computed(() => settings.value.nextActionTypes || []);
const agentOptions = computed(() =>
  agents.value.map(agent => ({
    value: agent.id,
    label: agent.name || agent.email,
  }))
);
const conditionFields = computed(() => [
  { key: 'subject', label: t('KANBAN.SETTINGS.SALES.SYSTEM_FIELDS.SUBJECT') },
  {
    key: 'amount_cents',
    label: t('KANBAN.SETTINGS.SALES.SYSTEM_FIELDS.AMOUNT'),
  },
  ...customFields.value.map(field => ({
    key: field.key,
    label: field.label || field.key,
    fieldType: field.fieldType,
    conditionOptions: field.options?.map(option => ({
      value: option,
      label: option,
    })),
  })),
]);
const dateFields = computed(() =>
  customFields.value.filter(field =>
    ['date', 'datetime'].includes(field.fieldType)
  )
);

const normalize = value => camelcaseKeys(value || {}, { deep: true });
const resetForm = () => {
  selectedRuleId.value = null;
  form.name = '';
  form.description = '';
  form.eventName = 'kanban.card.stage_changed';
  form.active = true;
  form.stageId = '';
  form.ownerId = '';
  form.fieldKey = '';
  form.fieldOperator = 'equals';
  form.fieldValue = '';
  form.flowDefinition = {};
  form.actions.splice(0, form.actions.length, blankAction());
};

const applyRule = rule => {
  const normalized = normalize(rule);
  const conditions = normalized.conditions || {};
  const field = conditions.fields?.[0] || {};
  selectedRuleId.value = normalized.id;
  form.name = normalized.name || '';
  form.description = normalized.description || '';
  form.eventName = normalized.eventName || 'kanban.card.stage_changed';
  form.active = normalized.active !== false;
  form.stageId = conditions.stageIds?.[0] || '';
  form.ownerId = conditions.ownerIds?.[0] || '';
  form.fieldKey = field.fieldKey || '';
  form.fieldOperator = field.operator || 'equals';
  form.fieldValue = field.value || '';
  form.flowDefinition = normalized.flowDefinition || {};
  form.actions.splice(0, form.actions.length, ...(normalized.actions || []));
};

const openNewFlow = () => {
  resetForm();
  activeTab.value = 'flows';
  showEditor.value = true;
};
const openRule = rule => {
  applyRule(rule);
  activeTab.value = 'flows';
  showEditor.value = true;
};
const closeEditor = () => {
  showEditor.value = false;
  resetForm();
};

const actionParams = action => {
  switch (action.actionName) {
    case 'move_stage':
      return { stage_id: Number(action.stageId) };
    case 'assign_owner':
      return { owner_id: Number(action.ownerId) };
    case 'set_next_action':
      return {
        next_action_type: action.nextActionType,
        next_action_at: action.nextActionAt || null,
        next_action_note: action.nextActionNote || null,
      };
    case 'set_field':
      return { field_key: action.fieldKey, value: action.fieldValue };
    default:
      return {};
  }
};

const payload = () => ({
  kanban_automation_rule: {
    name: form.name.trim(),
    description: form.description.trim() || null,
    event_name: form.eventName,
    active: form.active,
    conditions: {
      stage_ids: form.stageId ? [Number(form.stageId)] : [],
      owner_ids: form.ownerId ? [Number(form.ownerId)] : [],
      fields: form.fieldKey
        ? [
            {
              field_key: form.fieldKey,
              operator: form.fieldOperator,
              value: form.fieldValue,
            },
          ]
        : [],
    },
    actions: form.actions
      .filter(action => action.actionName)
      .map(action => ({
        action_name: action.actionName,
        action_params: actionParams(action),
      })),
    flow_definition: form.flowDefinition,
  },
});

const save = async () => {
  if (!form.name.trim() || isSaving.value) return;

  isSaving.value = true;
  error.value = '';
  try {
    const response = selectedRuleId.value
      ? await KanbanBoardsAPI.updateAutomationRule(
          boardId.value,
          selectedRuleId.value,
          payload()
        )
      : await KanbanBoardsAPI.createAutomationRule(boardId.value, payload());
    const saved = normalize(response.data);
    const index = rules.value.findIndex(rule => rule.id === saved.id);
    if (index < 0) rules.value.push(saved);
    else rules.value.splice(index, 1, saved);
    applyRule(saved);
    useAlert(t('KANBAN.SETTINGS.AUTOMATIONS.RULES.SAVE_SUCCESS'));
  } catch (saveError) {
    error.value =
      saveError?.response?.data?.message ||
      t('KANBAN.SETTINGS.AUTOMATIONS.RULES.SAVE_ERROR');
    useAlert(error.value);
  } finally {
    isSaving.value = false;
  }
};

const load = async () => {
  isLoading.value = true;
  error.value = '';
  try {
    const [
      settingsResponse,
      rulesResponse,
      cadencesResponse,
      remindersResponse,
    ] = await Promise.all([
      KanbanBoardsAPI.getSettings(boardId.value),
      KanbanBoardsAPI.getAutomationRules(boardId.value),
      KanbanBoardsAPI.getCadences(boardId.value),
      KanbanBoardsAPI.getAppointmentReminderRules(boardId.value),
    ]);
    settings.value = normalize(settingsResponse.data);
    rules.value = normalize(rulesResponse.data);
    cadences.value = normalize(cadencesResponse.data);
    appointmentReminders.value = normalize(remindersResponse.data);
  } catch (loadError) {
    error.value = t('KANBAN.SETTINGS.LOAD_ERROR');
  } finally {
    isLoading.value = false;
  }
};

const goToSettings = section =>
  router.push({
    name: 'kanban_board_settings',
    params: { accountId: route.params.accountId, boardId: boardId.value },
    query: { section },
  });

onMounted(load);
</script>

<template>
  <main
    data-testid="kanban-automations-workspace"
    class="flex h-full min-h-0 w-full flex-col bg-n-surface-1 text-n-slate-12"
  >
    <header
      class="flex flex-wrap items-center justify-between gap-3 border-b border-n-weak px-4 py-3 lg:px-6"
    >
      <div class="min-w-0">
        <button
          type="button"
          class="mb-1 inline-flex items-center gap-1 text-xs font-medium text-n-slate-11 hover:text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand"
          @click="
            router.push({
              name: 'kanban_board_show',
              params: { accountId: route.params.accountId, boardId },
            })
          "
        >
          <i class="i-lucide-arrow-left size-3" />
          {{ t('KANBAN.AUTOMATIONS_WORKSPACE.BACK') }}
        </button>
        <h1 class="m-0 text-lg font-semibold text-n-slate-12">
          {{ t('KANBAN.AUTOMATIONS_WORKSPACE.TITLE') }}
        </h1>
      </div>
      <Button
        v-if="!showEditor"
        type="button"
        data-testid="kanban-automations-new-flow"
        icon="i-lucide-plus"
        :label="t('KANBAN.AUTOMATIONS_WORKSPACE.NEW_FLOW')"
        color="blue"
        size="sm"
        @click="openNewFlow"
      />
      <div v-else class="flex items-center gap-2">
        <Button
          type="button"
          :label="t('KANBAN.ACTIONS.CANCEL')"
          color="slate"
          size="sm"
          @click="closeEditor"
        />
        <Button
          type="button"
          icon="i-lucide-save"
          :label="t('KANBAN.ACTIONS.SAVE')"
          color="blue"
          size="sm"
          :is-loading="isSaving"
          @click="save"
        />
      </div>
    </header>

    <div
      v-if="showEditor"
      data-testid="kanban-automation-editor"
      class="flex min-h-0 flex-1 flex-col"
    >
      <section
        class="grid gap-3 border-b border-n-weak bg-n-surface-2 px-4 py-3 lg:grid-cols-[minmax(0,1fr)_13rem_11rem_auto] lg:px-6"
      >
        <label class="grid gap-1 text-xs font-medium text-n-slate-11">
          {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.NAME') }}
          <input
            v-model="form.name"
            data-testid="kanban-automations-flow-name"
            type="text"
            class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
          />
        </label>
        <label class="grid gap-1 text-xs font-medium text-n-slate-11">
          {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.EVENT') }}
          <select
            v-model="form.eventName"
            class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
          >
            <option
              v-for="event in eventOptions"
              :key="event.value"
              :value="event.value"
            >
              {{ event.label }}
            </option>
          </select>
        </label>
        <label class="grid gap-1 text-xs font-medium text-n-slate-11">
          {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.STAGE') }}
          <select
            v-model="form.stageId"
            class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
          >
            <option value="">
              {{ t('KANBAN.AUTOMATIONS_WORKSPACE.ANY_STAGE') }}
            </option>
            <option v-for="stage in stages" :key="stage.id" :value="stage.id">
              {{ stage.name }}
            </option>
          </select>
        </label>
        <label
          class="flex items-end gap-2 pb-2 text-xs font-medium text-n-slate-11"
        >
          <input
            v-model="form.active"
            type="checkbox"
            class="size-4 rounded border-n-weak text-n-brand focus:ring-n-brand"
          />
          {{ t('KANBAN.AUTOMATIONS_WORKSPACE.ACTIVE') }}
        </label>
      </section>
      <KanbanWorkflowBuilder
        v-model="form.flowDefinition"
        class="min-h-0 flex-1 rounded-none border-x-0 border-b-0"
        :stages="stages"
        :agents="agentOptions"
        :custom-fields="customFields"
        :next-action-types="nextActionTypes"
        :condition-fields="conditionFields"
        :date-fields="dateFields"
        :cadences="cadences"
      />
      <p
        v-if="error"
        class="m-0 border-t border-n-weak px-4 py-2 text-sm text-n-ruby-11"
        role="alert"
      >
        {{ error }}
      </p>
    </div>

    <section v-else class="min-h-0 flex-1 overflow-y-auto px-4 py-4 lg:px-6">
      <div
        class="mb-4 flex w-fit items-center gap-1 rounded-md bg-n-surface-2 p-1"
        role="tablist"
      >
        <button
          v-for="tab in automationTabs"
          :key="tab.key"
          type="button"
          class="h-8 rounded px-3 text-sm font-medium focus:outline-none focus:ring-2 focus:ring-n-brand"
          :class="
            activeTab === tab.key
              ? 'bg-n-surface-1 text-n-slate-12 shadow-sm'
              : 'text-n-slate-11 hover:text-n-slate-12'
          "
          :aria-selected="activeTab === tab.key"
          role="tab"
          @click="activeTab = tab.key"
        >
          {{ tab.label }}
        </button>
      </div>

      <div v-if="isLoading" class="grid gap-2" aria-busy="true">
        <div
          v-for="item in 4"
          :key="item"
          class="h-16 animate-pulse rounded-md bg-n-surface-2"
        />
      </div>
      <template v-else-if="activeTab === 'flows'">
        <div v-if="rules.length" class="grid max-w-5xl gap-2">
          <article
            v-for="rule in rules"
            :key="rule.id"
            class="flex items-center justify-between gap-3 rounded-md border border-n-weak bg-n-surface-1 px-4 py-3"
          >
            <button
              type="button"
              class="min-w-0 text-left focus:outline-none focus:ring-2 focus:ring-n-brand"
              @click="openRule(rule)"
            >
              <p class="m-0 truncate text-sm font-medium text-n-slate-12">
                {{ rule.name }}
              </p>
              <p class="m-0 mt-1 text-xs text-n-slate-11">
                {{
                  eventOptions.find(item => item.value === rule.eventName)
                    ?.label
                }}
              </p>
            </button>
            <span
              class="shrink-0 rounded-full px-2 py-1 text-xs font-medium"
              :class="
                rule.active
                  ? 'bg-n-green-3 text-n-green-11'
                  : 'bg-n-slate-3 text-n-slate-11'
              "
            >
              {{
                rule.active
                  ? t('KANBAN.AUTOMATIONS_WORKSPACE.ACTIVE')
                  : t('KANBAN.AUTOMATIONS_WORKSPACE.DRAFT')
              }}
            </span>
          </article>
        </div>
        <div v-else class="grid max-w-xl justify-items-start gap-2 py-10">
          <i class="i-lucide-git-branch size-8 text-n-slate-10" />
          <h2 class="m-0 text-base font-semibold text-n-slate-12">
            {{ t('KANBAN.AUTOMATIONS_WORKSPACE.EMPTY_TITLE') }}
          </h2>
          <p class="m-0 text-sm text-n-slate-11">
            {{ t('KANBAN.AUTOMATIONS_WORKSPACE.EMPTY_DESCRIPTION') }}
          </p>
          <Button
            type="button"
            icon="i-lucide-plus"
            :label="t('KANBAN.AUTOMATIONS_WORKSPACE.NEW_FLOW')"
            color="blue"
            size="sm"
            @click="openNewFlow"
          />
        </div>
      </template>
      <template v-else>
        <div class="grid max-w-3xl gap-2">
          <article
            v-for="item in activeTab === 'cadences'
              ? cadences
              : appointmentReminders"
            :key="item.id"
            class="rounded-md border border-n-weak bg-n-surface-1 px-4 py-3"
          >
            <p class="m-0 text-sm font-medium text-n-slate-12">
              {{
                item.name ||
                item.triggerStageName ||
                t('KANBAN.AUTOMATIONS_WORKSPACE.UNTITLED')
              }}
            </p>
          </article>
          <p
            v-if="
              !(activeTab === 'cadences' ? cadences : appointmentReminders)
                .length
            "
            class="m-0 text-sm text-n-slate-11"
          >
            {{ t('KANBAN.AUTOMATIONS_WORKSPACE.NO_ITEMS') }}
          </p>
          <Button
            type="button"
            icon="i-lucide-settings-2"
            :label="t('KANBAN.AUTOMATIONS_WORKSPACE.MANAGE')"
            color="slate"
            size="sm"
            @click="goToSettings('automation')"
          />
        </div>
      </template>
    </section>
  </main>
</template>
