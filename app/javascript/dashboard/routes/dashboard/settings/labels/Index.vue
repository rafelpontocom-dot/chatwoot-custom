<script setup>
import { useAlert } from 'dashboard/composables';
import { computed, onBeforeMount, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStoreGetters, useStore } from 'dashboard/composables/store';
import { useAdmin } from 'dashboard/composables/useAdmin';
import { picoSearch } from '@chatwoot/pico-search';

import AddLabel from './AddLabel.vue';
import EditLabel from './EditLabel.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import {
  BaseTable,
  BaseTableRow,
  BaseTableCell,
} from 'dashboard/components-next/table';

const getters = useStoreGetters();
const store = useStore();
const { t } = useI18n();

const loading = ref({});
const showAddPopup = ref(false);
const showEditPopup = ref(false);
const showDeleteConfirmationPopup = ref(false);
const selectedLabel = ref({});
const searchQuery = ref('');

const records = computed(() => getters['labels/getLabels'].value);

// RAEVO (08/10, cartão 123jpnbcb5p). O agente entra aqui para gerir as SUAS:
// a lista já vem filtrada pelo servidor (as de todos, as dos times dele e as
// pessoais dele), e só nas pessoais dele há editar e apagar — o mesmo que o
// `LabelPolicy` deixa. Reordenar mexe na lista de toda a conta: só o admin.
const { isAdmin } = useAdmin();
const currentUserId = computed(() => getters.getCurrentUserID.value);
const canManage = label =>
  isAdmin.value ||
  (label.visibility === 'personal' &&
    Number(label.created_by_id) === Number(currentUserId.value));

// Quem vê cada etiqueta, por extenso e com ícone: a cor sozinha não diz nada.
const teams = computed(() => getters['teams/getTeams'].value || []);
const visibilityOf = label => {
  if (label.visibility === 'personal') {
    return {
      icon: 'i-lucide-lock',
      text: t('LABEL_MGMT.FORM.VISIBILITY.PERSONAL'),
    };
  }
  if (label.visibility === 'team') {
    const team = teams.value.find(item => item.id === label.team_id);
    return {
      icon: 'i-lucide-users',
      text: t('LABEL_MGMT.LIST.VISIBILITY_TEAM', {
        team: team?.name || label.team_id,
      }),
    };
  }
  return {
    icon: 'i-lucide-globe',
    text: t('LABEL_MGMT.FORM.VISIBILITY.GLOBAL'),
  };
};

const filteredRecords = computed(() => {
  const query = searchQuery.value.trim();
  if (!query) return records.value;
  return picoSearch(records.value, query, [
    { name: 'title', weight: 4 },
    'description',
  ]);
});
const uiFlags = computed(() => getters['labels/getUIFlags'].value);

const deleteMessage = computed(() => ` ${selectedLabel.value.title}?`);

const openAddPopup = () => {
  showAddPopup.value = true;
};
const hideAddPopup = () => {
  showAddPopup.value = false;
};

const openEditPopup = response => {
  showEditPopup.value = true;
  selectedLabel.value = response;
};
const hideEditPopup = () => {
  showEditPopup.value = false;
};

const openDeletePopup = response => {
  showDeleteConfirmationPopup.value = true;
  selectedLabel.value = response;
};
const closeDeletePopup = () => {
  showDeleteConfirmationPopup.value = false;
};

const deleteLabel = async id => {
  try {
    await store.dispatch('labels/delete', id);
    useAlert(t('LABEL_MGMT.DELETE.API.SUCCESS_MESSAGE'));
  } catch (error) {
    const errorMessage =
      error?.message || t('LABEL_MGMT.DELETE.API.ERROR_MESSAGE');
    useAlert(errorMessage);
  } finally {
    loading.value[selectedLabel.value.id] = false;
  }
};

const confirmDeletion = () => {
  loading.value[selectedLabel.value.id] = true;
  closeDeletePopup();
  deleteLabel(selectedLabel.value.id);
};

// Reordenar sobre uma lista filtrada trocaria a etiqueta com uma vizinha que
// não se vê, por isso os botões só valem com a pesquisa vazia.
const canReorder = computed(
  () => !searchQuery.value.trim() && !uiFlags.value.isUpdating
);

const moveLabel = async (from, to) => {
  const labelIds = records.value.map(label => label.id);
  const [labelId] = labelIds.splice(from, 1);
  labelIds.splice(to, 0, labelId);

  try {
    await store.dispatch('labels/reorder', labelIds);
  } catch (error) {
    useAlert(t('LABEL_MGMT.REORDER.ERROR_MESSAGE'));
  }
};

