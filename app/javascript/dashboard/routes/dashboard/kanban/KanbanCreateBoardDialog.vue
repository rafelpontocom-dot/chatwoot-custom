<script setup>
import { nextTick, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  modelValue: {
    type: Boolean,
    default: false,
  },
  isCreating: {
    type: Boolean,
    default: false,
  },
  error: {
    type: String,
    default: '',
  },
});

const emit = defineEmits(['update:modelValue', 'create', 'close']);

const { t } = useI18n();

const boardName = ref('');
const templateKey = ref('whatsapp_sales');
const boardNameInput = ref(null);

const closeDialog = () => {
  boardName.value = '';
  templateKey.value = 'whatsapp_sales';
  emit('update:modelValue', false);
  emit('close');
};

const handleDialogKeydown = event => {
  if (event.key === 'Escape') {
    event.preventDefault();
    closeDialog();
    return;
  }

  if (event.key !== 'Tab') return;

  const focusableElements = [
    ...event.currentTarget.querySelectorAll(
      'input:not([disabled]), select:not([disabled]), button:not([disabled])'
    ),
  ];
  if (!focusableElements.length) return;

  const firstElement = focusableElements[0];
  const lastElement = focusableElements[focusableElements.length - 1];

  if (event.shiftKey && document.activeElement === firstElement) {
    event.preventDefault();
    lastElement.focus();
  } else if (!event.shiftKey && document.activeElement === lastElement) {
    event.preventDefault();
    firstElement.focus();
  }
};

const createBoard = () => {
  const name = boardName.value.trim();
  if (!name || props.isCreating) return;

  emit('create', { name, templateKey: templateKey.value });
};

watch(
  () => props.modelValue,
  isOpen => {
    if (isOpen) {
      nextTick(() => boardNameInput.value?.focus());
      return;
    }

    boardName.value = '';
    templateKey.value = 'whatsapp_sales';
  }
);
</script>

<template>
  <div>
    <div
      v-if="modelValue"
      class="fixed inset-0 z-50 flex items-center justify-center bg-n-slate-12/40 px-4 backdrop-blur-sm"
      data-testid="kanban-create-board-dialog"
      role="dialog"
      aria-modal="true"
      aria-labelledby="kanban-create-board-title"
      @keydown="handleDialogKeydown"
    >
      <form
        class="w-full max-w-sm rounded-lg border border-n-weak bg-n-surface-1 p-4 shadow-xl"
        @submit.prevent="createBoard"
      >
        <label
          id="kanban-create-board-title"
          for="kanban-create-board-name"
          class="mb-2 block text-sm font-medium text-n-slate-12"
        >
          {{ t('KANBAN.OVERVIEW.CREATE_BOARD_MODAL_TITLE') }}
        </label>
        <input
          id="kanban-create-board-name"
          ref="boardNameInput"
          v-model="boardName"
          type="text"
          class="w-full rounded-md border border-n-weak bg-n-surface-2 px-3 py-2 text-sm text-n-slate-12 outline-none placeholder:text-n-slate-10 focus:border-n-brand"
          :placeholder="t('KANBAN.ACTIONS.BOARD_NAME_PLACEHOLDER')"
          data-testid="kanban-create-board-name-input"
          @keydown.enter.prevent="createBoard"
        />
        <label class="mt-3 grid gap-1 text-sm font-medium text-n-slate-12">
          {{ t('KANBAN.BOARD_TEMPLATES.LABEL') }}
          <select
            v-model="templateKey"
            data-testid="kanban-create-board-template"
            class="h-10 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm font-normal text-n-slate-12 outline-none focus:border-n-brand"
          >
            <option value="whatsapp_sales">
              {{ t('KANBAN.BOARD_TEMPLATES.WHATSAPP_SALES') }}
            </option>
            <option value="clinic">
              {{ t('KANBAN.BOARD_TEMPLATES.CLINIC') }}
            </option>
            <option value="b2b">
              {{ t('KANBAN.BOARD_TEMPLATES.B2B') }}
            </option>
            <option value="blank">
              {{ t('KANBAN.BOARD_TEMPLATES.BLANK') }}
            </option>
          </select>
        </label>
        <p
          v-if="error"
          class="mt-2 text-sm text-n-ruby-11"
          role="alert"
          data-testid="kanban-create-board-error"
        >
          {{ error }}
        </p>
        <div class="mt-4 flex justify-end gap-2">
          <button
            type="submit"
            class="flex size-9 items-center justify-center rounded-md border border-n-weak bg-n-surface-2 text-n-slate-12 transition-colors hover:bg-n-teal-9 hover:text-white focus:outline-none focus:ring-2 focus:ring-n-teal-8 disabled:cursor-not-allowed disabled:opacity-50 disabled:hover:bg-n-surface-2 disabled:hover:text-n-slate-12"
            :disabled="!boardName.trim() || isCreating"
            :aria-label="t('KANBAN.ACTIONS.CONFIRM_CREATE_BOARD')"
            :title="t('KANBAN.ACTIONS.CONFIRM_CREATE_BOARD')"
            data-testid="kanban-create-board-confirm"
          >
            <i class="i-lucide-check size-4" />
          </button>
          <button
            type="button"
            class="flex size-9 items-center justify-center rounded-md border border-n-weak bg-n-surface-2 text-n-slate-12 transition-colors hover:bg-n-ruby-9 hover:text-white focus:outline-none focus:ring-2 focus:ring-n-ruby-8"
            :aria-label="t('KANBAN.ACTIONS.CANCEL_CREATE_BOARD')"
            :title="t('KANBAN.ACTIONS.CANCEL_CREATE_BOARD')"
            data-testid="kanban-create-board-cancel"
            @click="closeDialog"
          >
            <i class="i-lucide-x size-4" />
          </button>
        </div>
      </form>
    </div>
  </div>
</template>
