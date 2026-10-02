<script setup>
/**
 * A oportunidade dentro da conversa.
 *
 * Trabalhar um lead obrigava a ir e voltar entre a conversa e a ficha da
 * oportunidade, e cada volta perdia o contexto. Aqui a ficha é **a mesma**
 * (`KanbanOpportunityDetailsModal`, em modo gaveta): as mesmas abas, os mesmos
 * campos, as mesmas regras de gravação. Duplicar os campos era o caminho curto
 * para eles divergirem, como já aconteceu com o formulário de procedimento.
 */
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import KanbanBoardsAPI from 'dashboard/api/kanbanBoards';
import { useMapGetter } from 'dashboard/composables/store';
import KanbanOpportunityDetailsModal from 'dashboard/routes/dashboard/kanban/KanbanOpportunityDetailsModal.vue';
import KanbanConversationCards from './KanbanConversationCards.vue';

const props = defineProps({
  conversationId: {
    type: [Number, String],
    required: true,
  },
  /**
   * A ficha foi aberta a partir do funil, e não da barra lateral da conversa.
   *
   * Muda duas coisas, e as duas pela mesma razão: ali a oportunidade **já está
   * num funil**, porque foi de lá que a gaveta abriu. «Adicionar ao Kanban» não
   * tem o que fazer, e o espaço que ele ocupava — mais os 123px que sobravam
   * por baixo — passa para a ficha, que estava a cortar campos a meio.
   */
  fromBoard: {
    type: Boolean,
    default: false,
  },
});

const { t } = useI18n();
const currentRole = useMapGetter('getCurrentRole');
const agents = useMapGetter('agents/getAgents');

const cards = ref([]);
const selectedCardId = ref(null);
const boardSettings = ref(null);
const isLoading = ref(false);
const hasError = ref(false);
const showCreateForm = ref(false);

const isAdmin = computed(() => currentRole.value === 'administrator');
const ownerOptions = computed(() =>
  (agents.value || []).map(agent => ({ value: agent.id, label: agent.name }))
);

// A mais recente primeiro: é a que a conversa está a tratar agora.
const sortedCards = computed(() =>
  [...cards.value].sort(
    (first, second) =>
      new Date(second.created_at || 0) - new Date(first.created_at || 0)
  )
);
const selectedCard = computed(
  () =>
    sortedCards.value.find(card => card.id === selectedCardId.value) ||
    sortedCards.value[0]
);

const loadBoardSettings = async boardId => {
  if (!boardId) return;

  try {
    const response = await KanbanBoardsAPI.getSettings(boardId);
    boardSettings.value = response.data || null;
  } catch {
    boardSettings.value = null;
    hasError.value = true;
  }
};

const loadCards = async ({ silent = false } = {}) => {
  isLoading.value = !silent;
  hasError.value = false;
  try {
    const response = await KanbanBoardsAPI.getConversationCards(
      props.conversationId
    );
    cards.value = response.data?.payload || [];
    // Numa atualização silenciosa a ficha aberta continua aberta: trocar de
    // oportunidade debaixo de quem acabou de gravar seria perder o lugar.
    if (!silent || !selectedCard.value) {
      selectedCardId.value = sortedCards.value[0]?.id || null;
      showCreateForm.value = false;
      await loadBoardSettings(selectedCard.value?.kanban_board?.id);
    }
  } catch {
    cards.value = [];
    boardSettings.value = null;
    hasError.value = true;
  } finally {
    isLoading.value = false;
  }
};

watch(selectedCardId, async () => {
  await loadBoardSettings(selectedCard.value?.kanban_board?.id);
});
watch(() => props.conversationId, loadCards);
onMounted(loadCards);

// Mudar o assunto ou a etapa muda o que o seletor mostra — sem piscar a ficha.
const onUpdated = () => loadCards({ silent: true });
</script>