// RAEVO (08/10, 123jpnbc243): além das setas, arrasta-se a linha. As setas
// ficam: são a alternativa de teclado, e o arrastar nativo não serve ao toque.
// `dropIndex` é o lugar ENTRE linhas onde a etiqueta cai (0 = antes da primeira).
const canDrag = computed(() => isAdmin.value && canReorder.value);
const draggedIndex = ref(null);
const dropIndex = ref(null);
const resetDrag = () => {
  draggedIndex.value = null;
  dropIndex.value = null;
};
const onDragStart = (event, index) => {
  draggedIndex.value = index;
  event.dataTransfer.effectAllowed = 'move';
  // O Firefox só começa a arrastar com dados no dataTransfer.
  event.dataTransfer.setData('text/plain', String(index));
};
const onDragOver = (event, index) => {
  if (draggedIndex.value === null) return;
  event.preventDefault();
  const { top, height } = event.currentTarget.getBoundingClientRect();
  dropIndex.value = event.clientY < top + height / 2 ? index : index + 1;
};
const onDrop = () => {
  const from = draggedIndex.value;
  const gap = dropIndex.value;
  resetDrag();
  if (from === null || gap === null) return;

  const to = gap > from ? gap - 1 : gap;
  if (to !== from) moveLabel(from, to);
};
// Cair por cima de si própria, ou logo a seguir, não muda nada: sem linha.
const showsDropLineAt = gap =>
  dropIndex.value === gap &&
  gap !== draggedIndex.value &&
  gap !== draggedIndex.value + 1;

const tableHeaders = computed(() => {
  return [
    t('LABEL_MGMT.LIST.TABLE_HEADER.NAME'),
    t('LABEL_MGMT.LIST.TABLE_HEADER.DESCRIPTION'),
    t('LABEL_MGMT.LIST.TABLE_HEADER.COLOR'),
    t('LABEL_MGMT.LIST.TABLE_HEADER.ACTION'),
  ];
});

onBeforeMount(() => {
  store.dispatch('labels/get');
  store.dispatch('teams/get');
});
</script>

