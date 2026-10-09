<script setup>
import { computed, nextTick, ref, useId, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import camelcaseKeys from 'camelcase-keys';
import KanbanBoardsAPI from 'dashboard/api/kanbanBoards';
import ContactAPI from 'dashboard/api/contacts';
import { useStore } from 'dashboard/composables/store';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import RaevoField from 'dashboard/components-next/raevo/RaevoField.vue';
import {
  emptyRequiredFieldValue,
  isRequiredFieldEmpty,
  mergeRequiredFields,
  requiredFieldsForStage,
} from 'dashboard/helper/kanbanRequiredFields';
import KanbanRequiredFields from './KanbanRequiredFields.vue';

// RAEVO (09/10, 123jpnbcb5n) — nova oportunidade a partir do contato, sobre a
// maquete aprovada. O contato vem da página; a caixa de entrada por omissão é a
// da última conversa dele (escolha de 08/10). Grava pela criação manual do
// Pipeline, que já valida caixa, âmbito do funil e campos obrigatórios, e liga
// a oportunidade à conversa mais recente daquela caixa.
//
// Não usa o `Dialog` do Chatwoot de propósito: ele teleporta-se para o <body>, e
// no telemóvel o painel do contato é uma gaveta que fecha a qualquer clique fora
// de `#contact-sidebar-content` (ContactsDetailsLayout, nativo). O primeiro
// toque no diálogo fechava a gaveta e desmontava o diálogo com ela — criar era
// impossível. Um <dialog> nativo aberto com `showModal()` fica na camada de topo,
// por cima de tudo, mas no DOM continua dentro da gaveta.
const props = defineProps({
  contactId: { type: [Number, String], required: true },
  contactName: { type: String, default: '' },
});

const emit = defineEmits(['created']);

const { t } = useI18n();
const store = useStore();

const dialog = ref(null);
const titleId = useId();
// Como no `Dialog` do Chatwoot, o conteúdo só existe aberto: a página do
// contato monta o painel duas vezes (coluna e gaveta do telemóvel).
const aberto = ref(false);
const boards = ref([]);
const stages = ref([]);
const boardFieldDefinitions = ref([]);
const inboxes = ref([]);
const inboxDaUltimaConversa = ref(false);
const boardId = ref('');
const stageId = ref('');
const subject = ref('');
const amount = ref('');
const inboxId = ref('');
const requiredFieldDefinitions = ref([]);
const requiredFieldValues = ref({});
const isLoading = ref(false);
const isCreating = ref(false);
const loadError = ref('');
const createError = ref('');

const normalizeCollection = response =>
  response.data?.payload || response.data || [];
const ativos = lista => lista.filter(item => item.active !== false);

// «1.200,50», «1200,5», «1.200» (milhar à brasileira) e «1200.50» dão o mesmo
// número; vírgula e ponto juntos são milhar e decimal.
const valorEmCentavos = texto => {
  const limpo = String(texto || '').replace(/[^\d.,]/g, '');
  if (!limpo) return null;
  let normalizado = limpo;
  if (limpo.includes(',')) {
    normalizado = limpo.replace(/\./g, '').replace(',', '.');
  } else if (/^\d{1,3}(\.\d{3})+$/.test(limpo)) {
    normalizado = limpo.replace(/\./g, '');
  }
  const numero = Number(normalizado);
  return Number.isNaN(numero) ? null : Math.round(numero * 100);
};

const centavos = computed(() => valorEmCentavos(amount.value));
const valorInvalido = computed(
  () => amount.value.trim().length > 0 && centavos.value === null
);
const camposPorPreencher = computed(() =>
  requiredFieldDefinitions.value.some(definition =>
    isRequiredFieldEmpty(requiredFieldValues.value[definition.key])
  )
);
const podeCriar = computed(
  () =>
    boardId.value &&
    stageId.value &&
    inboxId.value &&
    subject.value.trim() &&
    !valorInvalido.value &&
    !camposPorPreencher.value &&
    !isCreating.value
);

// Mudar de etapa troca os campos, mas guarda o que já foi escrito nos que ficam.
watch([stageId, boardFieldDefinitions], () => {
  const definicoes = requiredFieldsForStage(
    boardFieldDefinitions.value,
    stageId.value
  );
  requiredFieldDefinitions.value = definicoes;
  requiredFieldValues.value = Object.fromEntries(
    definicoes.map(definition => [
      definition.key,
      requiredFieldValues.value[definition.key] ??
        emptyRequiredFieldValue(definition),
    ])
  );
});

const carregarEtapas = async id => {
  stages.value = [];
  stageId.value = '';
  boardFieldDefinitions.value = [];
  if (!id) return;
  const { data } = await KanbanBoardsAPI.showBoard(id);
  stages.value = ativos(data?.stages || []);
  boardFieldDefinitions.value = data?.custom_field_definitions || [];
  stageId.value = stages.value[0]?.id || '';
};

// A conversa mais recente vem primeiro; sem conversas, as caixas onde o
// contato existe.
const carregarCaixas = async () => {
  const nomeDe = id =>
    store.getters['inboxes/getInboxById']?.(id)?.name ||
    t('KANBAN.CONTACT_OPPORTUNITY.INBOX_FALLBACK', { id });
  const {
    data: { payload: conversas = [] },
  } = await ContactAPI.getConversations(props.contactId);
  const vistos = new Map();
  camelcaseKeys(conversas || [], { deep: true }).forEach(conversa => {
    if (conversa.inboxId && !vistos.has(conversa.inboxId)) {
      vistos.set(conversa.inboxId, {
        id: conversa.inboxId,
        name: nomeDe(conversa.inboxId),
      });
    }
  });
  inboxDaUltimaConversa.value = vistos.size > 0;
  if (!vistos.size) {
    const {
      data: { payload: contactaveis = [] },
    } = await ContactAPI.getContactableInboxes(props.contactId);
    (contactaveis || []).forEach(({ inbox }) =>
      vistos.set(inbox.id, { id: inbox.id, name: inbox.name })
    );
  }
  inboxes.value = Array.from(vistos.values());
  inboxId.value = inboxes.value[0]?.id || '';
};

const open = async () => {
  boards.value = [];
  boardId.value = '';
  subject.value = props.contactName;
  amount.value = '';
  createError.value = '';
  loadError.value = '';
  aberto.value = true;
  dialog.value?.showModal();
  isLoading.value = true;
  try {
    const [respostaFunis] = await Promise.all([
      KanbanBoardsAPI.getBoards(),
      carregarCaixas(),
    ]);
    boards.value = ativos(normalizeCollection(respostaFunis));
    boardId.value = boards.value[0]?.id || '';
    await carregarEtapas(boardId.value);
  } catch {
    loadError.value = t('KANBAN.CONTACT_OPPORTUNITY.LOAD_ERROR');
  } finally {
    isLoading.value = false;
  }
};

const fechar = () => dialog.value?.close();

const trocarFunil = async () => {
  createError.value = '';
  try {
    await carregarEtapas(boardId.value);
  } catch {
    loadError.value = t('KANBAN.CONTACT_OPPORTUNITY.LOAD_ERROR');
  }
};

const criar = async () => {
  if (!podeCriar.value) return;
  isCreating.value = true;
  createError.value = '';
  const card = {
    kanban_stage_id: stageId.value,
    contact_id: props.contactId,
    inbox_id: inboxId.value,
    subject: subject.value.trim(),
  };
  if (centavos.value !== null) card.amount_cents = centavos.value;
  if (requiredFieldDefinitions.value.length) {
    card.custom_field_values = { ...requiredFieldValues.value };
  }
  try {
    const { data } = await KanbanBoardsAPI.createManualCard(boardId.value, {
      card,
    });
    dialog.value?.close();
    emit('created', { id: data?.id, boardId: boardId.value });
  } catch (error) {
    const resposta = error?.response?.data;
    if (resposta?.code === 'possible_duplicate') {
      createError.value = t('KANBAN.CONTACT_OPPORTUNITY.DUPLICATE', {
        subject: resposta.duplicate_card?.subject,
        stage: resposta.duplicate_card?.stage_name,
      });
    } else if (resposta?.missing_fields?.length) {
      const juntos = mergeRequiredFields(
        requiredFieldDefinitions.value,
        requiredFieldValues.value,
        resposta.field_definitions,
        resposta.missing_fields
      );
      requiredFieldDefinitions.value = juntos.definitions;
      requiredFieldValues.value = juntos.values;
      createError.value = t('KANBAN.CONTACT_OPPORTUNITY.REQUIRED_PENDING');
      await nextTick();
      document
        .querySelector(
          `[data-testid="kanban-contact-opportunity-field-${resposta.missing_fields[0]}"]`
        )
        ?.focus();
    } else {
      createError.value = t('KANBAN.CONTACT_OPPORTUNITY.CREATE_ERROR');
    }
  } finally {
    isCreating.value = false;
  }
};

defineExpose({ open });
</script>

<template>
  <dialog
    ref="dialog"
    :aria-labelledby="titleId"
    class="w-[calc(100%-2rem)] max-w-lg overflow-visible rounded-xl border border-solid border-n-weak bg-n-solid-1 p-0 shadow-lg backdrop:bg-n-alpha-black1 backdrop:backdrop-blur-sm"
    @click.self="fechar"
    @close="aberto = false"
  >
    <form
      v-if="aberto"
      class="flex max-h-[calc(100dvh-4rem)] flex-col gap-5 overflow-y-auto p-6"
      @submit.prevent="criar"
    >
      <h3
        :id="titleId"
        class="mb-0 text-base font-medium leading-6 text-n-slate-12"
      >
        {{ t('KANBAN.CONTACT_OPPORTUNITY.TITLE') }}
      </h3>
      <div
        data-testid="kanban-contact-opportunity-dialog"
        class="grid gap-4"
        :aria-busy="isLoading || isCreating"
      >
        <div
          class="flex items-center gap-2 rounded-lg border border-solid border-n-weak px-3 py-2"
        >
          <Avatar :name="contactName" :size="24" rounded-full />
          <span class="min-w-0 break-words text-sm font-medium text-n-slate-12">
            {{ contactName }}
          </span>
          <span class="text-xs text-n-slate-11">
            {{ t('KANBAN.CONTACT_OPPORTUNITY.THIS_CONTACT') }}
          </span>
        </div>

        <p
          v-if="loadError"
          role="alert"
          class="mb-0 flex items-start gap-2 rounded-md bg-n-ruby-2 px-2.5 py-2 text-xs text-n-ruby-11"
        >
          <i
            aria-hidden="true"
            class="i-lucide-circle-alert mt-px size-3.5 shrink-0"
          />
          {{ loadError }}
        </p>

        <div class="grid gap-4 sm:grid-cols-2">
          <RaevoField
            :label="t('KANBAN.CONTACT_OPPORTUNITY.BOARD')"
            variant="select"
          >
            <template #default="{ controlClass, fieldId }">
              <select
                :id="fieldId"
                v-model="boardId"
                data-testid="kanban-contact-opportunity-board"
                :class="controlClass"
                :disabled="isLoading || isCreating"
                @change="trocarFunil"
              >
                <option
                  v-for="board in boards"
                  :key="board.id"
                  :value="board.id"
                >
                  {{ board.name }}
                </option>
              </select>
            </template>
          </RaevoField>
          <RaevoField
            :label="t('KANBAN.CONTACT_OPPORTUNITY.STAGE')"
            variant="select"
          >
            <template #default="{ controlClass, fieldId }">
              <select
                :id="fieldId"
                v-model="stageId"
                data-testid="kanban-contact-opportunity-stage"
                :class="controlClass"
                :disabled="isLoading || isCreating"
              >
                <option
                  v-for="stage in stages"
                  :key="stage.id"
                  :value="stage.id"
                >
                  {{ stage.name }}
                </option>
              </select>
            </template>
          </RaevoField>
        </div>

        <RaevoField :label="t('KANBAN.CONTACT_OPPORTUNITY.SUBJECT')">
          <template #default="{ controlClass, fieldId }">
            <input
              :id="fieldId"
              v-model="subject"
              type="text"
              data-testid="kanban-contact-opportunity-subject"
              :class="controlClass"
              :disabled="isCreating"
            />
          </template>
        </RaevoField>

        <div class="grid gap-4 sm:grid-cols-2">
          <RaevoField
            :label="t('KANBAN.CONTACT_OPPORTUNITY.AMOUNT')"
            :error="
              valorInvalido
                ? t('KANBAN.CONTACT_OPPORTUNITY.AMOUNT_INVALID')
                : ''
            "
          >
            <template #default="{ controlClass, fieldId }">
              <input
                :id="fieldId"
                v-model="amount"
                type="text"
                inputmode="decimal"
                data-testid="kanban-contact-opportunity-amount"
                :placeholder="
                  t('KANBAN.CONTACT_OPPORTUNITY.AMOUNT_PLACEHOLDER')
                "
                :class="controlClass"
                :disabled="isCreating"
              />
            </template>
          </RaevoField>
          <RaevoField
            :label="t('KANBAN.CONTACT_OPPORTUNITY.INBOX')"
            :hint="
              inboxDaUltimaConversa
                ? t('KANBAN.CONTACT_OPPORTUNITY.INBOX_HINT')
                : ''
            "
            :error="
              !isLoading && !loadError && !inboxes.length
                ? t('KANBAN.CONTACT_OPPORTUNITY.NO_INBOX')
                : ''
            "
            variant="select"
          >
            <template #default="{ controlClass, fieldId }">
              <select
                :id="fieldId"
                v-model="inboxId"
                data-testid="kanban-contact-opportunity-inbox"
                :class="controlClass"
                :disabled="isLoading || isCreating || !inboxes.length"
              >
                <option
                  v-for="inbox in inboxes"
                  :key="inbox.id"
                  :value="inbox.id"
                >
                  {{ inbox.name }}
                </option>
              </select>
            </template>
          </RaevoField>
        </div>

        <KanbanRequiredFields
          v-if="requiredFieldDefinitions.length"
          v-model="requiredFieldValues"
          :definitions="requiredFieldDefinitions"
          testid-prefix="kanban-contact-opportunity-field-"
        />

        <div
          v-if="createError"
          role="alert"
          data-testid="kanban-contact-opportunity-error"
          class="flex items-start gap-2 rounded-md bg-n-ruby-2 px-2.5 py-2 text-xs text-n-ruby-11"
        >
          <i
            aria-hidden="true"
            class="i-lucide-circle-alert mt-px size-3.5 shrink-0"
          />
          <span>{{ createError }}</span>
        </div>
      </div>

      <div class="flex items-center justify-between gap-3">
        <NextButton
          type="button"
          faded
          slate
          class="w-full"
          data-testid="kanban-contact-opportunity-cancel"
          :label="t('KANBAN.CONTACT_OPPORTUNITY.CANCEL')"
          :disabled="isCreating"
          @click="fechar"
        />
        <NextButton
          type="submit"
          class="w-full"
          data-testid="kanban-contact-opportunity-create"
          :label="
            isCreating
              ? t('KANBAN.CONTACT_OPPORTUNITY.CREATING')
              : t('KANBAN.CONTACT_OPPORTUNITY.CREATE')
          "
          :is-loading="isCreating"
          :disabled="!podeCriar"
        />
      </div>
    </form>
  </dialog>
</template>