<template>
  <div :class="fromBoard ? 'flex h-full min-h-0 flex-col gap-2' : 'grid gap-2'">
    <p
      v-if="isLoading"
      data-testid="kanban-conversation-opportunity-loading"
      class="mb-0 text-xs text-n-slate-11"
    >
      {{ t('CONVERSATION_SIDEBAR.KANBAN.LOADING') }}
    </p>
    <p
      v-else-if="hasError"
      data-testid="kanban-conversation-opportunity-error"
      class="mb-0 flex items-start gap-1.5 text-xs text-n-ruby-11"
      role="alert"
    >
      <i class="i-lucide-alert-triangle mt-0.5 size-3.5 shrink-0" />
      {{ t('CONVERSATION_SIDEBAR.KANBAN.ERROR') }}
    </p>

    <template v-else-if="selectedCard && boardSettings">
      <label
        v-if="sortedCards.length > 1"
        class="grid gap-1 px-1 text-xs text-n-slate-11"
      >
        {{ t('CONVERSATION_SIDEBAR.KANBAN.WHICH_OPPORTUNITY') }}
        <select
          v-model.number="selectedCardId"
          data-testid="kanban-conversation-opportunity-picker"
          class="h-8 w-full rounded-md border border-n-weak bg-n-solid-1 px-2 text-xs text-n-slate-12 outline-none focus:border-n-brand focus:ring-2 focus:ring-n-brand/20"
        >
          <option v-for="card in sortedCards" :key="card.id" :value="card.id">
            {{ card.subject }} · {{ card.kanban_board.name }}
          </option>
        </select>
      </label>

      <!--
        A ficha inteira, em modo gaveta: cresce até ao fim da coluna e rola por
        dentro, em vez de empurrar a conversa.

        Vinda do funil, a caixa vai até ao fim: o `max-h` estava calculado para
        a barra lateral da conversa e, na gaveta, acabava 123px antes do fundo —
        cortava um campo a meio e deixava espaço vazio por baixo.
      -->
      <div
        :class="
          fromBoard
            ? '-mx-2 flex min-h-0 flex-1 flex-col overflow-hidden rounded-lg border border-n-weak'
            : '-mx-2 flex max-h-[calc(100vh-14rem)] min-h-[28rem] flex-col overflow-hidden rounded-lg border border-n-weak'
        "
      >
        <KanbanOpportunityDetailsModal
          :key="selectedCard.id"
          :board-id="boardSettings.id"
          :board-name="boardSettings.name"
          :stages="boardSettings.stages || []"
          :card-id="selectedCard.id"
          :next-action-types="boardSettings.next_action_types || []"
          :lost-reason-options="boardSettings.lost_reason_options || []"
          :custom-field-definitions="
            boardSettings.custom_field_definitions || []
          "
          :custom-field-sections="boardSettings.custom_field_sections || []"
          :contact-field-keys="boardSettings.contact_field_keys || []"
          :calendar-enabled="boardSettings.calendar_enabled"
          :calendar-booking-stage-ids="
            boardSettings.calendar_booking_stage_ids || []
          "
          :calendar-procedure-ids="boardSettings.calendar_procedure_ids || []"
          :owner-options="ownerOptions"
          :can-manage-fields="isAdmin"
          drawer-mode
          embedded
          @updated="onUpdated"
        />
      </div>

      <!--
        Só fora do funil. Na gaveta do Pipeline a oportunidade já está no funil
        — foi de lá que a gaveta abriu —, e o botão ficava solto por baixo da
        caixa a propor o que já estava feito.
      -->
      <button
        v-if="!fromBoard"
        type="button"
        data-testid="kanban-conversation-new-opportunity"
        class="justify-self-start rounded-md px-1 py-1 text-xs font-medium text-n-brand outline-none hover:underline focus-visible:ring-2 focus-visible:ring-n-brand"
        @click="showCreateForm = !showCreateForm"
      >
        {{ t('CONVERSATION_SIDEBAR.KANBAN.ADD') }}
      </button>
      <KanbanConversationCards
        v-if="showCreateForm && !fromBoard"
        :conversation-id="conversationId"
      />
    </template>

    <!-- Sem oportunidade: o painel existente já sabe criar uma. -->
    <KanbanConversationCards v-else :conversation-id="conversationId" />
  </div>
</template>