<template>
  <SettingsLayout
    :is-loading="uiFlags.isFetching"
    :loading-message="$t('LABEL_MGMT.LOADING')"
    :no-records-found="!records.length"
    :no-records-message="$t('LABEL_MGMT.LIST.404')"
  >
    <template #header>
      <BaseSettingsHeader
        v-model:search-query="searchQuery"
        :title="$t('LABEL_MGMT.HEADER')"
        :description="$t('LABEL_MGMT.DESCRIPTION')"
        :link-text="$t('LABEL_MGMT.LEARN_MORE')"
        :search-placeholder="$t('LABEL_MGMT.SEARCH_PLACEHOLDER')"
        feature-name="labels"
      >
        <template v-if="records?.length" #count>
          <span class="text-body-main text-n-slate-11">
            {{ $t('LABEL_MGMT.COUNT', { n: records.length }) }}
          </span>
        </template>
        <template #actions>
          <Button
            :label="$t('LABEL_MGMT.HEADER_BTN_TXT')"
            size="sm"
            @click="openAddPopup"
          />
        </template>
      </BaseSettingsHeader>
    </template>
    <template #body>
      <BaseTable
        :headers="tableHeaders"
        :items="filteredRecords"
        :no-data-message="
          searchQuery ? $t('LABEL_MGMT.NO_RESULTS') : $t('LABEL_MGMT.LIST.404')
        "
      >
        <template #row="{ items }">
          <BaseTableRow
            v-for="(label, index) in items"
            :key="label.title"
            :item="label"
            :data-testid="`label-row-${label.title}`"
            :draggable="canDrag ? 'true' : 'false'"
            :class="{
              'cursor-grab': canDrag,
              'opacity-50': draggedIndex === index,
              '!border-t-2 !border-t-n-brand': showsDropLineAt(index),
              '!border-b-2 !border-b-n-brand':
                index === items.length - 1 && showsDropLineAt(items.length),
            }"
            @dragstart="onDragStart($event, index)"
            @dragover="onDragOver($event, index)"
            @drop.prevent="onDrop"
            @dragend="resetDrag"
          >
            <template #default>
              <!--
                RAEVO: quem vê vai por baixo do nome, não em coluna. Em coluna,
                a 390px empurrava o editar/apagar do agente para fora do ecrã.
              -->
              <BaseTableCell>
                <span
                  v-if="canDrag"
                  v-tooltip.top="$t('LABEL_MGMT.REORDER.DRAG_HINT')"
                  aria-hidden="true"
                  class="i-lucide-grip-vertical size-3.5 me-1 align-middle text-n-slate-10"
                />
                <span class="text-body-main text-n-slate-12">
                  {{ label.title }}
                </span>
                <span
                  :data-testid="`label-visibility-${label.title}`"
                  class="flex items-center gap-1 mt-0.5 text-xs text-n-slate-11"
                >
                  <span
                    aria-hidden="true"
                    class="size-3 shrink-0"
                    :class="visibilityOf(label).icon"
                  />
                  {{ visibilityOf(label).text }}
                </span>
              </BaseTableCell>

              <BaseTableCell>
                <span class="text-body-main text-n-slate-11">
                  {{ label.description }}
                </span>
              </BaseTableCell>

              <BaseTableCell>
                <div class="flex items-center">
                  <span
                    class="w-4 h-4 ltr:mr-2 rtl:ml-2 border border-solid rounded border-n-weak"
                    :style="{ backgroundColor: label.color }"
                  />
                  <span class="text-body-main text-n-slate-12">
                    {{ label.color }}
                  </span>
                </div>
              </BaseTableCell>

              <BaseTableCell align="end">
                <div class="flex gap-3 justify-end flex-shrink-0">
                  <Button
                    v-if="isAdmin"
                    v-tooltip.top="
                      canReorder
                        ? $t('LABEL_MGMT.REORDER.MOVE_UP')
                        : $t('LABEL_MGMT.REORDER.SEARCH_HINT')
                    "
                    :aria-label="$t('LABEL_MGMT.REORDER.MOVE_UP')"
                    icon="i-lucide-arrow-up"
                    slate
                    sm
                    :disabled="!canReorder || index === 0"
                    @click="moveLabel(index, index - 1)"
                  />
                  <Button
                    v-if="isAdmin"
                    v-tooltip.top="
                      canReorder
                        ? $t('LABEL_MGMT.REORDER.MOVE_DOWN')
                        : $t('LABEL_MGMT.REORDER.SEARCH_HINT')
                    "
                    :aria-label="$t('LABEL_MGMT.REORDER.MOVE_DOWN')"
                    icon="i-lucide-arrow-down"
                    slate
                    sm
                    :disabled="!canReorder || index === items.length - 1"
                    @click="moveLabel(index, index + 1)"
                  />
                  <Button
                    v-if="canManage(label)"
                    v-tooltip.top="$t('LABEL_MGMT.FORM.EDIT')"
                    :data-testid="`label-edit-${label.title}`"
                    icon="i-woot-edit-pen"
                    slate
                    sm
                    :is-loading="loading[label.id]"
                    @click="openEditPopup(label)"
                  />
                  <Button
                    v-if="canManage(label)"
                    v-tooltip.top="$t('LABEL_MGMT.FORM.DELETE')"
                    :data-testid="`label-delete-${label.title}`"
                    icon="i-woot-bin"
                    slate
                    sm
                    class="hover:enabled:text-n-ruby-11 hover:enabled:bg-n-ruby-2"
                    :is-loading="loading[label.id]"
                    @click="openDeletePopup(label)"
                  />
                </div>
              </BaseTableCell>
            </template>
          </BaseTableRow>
        </template>
      </BaseTable>
    </template>

    <woot-modal v-model:show="showAddPopup" :on-close="hideAddPopup">
      <AddLabel @close="hideAddPopup" />
    </woot-modal>

    <woot-modal v-model:show="showEditPopup" :on-close="hideEditPopup">
      <EditLabel :selected-response="selectedLabel" @close="hideEditPopup" />
    </woot-modal>

    <woot-delete-modal
      v-model:show="showDeleteConfirmationPopup"
      :on-close="closeDeletePopup"
      :on-confirm="confirmDeletion"
      :title="$t('LABEL_MGMT.DELETE.CONFIRM.TITLE')"
      :message="$t('LABEL_MGMT.DELETE.CONFIRM.MESSAGE')"
      :message-value="deleteMessage"
      :confirm-text="$t('LABEL_MGMT.DELETE.CONFIRM.YES')"
      :reject-text="$t('LABEL_MGMT.DELETE.CONFIRM.NO')"
    />
  </SettingsLayout>
</template>
