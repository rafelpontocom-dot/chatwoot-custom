<script setup>
import { computed, nextTick, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { OnClickOutside } from '@vueuse/components';
import Button from 'dashboard/components-next/button/Button.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import { useAlert } from 'dashboard/composables';
import { useAdmin } from 'dashboard/composables/useAdmin';
import { useMapGetter } from 'dashboard/composables/store';
import { findSnoozeTime } from 'dashboard/helper/snoozeHelpers';
import wootConstants from 'dashboard/constants/globals';
import { copyTextToClipboard } from 'shared/helpers/clipboard';
import BulkActionsAPI from 'dashboard/api/raevoConversationBulkActions';
import { useRaevoConversationSelectionShortcuts } from './useRaevoConversationSelectionShortcuts';

// RAEVO (17/10, 123jpnbcxh4) — seleção e ações em massa nas Conversas, proposta B
// aprovada pelo Pedro: a primeira linha da lista é «Selecionar todas», e as ações
// aparecem logo abaixo, no topo. A foto do contacto continua a selecionar uma a
// uma (isso é do cartão nativo). «Selecionar as N do filtro» age sobre o recorte
// inteiro, não só sobre as 25 carregadas — que era o limite da barra nativa.
const props = defineProps({
  conversationList: { type: Array, default: () => [] },
  // `display_id` das marcadas, como o `useBulkActions` nativo as guarda.
  selectedConversations: { type: Array, default: () => [] },
  // O recorte da lista — ver `raevoConversationBulkScope`.
  scope: { type: Object, default: () => ({}) },
});

const emit = defineEmits(['selectAllConversations', 'clear']);

const { t } = useI18n();
const { isAdmin } = useAdmin();
const labels = useMapGetter('labels/getLabels');
const agents = useMapGetter('agents/getAgents');
const teams = useMapGetter('teams/getTeams');
const accountId = useMapGetter('getCurrentAccountId');

const filterAll = ref(false);
const filterCount = ref(null);
const menuView = ref(null);
const labelQuery = ref('');
const pending = ref(null);
const busy = ref(false);
const confirmDialog = ref(null);
const menuRef = ref(null);

const loaded = computed(() => props.conversationList.length);

const marked = computed(() => props.selectedConversations.length);
const selectedCount = computed(() =>
  filterAll.value ? filterCount.value || 0 : marked.value
);
const allLoadedMarked = computed(
  () => loaded.value > 0 && marked.value === loaded.value
);
const someMarked = computed(() => marked.value > 0 && !allLoadedMarked.value);
const onlyOne = computed(() => !filterAll.value && marked.value === 1);
const offerFilter = computed(
  () =>
    allLoadedMarked.value &&
    !filterAll.value &&
    filterCount.value > loaded.value
);

const selectionLabel = computed(() =>
  selectedCount.value
    ? t(
        'RAEVO_CONVERSATION.BULK.SELECTED',
        { count: selectedCount.value },
        selectedCount.value
      )
    : t('RAEVO_CONVERSATION.BULK.SELECT_ALL')
);

const operationLabel = operation =>
  t(`RAEVO_CONVERSATION.BULK.OPERATIONS.${operation}`);

watch(marked, () => {
  if (!allLoadedMarked.value) filterAll.value = false;
});

// Só se pergunta ao servidor quantas são quando a página inteira já está
// marcada: é o único momento em que «as N do filtro» faz sentido oferecer.
watch(allLoadedMarked, async all => {
  if (!all) return;
  try {
    const { data } = await BulkActionsAPI.count(props.scope);
    filterCount.value = data.count;
  } catch {
    filterCount.value = null;
  }
});

const toggleAll = checked => {
  filterAll.value = false;
  emit('selectAllConversations', checked);
};

const clear = () => {
  filterAll.value = false;
  menuView.value = null;
  emit('clear');
};

useRaevoConversationSelectionShortcuts({
  conversationList: computed(() => props.conversationList),
  selectedConversations: computed(() => props.selectedConversations),
  clear,
  isMenuOpen: computed(() => Boolean(menuView.value)),
});

const closeMenu = () => {
  menuView.value = null;
  labelQuery.value = '';
};

const focusFirstMenuItem = async () => {
  await nextTick();
  menuRef.value?.querySelector('button:not([disabled]), input')?.focus();
};

const openMenu = view => {
  menuView.value = menuView.value === view ? null : view;
  if (menuView.value) focusFirstMenuItem();
};

const onMenuKeydown = event => {
  if (event.key === 'Escape') {
    closeMenu();
    return;
  }
  if (!['ArrowDown', 'ArrowUp'].includes(event.key)) return;
  const items = [...menuRef.value.querySelectorAll('button:not([disabled])')];
  const index = items.indexOf(document.activeElement);
  const step = event.key === 'ArrowDown' ? 1 : -1;
  items[(index + step + items.length) % items.length]?.focus();
  event.preventDefault();
};

const scopeToApply = () =>
  filterAll.value ? props.scope : { ids: props.selectedConversations };

const apply = async (operation, value = null) => {
  busy.value = true;
  try {
    const { data } = await BulkActionsAPI.apply({
      scope: scopeToApply(),
      operation,
      value,
    });
    let message = t(
      'RAEVO_CONVERSATION.BULK.DONE',
      { count: data.count },
      data.count
    );
    if (data.skipped) {
      message = `${message} ${t('RAEVO_CONVERSATION.BULK.SKIPPED', { count: data.skipped })}`;
    }
    useAlert(message);
    clear();
  } catch {
    useAlert(t('RAEVO_CONVERSATION.BULK.FAILED'));
  } finally {
    busy.value = false;
  }
};

// Excluir pede sempre confirmação; o resto só quando age sobre o filtro inteiro,
// porque aí o número já não é o que se vê no ecrã.
const run = (operation, value = null) => {
  closeMenu();
  if (operation === 'delete' || filterAll.value) {
    pending.value = { operation, value };
    confirmDialog.value?.open();
    return;
  }
  apply(operation, value);
};

const confirmPending = async () => {
  const { operation, value } = pending.value;
  confirmDialog.value?.close();
  pending.value = null;
  await apply(operation, value);
};

const confirmTitle = computed(() => {
  if (!pending.value) return '';
  if (pending.value.operation === 'delete') {
    return t(
      'RAEVO_CONVERSATION.BULK.CONFIRM_DELETE_TITLE',
      { count: selectedCount.value },
      selectedCount.value
    );
  }
  return t('RAEVO_CONVERSATION.BULK.CONFIRM_TITLE', {
    action: operationLabel(pending.value.operation),
    count: selectedCount.value,
  });
});

const confirmBody = computed(() =>
  pending.value?.operation === 'delete'
    ? t('RAEVO_CONVERSATION.BULK.CONFIRM_DELETE_BODY')
    : t('RAEVO_CONVERSATION.BULK.CONFIRM_BODY')
);

const snoozeOptions = computed(() => [
  {
    key: wootConstants.SNOOZE_OPTIONS.UNTIL_NEXT_REPLY,
    label: t('CONVERSATION.CARD_CONTEXT_MENU.SNOOZE.NEXT_REPLY'),
  },
  {
    key: wootConstants.SNOOZE_OPTIONS.UNTIL_TOMORROW,
    label: t('CONVERSATION.CARD_CONTEXT_MENU.SNOOZE.TOMORROW'),
  },
  {
    key: wootConstants.SNOOZE_OPTIONS.UNTIL_NEXT_WEEK,
    label: t('CONVERSATION.CARD_CONTEXT_MENU.SNOOZE.NEXT_WEEK'),
  },
]);

const snooze = key => run('snooze', findSnoozeTime(key) || null);

const priorityOptions = computed(() => [
  { key: null, label: t('CONVERSATION.PRIORITY.OPTIONS.NONE') },
  { key: 'urgent', label: t('CONVERSATION.PRIORITY.OPTIONS.URGENT') },
  { key: 'high', label: t('CONVERSATION.PRIORITY.OPTIONS.HIGH') },
  { key: 'medium', label: t('CONVERSATION.PRIORITY.OPTIONS.MEDIUM') },
  { key: 'low', label: t('CONVERSATION.PRIORITY.OPTIONS.LOW') },
]);

const filteredLabels = computed(() => {
  const query = labelQuery.value.trim().toLowerCase();
  return (labels.value || []).filter(
    label => !query || label.title.toLowerCase().includes(query)
  );
});

const pickerItems = computed(() => {
  const none = { key: null, label: t('RAEVO_CONVERSATION.BULK.NONE') };
  switch (menuView.value) {
    case 'priority':
      return priorityOptions.value;
    case 'add_labels':
    case 'remove_labels':
      return filteredLabels.value.map(label => ({
        key: label.title,
        label: label.title,
      }));
    case 'assign_agent':
      return [
        none,
        ...(agents.value || []).map(a => ({ key: a.id, label: a.name })),
      ];
    case 'assign_team':
      return [
        none,
        ...(teams.value || []).map(team => ({
          key: team.id,
          label: team.name,
        })),
      ];
    default:
      return [];
  }
});

const pick = key => {
  const operation = menuView.value;
  const isLabel = operation === 'add_labels' || operation === 'remove_labels';
  run(operation, isLabel ? [key] : key);
};

const conversationLink = () =>
  `${window.chatwootConfig?.hostURL || ''}/app/accounts/${accountId.value}/conversations/${props.selectedConversations[0]}`;

const openInNewTab = () => {
  closeMenu();
  window.open(conversationLink(), '_blank', 'noopener,noreferrer');
};

const copyLink = async () => {
  closeMenu();
  await copyTextToClipboard(conversationLink());
  useAlert(t('RAEVO_CONVERSATION.BULK.LINK_COPIED'));
};

// O mesmo agrupamento e os mesmos textos do clique direito numa conversa.
const moreGroups = computed(() => [
  {
    title: t('RAEVO_CONVERSATION.BULK.GROUPS.STATUS'),
    items: [
      {
        key: 'reopen',
        icon: 'i-lucide-rotate-ccw',
        action: () => run('reopen'),
      },
    ],
  },
  {
    title: t('RAEVO_CONVERSATION.BULK.GROUPS.READ'),
    items: [
      { key: 'read', icon: 'i-lucide-mail-open', action: () => run('read') },
      { key: 'unread', icon: 'i-lucide-mail', action: () => run('unread') },
    ],
  },
  {
    title: t('RAEVO_CONVERSATION.BULK.GROUPS.ORGANIZE'),
    items: [
      { key: 'priority', icon: 'i-lucide-flag', submenu: true },
      { key: 'add_labels', icon: 'i-lucide-tag', submenu: true },
      { key: 'remove_labels', icon: 'i-lucide-tag', submenu: true },
      { key: 'assign_agent', icon: 'i-lucide-user-plus', submenu: true },
      { key: 'assign_team', icon: 'i-lucide-users', submenu: true },
    ],
  },
  {
    title: t('RAEVO_CONVERSATION.BULK.GROUPS.ONE'),
    items: [
      {
        key: 'open_tab',
        icon: 'i-lucide-external-link',
        action: openInNewTab,
        onlyOne: true,
      },
      {
        key: 'copy_link',
        icon: 'i-lucide-link',
        action: copyLink,
        onlyOne: true,
      },
    ],
  },
  ...(isAdmin.value
    ? [
        {
          title: '',
          items: [
            {
              key: 'delete',
              icon: 'i-lucide-trash-2',
              action: () => run('delete'),
              danger: true,
            },
          ],
        },
      ]
    : []),
]);

const choose = item => {
  if (item.submenu) {
    menuView.value = item.key;
    focusFirstMenuItem();
    return;
  }
  item.action();
};
</script>

<template>
  <div
    v-if="loaded"
    data-testid="raevo-bulk-bar"
    class="relative border-b border-n-weak"
  >
    <div class="flex min-h-10 items-center gap-2 px-4 py-1.5">
      <label
        v-tooltip.bottom="t('RAEVO_CONVERSATION.BULK.SHORTCUTS_HINT')"
        class="flex cursor-pointer items-center gap-2 text-sm text-n-slate-12"
        data-testid="raevo-bulk-select-all"
        :aria-description="t('RAEVO_CONVERSATION.BULK.SHORTCUTS_HINT')"
      >
        <Checkbox
          :model-value="allLoadedMarked || filterAll"
          :indeterminate="someMarked"
          @update:model-value="toggleAll"
        />
        <span :class="selectedCount ? 'font-semibold' : 'text-n-slate-11'">
          {{ selectionLabel }}
        </span>
      </label>
      <Button
        v-if="selectedCount"
        :label="t('RAEVO_CONVERSATION.BULK.CLEAR')"
        link
        sm
        class="ms-auto"
        data-testid="raevo-bulk-clear"
        @click="clear"
      />
    </div>

    <p
      v-if="offerFilter || filterAll"
      class="mx-4 mb-2 rounded-lg bg-n-solid-amber px-3 py-2 text-xs text-n-amber-12"
      role="status"
    >
      <template v-if="filterAll">
        {{
          t('RAEVO_CONVERSATION.BULK.FILTER_SELECTED', { count: filterCount })
        }}
      </template>
      <template v-else>
        {{ t('RAEVO_CONVERSATION.BULK.PAGE_SELECTED', { count: loaded }) }}
        <button
          type="button"
          class="font-semibold underline underline-offset-2 outline-none focus-visible:ring-2 focus-visible:ring-n-brand"
          data-testid="raevo-bulk-select-filter"
          @click="filterAll = true"
        >
          {{
            t('RAEVO_CONVERSATION.BULK.SELECT_FILTER', { count: filterCount })
          }}
        </button>
      </template>
    </p>

    <OnClickOutside v-if="selectedCount" @trigger="closeMenu">
      <div
        class="flex flex-wrap items-center gap-1.5 px-4 pb-2"
        data-testid="raevo-bulk-actions"
      >
        <!--
          Sem ícone nos três: com ele, a 340px de lista, o «⋯» descia para uma
          segunda linha. O texto já diz a ação.
        -->
        <Button
          :label="t('RAEVO_CONVERSATION.BULK.RESOLVE')"
          slate
          sm
          :disabled="busy"
          data-testid="raevo-bulk-resolve"
          @click="run('resolve')"
        />
        <Button
          :label="t('RAEVO_CONVERSATION.BULK.SNOOZE')"
          slate
          sm
          :disabled="busy"
          aria-haspopup="menu"
          :aria-expanded="menuView === 'snooze'"
          data-testid="raevo-bulk-snooze"
          @click="openMenu('snooze')"
        />
        <Button
          :label="t('RAEVO_CONVERSATION.BULK.PENDING')"
          slate
          sm
          :disabled="busy"
          data-testid="raevo-bulk-pending"
          @click="run('pending')"
        />
        <!--
          Só ícone: com rótulo, as quatro ações não cabiam numa linha na largura
          da lista (340px) e a barra ficava com duas. Nome acessível e dica dizem
          o que é.
        -->
        <Button
          v-tooltip.top="t('RAEVO_CONVERSATION.BULK.MORE')"
          :aria-label="t('RAEVO_CONVERSATION.BULK.MORE')"
          icon="i-lucide-ellipsis"
          slate
          faded
          sm
          :disabled="busy"
          aria-haspopup="menu"
          :aria-expanded="Boolean(menuView) && menuView !== 'snooze'"
          data-testid="raevo-bulk-more"
          @click="openMenu('more')"
        />
      </div>

      <div
        v-if="menuView"
        ref="menuRef"
        role="menu"
        class="absolute start-4 top-full z-40 mt-1 grid max-h-[min(36rem,70vh)] w-64 gap-px overflow-y-auto rounded-xl bg-n-solid-2 p-1 shadow-lg ring-1 ring-n-weak"
        data-testid="raevo-bulk-menu"
        @keydown="onMenuKeydown"
      >
        <template v-if="menuView === 'snooze'">
          <button
            v-for="option in snoozeOptions"
            :key="option.key"
            type="button"
            role="menuitem"
            class="flex w-full items-center gap-2 rounded-md px-2 py-1.5 text-start text-sm text-n-slate-12 outline-none hover:bg-n-alpha-2 focus-visible:bg-n-alpha-2"
            @click="snooze(option.key)"
          >
            {{ option.label }}
          </button>
        </template>

        <template v-else-if="menuView === 'more'">
          <template v-for="(group, index) in moreGroups" :key="index">
            <div v-if="index" class="my-0.5 h-px bg-n-weak" role="separator" />
            <span
              v-if="group.title"
              class="px-2 pt-1.5 text-micro font-semibold uppercase tracking-[0.1em] text-n-slate-11"
            >
              {{ group.title }}
            </span>
            <button
              v-for="item in group.items"
              :key="item.key"
              type="button"
              role="menuitem"
              :disabled="item.onlyOne && !onlyOne"
              :data-testid="`raevo-bulk-item-${item.key}`"
              class="flex w-full items-center gap-2 rounded-md px-2 py-1.5 text-start text-sm outline-none hover:bg-n-alpha-2 focus-visible:bg-n-alpha-2 disabled:cursor-not-allowed disabled:text-n-slate-10"
              :class="item.danger ? 'text-n-ruby-11' : 'text-n-slate-12'"
              @click="choose(item)"
            >
              <span
                :class="item.icon"
                class="size-4 shrink-0"
                aria-hidden="true"
              />
              <span class="min-w-0 flex-1">{{ operationLabel(item.key) }}</span>
              <span
                v-if="item.onlyOne && !onlyOne"
                class="text-xs text-n-slate-10"
              >
                {{ t('RAEVO_CONVERSATION.BULK.ONLY_ONE') }}
              </span>
              <span
                v-else-if="item.submenu"
                class="i-lucide-chevron-right size-4 shrink-0 text-n-slate-10 rtl:rotate-180"
                aria-hidden="true"
              />
            </button>
          </template>
        </template>

        <template v-else>
          <button
            type="button"
            class="flex w-full items-center gap-2 rounded-md px-2 py-1.5 text-start text-sm font-semibold text-n-slate-12 outline-none hover:bg-n-alpha-2 focus-visible:bg-n-alpha-2"
            data-testid="raevo-bulk-back"
            @click="openMenu('more')"
          >
            <span
              class="i-lucide-chevron-left size-4 shrink-0 rtl:rotate-180"
              aria-hidden="true"
            />
            {{ operationLabel(menuView) }}
          </button>
          <input
            v-if="menuView === 'add_labels' || menuView === 'remove_labels'"
            v-model="labelQuery"
            type="search"
            :aria-label="t('RAEVO_CONVERSATION.BULK.LABEL_SEARCH')"
            :placeholder="t('RAEVO_CONVERSATION.BULK.LABEL_SEARCH')"
            class="mx-1 my-1 rounded-lg border border-n-weak bg-n-solid-1 px-2 py-1 text-sm text-n-slate-12 outline-none focus-visible:ring-2 focus-visible:ring-n-brand"
          />
          <button
            v-for="option in pickerItems"
            :key="String(option.key)"
            type="button"
            role="menuitem"
            :data-testid="`raevo-bulk-pick-${option.key}`"
            class="flex w-full items-center gap-2 rounded-md px-2 py-1.5 text-start text-sm text-n-slate-12 outline-none hover:bg-n-alpha-2 focus-visible:bg-n-alpha-2"
            @click="pick(option.key)"
          >
            <span class="min-w-0 break-words">{{ option.label }}</span>
          </button>
        </template>
      </div>
    </OnClickOutside>

    <Dialog
      ref="confirmDialog"
      :type="pending?.operation === 'delete' ? 'alert' : 'edit'"
      :title="confirmTitle"
      :description="confirmBody"
      :confirm-button-label="
        pending?.operation === 'delete'
          ? operationLabel('delete')
          : t('RAEVO_CONVERSATION.BULK.CONFIRM')
      "
      @confirm="confirmPending"
      @close="pending = null"
    />
  </div>
</template>
