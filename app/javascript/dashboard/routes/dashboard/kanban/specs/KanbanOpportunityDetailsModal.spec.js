import { flushPromises, mount } from '@vue/test-utils';
import KanbanOpportunityDetailsModal from '../KanbanOpportunityDetailsModal.vue';
import KanbanBoardsAPI from 'dashboard/api/kanbanBoards';

const storeMocks = vi.hoisted(() => ({
  labels: [],
  dispatch: vi.fn(),
}));

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, params = {}) => {
      const translations = {
        'KANBAN.OPPORTUNITY_DETAILS.TITLE': 'Opportunity details',
        'KANBAN.OPPORTUNITY_DETAILS.TITLE_WITH_BOARD':
          'Edit opportunity in {boardName}',
        'KANBAN.OPPORTUNITY_DETAILS.CARD_ID': 'Card #{id}',
        'KANBAN.OPPORTUNITY_DETAILS.FIELD_TITLE': 'Title',
        'KANBAN.OPPORTUNITY_DETAILS.FIELD_DESCRIPTION': 'Description',
        'KANBAN.OPPORTUNITY_DETAILS.FIELD_AMOUNT': 'Value',
        'KANBAN.OPPORTUNITY_DETAILS.CUSTOM_FIELDS': 'Custom fields',
        'KANBAN.OPPORTUNITY_DETAILS.DESCRIPTION_PLACEHOLDER':
          'Add a single note for this card',
        'KANBAN.OPPORTUNITY_DETAILS.ASSIGNEE': 'Agent',
        'KANBAN.OPPORTUNITY_DETAILS.UNASSIGNED': 'Unassigned',
        'KANBAN.OPPORTUNITY_DETAILS.CONVERSATION': 'Conversation',
        'KANBAN.OPPORTUNITY_DETAILS.CONVERSATION_ID': 'Conversation #{id}',
        'KANBAN.OPPORTUNITY_DETAILS.CONTACT': 'Contact',
        'KANBAN.OPPORTUNITY_DETAILS.NO_CONTACT': 'No contact linked',
        'KANBAN.OPPORTUNITY_DETAILS.DATES': 'Dates',
        'KANBAN.OPPORTUNITY_DETAILS.START_DATE': 'Start date',
        'KANBAN.OPPORTUNITY_DETAILS.DUE_DATE': 'Due date',
        'KANBAN.OPPORTUNITY_DETAILS.NEXT_ACTION': 'Next action',
        'KANBAN.OPPORTUNITY_DETAILS.NEXT_ACTION_TYPE': 'Action type',
        'KANBAN.OPPORTUNITY_DETAILS.NEXT_ACTION_AT': 'Action date',
        'KANBAN.OPPORTUNITY_DETAILS.NEXT_ACTION_NOTE': 'Action note',
        'KANBAN.OPPORTUNITY_DETAILS.NEXT_ACTION_NOTE_PLACEHOLDER':
          'What should happen next?',
        'KANBAN.OPPORTUNITY_DETAILS.ACTION_TYPES.NONE': 'Select action',
        'KANBAN.OPPORTUNITY_DETAILS.ACTION_TYPES.CALL_BACK': 'Call back',
        'KANBAN.OPPORTUNITY_DETAILS.ACTION_TYPES.SEND_PROPOSAL':
          'Send proposal',
        'KANBAN.OPPORTUNITY_DETAILS.ACTION_TYPES.SEND_PAYMENT_LINK':
          'Send payment link',
        'KANBAN.OPPORTUNITY_DETAILS.ACTION_TYPES.FOLLOW_UP': 'Follow up',
        'KANBAN.OPPORTUNITY_DETAILS.ACTION_TYPES.CONFIRM_PAYMENT':
          'Confirm payment',
        'KANBAN.OPPORTUNITY_DETAILS.ACTION_TYPES.SEND_CONTRACT':
          'Send contract',
        'KANBAN.OPPORTUNITY_DETAILS.ACTION_TYPES.OTHER': 'Other',
        'KANBAN.OPPORTUNITY_DETAILS.CLOSE_STATUS': 'Close status',
        'KANBAN.OPPORTUNITY_DETAILS.MARK_WON': 'Mark won',
        'KANBAN.OPPORTUNITY_DETAILS.MARK_LOST': 'Mark lost',
        'KANBAN.OPPORTUNITY_DETAILS.LOST_REASON': 'Lost reason',
        'KANBAN.OPPORTUNITY_DETAILS.LOST_REASON_REQUIRED':
          'Enter a lost reason.',
        'KANBAN.OPPORTUNITY_DETAILS.CANCEL': 'Cancel',
        'KANBAN.OPPORTUNITY_DETAILS.SAVE': 'Save',
        'KANBAN.OPPORTUNITY_DETAILS.SAVING': 'Saving...',
        'KANBAN.OPPORTUNITY_DETAILS.LABELS': 'Labels',
        'KANBAN.OPPORTUNITY_DETAILS.SAVE_LABELS': 'Save labels',
        'KANBAN.OPPORTUNITY_DETAILS.SAVING_LABELS': 'Saving labels...',
        'KANBAN.OPPORTUNITY_DETAILS.NO_LABELS_AVAILABLE': 'No labels available',
        'KANBAN.OPPORTUNITY_DETAILS.LOAD_LABELS_ERROR':
          'Could not load labels.',
        'KANBAN.OPPORTUNITY_DETAILS.SAVE_LABELS_ERROR':
          'Could not save labels.',
        'KANBAN.OPPORTUNITY_DETAILS.OPEN_CONVERSATION': 'Open conversation',
        'KANBAN.OPPORTUNITY_DETAILS.NO_LINKED_CONVERSATION':
          'No linked conversation',
        'KANBAN.OPPORTUNITY_DETAILS.LOADING': 'Loading opportunity details...',
        'KANBAN.OPPORTUNITY_DETAILS.LOAD_ERROR':
          'Could not load opportunity details.',
        'KANBAN.OPPORTUNITY_DETAILS.SAVE_ERROR':
          'Could not save opportunity details.',
        'KANBAN.OPPORTUNITY_DETAILS.REQUIRED_TITLE': 'Title is required.',
        'KANBAN.OPPORTUNITY_DETAILS.CLOSE': 'Close opportunity details',
      };

      return Object.entries(params).reduce(
        (message, [name, value]) =>
          message.replace(`{${name}}`, value).replace(`#{${name}}`, value),
        translations[key] || key
      );
    },
  }),
}));

vi.mock('dashboard/api/kanbanBoards', () => ({
  default: {
    showCardById: vi.fn(),
    updateCardDetailsById: vi.fn(),
    getCardLabels: vi.fn(),
    updateCardLabels: vi.fn(),
  },
}));

vi.mock('dashboard/composables/store', async () => {
  const { computed } = await vi.importActual('vue');

  return {
    useStore: () => ({ dispatch: storeMocks.dispatch }),
    useMapGetter: () => computed(() => storeMocks.labels),
  };
});

const nextInputStub = {
  inheritAttrs: false,
  props: ['modelValue', 'label', 'message', 'messageType', 'type', 'autofocus'],
  emits: ['update:modelValue', 'input'],
  template: `
    <label>
      <span>{{ label }}</span>
      <input
        v-bind="$attrs"
        :type="type || 'text'"
        :value="modelValue"
        @input="$emit('update:modelValue', $event.target.value); $emit('input', $event)"
      />
      <p v-if="message" :data-message-type="messageType">{{ message }}</p>
    </label>
  `,
};

const nextButtonStub = {
  props: ['label', 'disabled', 'isLoading', 'icon'],
  emits: ['click'],
  template: `
    <button
      v-bind="$attrs"
      :disabled="disabled"
      :data-icon="icon"
      @click="$emit('click', $event)"
    >
      <span v-if="isLoading">loading</span>
      {{ label }}
    </button>
  `,
};

const buildCard = overrides => ({
  id: 501,
  subject: 'Enterprise expansion',
  description: 'Follow up with procurement next week.',
  startsAt: '2026-06-01T09:00',
  dueAt: '2026-06-05T18:00',
  amountCents: 12550,
  amountCurrency: 'BRL',
  customFieldValues: {
    consulta_realizada: 'Sim',
    observacao_venda: 'Cliente quer fechar no WhatsApp',
  },
  ownerId: 7,
  nextActionType: 'Enviar proposta',
  nextActionAt: '2026-07-20T15:00',
  nextActionNote: 'Send proposal by WhatsApp',
  nextActionCompletedAt: null,
  nextActionHistory: [],
  lostReason: '',
  conversationId: 42,
  conversation: {
    id: 42,
    meta: { assignee: { id: 7, name: 'Jane Agent' } },
  },
  contact: { id: 91, name: 'Acme Buyer' },
  ...overrides,
});

const labels = [
  { id: 1, title: 'hot', color: '#ff0000' },
  { id: 2, title: 'enterprise', color: '#00ff00' },
];

const mountModal = async ({
  card = buildCard(),
  resolveLoad = true,
  resolveLabels = true,
  accountLabels = labels,
  assignedLabels = [labels[0]],
  customFieldDefinitions = [
    {
      key: 'consulta_realizada',
      label: 'Consulta realizada?',
      fieldType: 'select',
      options: ['Sim', 'Não'],
    },
    {
      key: 'observacao_venda',
      label: 'Observação de venda',
      fieldType: 'text',
    },
  ],
} = {}) => {
  storeMocks.labels = accountLabels;
  storeMocks.dispatch.mockResolvedValue();

  if (resolveLabels) {
    KanbanBoardsAPI.getCardLabels.mockResolvedValue({
      data: { payload: assignedLabels },
    });
  }

  if (resolveLoad) {
    KanbanBoardsAPI.showCardById.mockResolvedValue({ data: card });
  }

  const wrapper = mount(KanbanOpportunityDetailsModal, {
    props: {
      boardId: 10,
      boardName: 'Sales funnel',
      cardId: 501,
      nextActionTypes: ['Enviar proposta', 'Enviar link de pagamento'],
      lostReasonOptions: ['Preço', 'Sem resposta'],
      customFieldDefinitions,
      ownerOptions: [
        { value: 7, label: 'Jane Agent' },
        { value: 8, label: 'Ana Paula' },
      ],
    },
    global: {
      stubs: {
        NextInput: nextInputStub,
        NextButton: nextButtonStub,
      },
    },
  });

  if (resolveLoad) await flushPromises();

  return wrapper;
};

const subjectInput = wrapper =>
  wrapper.find('[data-testid="kanban-opportunity-subject"]');
const descriptionInput = wrapper =>
  wrapper.find('[data-testid="kanban-opportunity-description"]');
const amountInput = wrapper =>
  wrapper.find('[data-testid="kanban-opportunity-amount"]');
const customFieldInput = (wrapper, key) =>
  wrapper.find(`[data-testid="kanban-custom-field-${key}"]`);
const startsAtInput = wrapper =>
  wrapper.find('[data-testid="kanban-opportunity-starts-at"]');
const dueAtInput = wrapper =>
  wrapper.find('[data-testid="kanban-opportunity-due-at"]');
const nextActionTypeInput = wrapper =>
  wrapper.find('[data-testid="kanban-opportunity-next-action-type"]');
const ownerInput = wrapper =>
  wrapper.find('[data-testid="kanban-opportunity-owner"]');
const nextActionAtInput = wrapper =>
  wrapper.find('[data-testid="kanban-opportunity-next-action-at"]');
const nextActionNoteInput = wrapper =>
  wrapper.find('[data-testid="kanban-opportunity-next-action-note"]');
const lostReasonInput = wrapper =>
  wrapper.find('[data-testid="kanban-opportunity-lost-reason"]');
const saveButton = wrapper =>
  wrapper.find('[data-testid="kanban-opportunity-save"]');
const labelButtons = wrapper =>
  wrapper.findAll('[data-testid="kanban-opportunity-label"]');
const saveLabelsButton = wrapper =>
  wrapper.find('[data-testid="kanban-opportunity-save-labels"]');

describe('KanbanOpportunityDetailsModal', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    storeMocks.labels = [];
  });

  it('loads detail through showCardById', async () => {
    await mountModal();

    expect(KanbanBoardsAPI.showCardById).toHaveBeenCalledWith(10, 501);
  });

  it('renders a responsive two-column layout', async () => {
    const wrapper = await mountModal();

    expect(wrapper.text()).toContain('Edit opportunity in Sales funnel');
    expect(wrapper.classes()).toEqual(
      expect.arrayContaining([
        'mx-auto',
        'w-full',
        'max-w-[calc(100vw-2rem)]',
        '2xl:max-w-[96rem]',
      ])
    );
    expect(
      wrapper.find('[data-testid="kanban-opportunity-form"]').classes()
    ).toContain('grid');
    expect(
      wrapper.find('[data-testid="kanban-opportunity-layout"]').classes()
    ).toContain('xl:grid-cols-[minmax(0,4fr)_minmax(16rem,1fr)]');
  });

  it('renders title, compact description, and amount controls', async () => {
    const wrapper = await mountModal();

    expect(subjectInput(wrapper).classes()).toContain('w-full');
    expect(descriptionInput(wrapper).classes()).toEqual(
      expect.arrayContaining(['max-w-full', 'w-full', 'min-h-24'])
    );
    expect(descriptionInput(wrapper).attributes('rows')).toBe('4');
    expect(amountInput(wrapper).element.value).toBe('125.50');
  });

  it('renders card ID in the header', async () => {
    const wrapper = await mountModal();

    expect(
      wrapper.find('[data-testid="kanban-opportunity-card-id"]').text()
    ).toContain('Card #501');
  });

  it('renders loading state', async () => {
    KanbanBoardsAPI.showCardById.mockReturnValue(new Promise(() => {}));
    const wrapper = mount(KanbanOpportunityDetailsModal, {
      props: {
        boardId: 10,
        boardName: 'Sales funnel',
        cardId: 501,
        nextActionTypes: ['Enviar proposta', 'Enviar link de pagamento'],
        lostReasonOptions: ['Preço', 'Sem resposta'],
        ownerOptions: [
          { value: 7, label: 'Jane Agent' },
          { value: 8, label: 'Ana Paula' },
        ],
      },
      global: {
        stubs: {
          NextInput: nextInputStub,
          NextButton: nextButtonStub,
        },
      },
    });

    await flushPromises();

    expect(
      wrapper.find('[data-testid="kanban-opportunity-loading"]').exists()
    ).toBe(true);
  });

  it('renders load error', async () => {
    KanbanBoardsAPI.showCardById.mockRejectedValue({
      response: { data: { message: 'Load failed' } },
    });
    const wrapper = await mountModal({ resolveLoad: false });

    await flushPromises();

    expect(
      wrapper.find('[data-testid="kanban-opportunity-load-error"]').text()
    ).toContain('Load failed');
  });

  it('loads subject', async () => {
    const wrapper = await mountModal();

    expect(subjectInput(wrapper).element.value).toBe('Enterprise expansion');
  });

  it('loads description', async () => {
    const wrapper = await mountModal();

    expect(descriptionInput(wrapper).element.value).toBe(
      'Follow up with procurement next week.'
    );
  });

  it('loads startsAt and dueAt', async () => {
    const wrapper = await mountModal();

    expect(startsAtInput(wrapper).element.value).toBe('2026-06-01T09:00');
    expect(dueAtInput(wrapper).element.value).toBe('2026-06-05T18:00');
  });

  it('loads board-specific custom fields', async () => {
    const wrapper = await mountModal();

    expect(wrapper.text()).toContain('Custom fields');
    expect(customFieldInput(wrapper, 'consulta_realizada').element.value).toBe(
      'Sim'
    );
    expect(customFieldInput(wrapper, 'observacao_venda').element.value).toBe(
      'Cliente quer fechar no WhatsApp'
    );
  });

  it('loads next action fields', async () => {
    const wrapper = await mountModal();

    expect(nextActionTypeInput(wrapper).element.value).toBe('Enviar proposta');
    expect(nextActionAtInput(wrapper).element.value).toBe('2026-07-20T15:00');
    expect(nextActionNoteInput(wrapper).element.value).toBe(
      'Send proposal by WhatsApp'
    );
  });

  it('loads owner field', async () => {
    const wrapper = await mountModal();

    expect(ownerInput(wrapper).element.value).toBe('7');
    expect(ownerInput(wrapper).text()).toContain('Ana Paula');
  });

  it('saves description with existing scalar fields', async () => {
    KanbanBoardsAPI.updateCardDetailsById.mockResolvedValue({
      data: buildCard({ description: 'Updated card note' }),
    });
    const wrapper = await mountModal();

    await descriptionInput(wrapper).setValue('Updated card note');
    await wrapper.find('form').trigger('submit');
    await flushPromises();

    expect(KanbanBoardsAPI.updateCardDetailsById).toHaveBeenCalledWith(
      10,
      501,
      expect.objectContaining({
        subject: 'Enterprise expansion',
        description: 'Updated card note',
      })
    );
  });

  it('clears description with null', async () => {
    KanbanBoardsAPI.updateCardDetailsById.mockResolvedValue({
      data: buildCard({ description: null }),
    });
    const wrapper = await mountModal();

    await descriptionInput(wrapper).setValue('');
    await wrapper.find('form').trigger('submit');
    await flushPromises();

    expect(KanbanBoardsAPI.updateCardDetailsById).toHaveBeenCalledWith(
      10,
      501,
      expect.objectContaining({ description: null })
    );
  });

  it('preserves edited text on save error', async () => {
    KanbanBoardsAPI.updateCardDetailsById.mockRejectedValue({
      response: { data: { message: 'Save failed' } },
    });
    const wrapper = await mountModal();

    await subjectInput(wrapper).setValue('Preserved subject');
    await descriptionInput(wrapper).setValue('Preserved description');
    await wrapper.find('form').trigger('submit');
    await flushPromises();

    expect(subjectInput(wrapper).element.value).toBe('Preserved subject');
    expect(descriptionInput(wrapper).element.value).toBe(
      'Preserved description'
    );
    expect(
      wrapper.find('[data-testid="kanban-opportunity-save-error"]').text()
    ).toContain('Save failed');
  });

  it('saves optional date values', async () => {
    KanbanBoardsAPI.updateCardDetailsById.mockResolvedValue({
      data: buildCard(),
    });
    const wrapper = await mountModal();

    await startsAtInput(wrapper).setValue('2026-06-02T10:30');
    await dueAtInput(wrapper).setValue('2026-06-04T15:45');
    await wrapper.find('form').trigger('submit');
    await flushPromises();

    expect(KanbanBoardsAPI.updateCardDetailsById).toHaveBeenCalledWith(
      10,
      501,
      expect.objectContaining({
        starts_at: new Date('2026-06-02T10:30').toISOString(),
        due_at: new Date('2026-06-04T15:45').toISOString(),
      })
    );
  });

  it('saves amount and board-specific custom fields', async () => {
    KanbanBoardsAPI.updateCardDetailsById.mockResolvedValue({
      data: buildCard({
        amountCents: 19990,
        customFieldValues: {
          consulta_realizada: 'Não',
          observacao_venda: 'Fechamento sem reunião',
        },
      }),
    });
    const wrapper = await mountModal();

    await amountInput(wrapper).setValue('199.90');
    await customFieldInput(wrapper, 'consulta_realizada').setValue('Não');
    await customFieldInput(wrapper, 'observacao_venda').setValue(
      'Fechamento sem reunião'
    );
    await wrapper.find('form').trigger('submit');
    await flushPromises();

    expect(KanbanBoardsAPI.updateCardDetailsById).toHaveBeenCalledWith(
      10,
      501,
      expect.objectContaining({
        amount_cents: 19990,
        amount_currency: 'BRL',
        custom_field_values: {
          consulta_realizada: 'Não',
          observacao_venda: 'Fechamento sem reunião',
        },
      })
    );
  });

  it('saves next action fields', async () => {
    KanbanBoardsAPI.updateCardDetailsById.mockResolvedValue({
      data: buildCard({
        nextActionType: 'send_payment_link',
        nextActionNote: 'Send checkout link',
      }),
    });
    const wrapper = await mountModal();

    await ownerInput(wrapper).setValue('8');
    await nextActionTypeInput(wrapper).setValue('Enviar link de pagamento');
    await nextActionAtInput(wrapper).setValue('2026-07-22T11:30');
    await nextActionNoteInput(wrapper).setValue('Send checkout link');
    await wrapper.find('form').trigger('submit');
    await flushPromises();

    expect(KanbanBoardsAPI.updateCardDetailsById).toHaveBeenCalledWith(
      10,
      501,
      expect.objectContaining({
        owner_id: 8,
        next_action_type: 'Enviar link de pagamento',
        next_action_at: new Date('2026-07-22T11:30').toISOString(),
        next_action_note: 'Send checkout link',
      })
    );
  });

  it('marks the current next action as completed', async () => {
    KanbanBoardsAPI.updateCardDetailsById.mockResolvedValue({
      data: buildCard({ nextActionCompletedAt: '2026-07-21T16:00:00.000Z' }),
    });
    const wrapper = await mountModal();

    await wrapper
      .find('[data-testid="kanban-opportunity-complete-next-action"]')
      .trigger('click');
    await flushPromises();

    expect(KanbanBoardsAPI.updateCardDetailsById).toHaveBeenCalledWith(
      10,
      501,
      expect.objectContaining({ next_action_completed_at: expect.any(String) })
    );
  });

  it('renders checkbox and multiselect custom fields', async () => {
    const wrapper = await mountModal({
      card: buildCard({
        customFieldValues: { prioridade: true, produtos: ['Plano'] },
      }),
      customFieldDefinitions: [
        { key: 'prioridade', label: 'Prioridade', fieldType: 'boolean' },
        {
          key: 'produtos',
          label: 'Produtos',
          fieldType: 'multiselect',
          options: ['Plano', 'Curso'],
        },
      ],
    });

    expect(customFieldInput(wrapper, 'prioridade').attributes('type')).toBe(
      'checkbox'
    );
    expect(customFieldInput(wrapper, 'prioridade').element.checked).toBe(true);
    expect(customFieldInput(wrapper, 'produtos').element.multiple).toBe(true);
  });

  it('shows a conditional field when a boolean source is false', async () => {
    const wrapper = await mountModal({
      card: buildCard({ customFieldValues: { aceitou: false } }),
      customFieldDefinitions: [
        { key: 'aceitou', label: 'Aceitou?', fieldType: 'boolean' },
        {
          key: 'motivo',
          label: 'Motivo',
          fieldType: 'text',
          condition: { fieldKey: 'aceitou', equals: false },
        },
      ],
    });

    expect(customFieldInput(wrapper, 'aceitou').element.checked).toBe(false);
    expect(customFieldInput(wrapper, 'motivo').exists()).toBe(true);
  });

  it('renders the recent next action history', async () => {
    const wrapper = await mountModal({
      card: buildCard({
        nextActionCompletedAt: '2026-07-21T16:00:00.000Z',
        nextActionHistory: [
          {
            type: 'Enviar proposta',
            note: 'Enviar no WhatsApp',
            completed_at: '2026-07-21T16:00:00.000Z',
          },
        ],
      }),
    });

    const history = wrapper.find(
      '[data-testid="kanban-opportunity-next-action-history"]'
    );
    expect(history.text()).toContain('Enviar proposta');
    expect(history.text()).toContain('Enviar no WhatsApp');
  });

  it('marks opportunity as won', async () => {
    KanbanBoardsAPI.updateCardDetailsById.mockResolvedValue({
      data: buildCard({ wonAt: '2026-07-23T12:00:00.000Z' }),
    });
    const wrapper = await mountModal();

    await wrapper
      .find('[data-testid="kanban-opportunity-mark-won"]')
      .trigger('click');
    await flushPromises();

    expect(KanbanBoardsAPI.updateCardDetailsById).toHaveBeenCalledWith(
      10,
      501,
      expect.objectContaining({
        won_at: expect.any(String),
      })
    );
  });

  it('requires a reason before marking opportunity as lost', async () => {
    const wrapper = await mountModal();

    await lostReasonInput(wrapper).setValue('   ');
    await wrapper
      .find('[data-testid="kanban-opportunity-mark-lost"]')
      .trigger('click');

    expect(KanbanBoardsAPI.updateCardDetailsById).not.toHaveBeenCalled();
    expect(wrapper.text()).toContain('Enter a lost reason.');
  });

  it('marks opportunity as lost with reason', async () => {
    KanbanBoardsAPI.updateCardDetailsById.mockResolvedValue({
      data: buildCard({
        lostAt: '2026-07-23T12:00:00.000Z',
        lostReason: 'Preço',
      }),
    });
    const wrapper = await mountModal();

    expect(lostReasonInput(wrapper).text()).toContain('Sem resposta');
    await lostReasonInput(wrapper).setValue('Preço');
    await wrapper
      .find('[data-testid="kanban-opportunity-mark-lost"]')
      .trigger('click');
    await flushPromises();

    expect(KanbanBoardsAPI.updateCardDetailsById).toHaveBeenCalledWith(
      10,
      501,
      expect.objectContaining({
        lost_at: expect.any(String),
        lost_reason: 'Preço',
      })
    );
  });

  it('clears dates with null', async () => {
    KanbanBoardsAPI.updateCardDetailsById.mockResolvedValue({
      data: buildCard({ startsAt: null, dueAt: null }),
    });
    const wrapper = await mountModal();

    await startsAtInput(wrapper).setValue('');
    await dueAtInput(wrapper).setValue('');
    await wrapper.find('form').trigger('submit');
    await flushPromises();

    expect(KanbanBoardsAPI.updateCardDetailsById).toHaveBeenCalledWith(
      10,
      501,
      expect.objectContaining({ starts_at: null, due_at: null })
    );
  });

  it('rejects blank title locally', async () => {
    const wrapper = await mountModal();

    await subjectInput(wrapper).setValue('   ');
    await wrapper.find('form').trigger('submit');

    expect(KanbanBoardsAPI.updateCardDetailsById).not.toHaveBeenCalled();
    expect(wrapper.text()).toContain('Title is required.');
  });

  it('disables save while pending', async () => {
    KanbanBoardsAPI.updateCardDetailsById.mockReturnValue(
      new Promise(() => {})
    );
    const wrapper = await mountModal();

    await wrapper.find('form').trigger('submit');

    expect(saveButton(wrapper).attributes('disabled')).toBeDefined();

    await wrapper.find('form').trigger('submit');
    expect(KanbanBoardsAPI.updateCardDetailsById).toHaveBeenCalledTimes(1);
  });

  it('emits updated on successful save', async () => {
    const updatedCard = buildCard({ description: 'Updated note' });
    KanbanBoardsAPI.updateCardDetailsById.mockResolvedValue({
      data: updatedCard,
    });
    const wrapper = await mountModal();

    await wrapper.find('form').trigger('submit');
    await flushPromises();

    expect(wrapper.emitted('updated')).toEqual([[updatedCard]]);
  });

  it('renders linked conversation and open action', async () => {
    const wrapper = await mountModal();

    expect(
      wrapper.find('[data-testid="kanban-opportunity-conversation"]').text()
    ).toContain('Conversation #42');
    expect(
      wrapper
        .find('[data-testid="kanban-opportunity-open-conversation"]')
        .text()
    ).toContain('Open conversation');
  });

  it('emits open conversation with card payload', async () => {
    const card = buildCard();
    const wrapper = await mountModal({ card });

    await wrapper
      .find('[data-testid="kanban-opportunity-open-conversation"]')
      .trigger('click');

    expect(wrapper.emitted('openConversation')).toEqual([[card]]);
  });

  it('renders no linked conversation for unlinked card', async () => {
    const wrapper = await mountModal({
      card: buildCard({ conversationId: null, conversation: null }),
    });

    expect(
      wrapper.find('[data-testid="kanban-opportunity-no-conversation"]').text()
    ).toContain('No linked conversation');
  });

  it('renders linked contact', async () => {
    const wrapper = await mountModal();

    expect(
      wrapper.find('[data-testid="kanban-opportunity-contact"]').text()
    ).toContain('Acme Buyer');
  });

  it('renders assignee as read-only text', async () => {
    const wrapper = await mountModal();

    expect(
      wrapper.find('[data-testid="kanban-opportunity-assignee"]').text()
    ).toContain('Jane Agent');
  });

  it('loads assigned card labels through getCardLabels', async () => {
    await mountModal();

    expect(KanbanBoardsAPI.getCardLabels).toHaveBeenCalledWith(10, 501);
  });

  it('loads available account labels through existing pattern', async () => {
    await mountModal();

    expect(storeMocks.dispatch).toHaveBeenCalledWith('labels/get');
  });

  it('renders label title and color', async () => {
    const wrapper = await mountModal();
    const firstLabel = labelButtons(wrapper)[0];

    expect(firstLabel.text()).toContain('hot');
    expect(firstLabel.find('span').element.style.backgroundColor).toBe(
      'rgb(255, 0, 0)'
    );
  });

  it('marks assigned labels as selected', async () => {
    const wrapper = await mountModal();

    expect(labelButtons(wrapper)[0].attributes('aria-pressed')).toBe('true');
    expect(labelButtons(wrapper)[1].attributes('aria-pressed')).toBe('false');
  });

  it('labels continue saving through updateCardLabels', async () => {
    KanbanBoardsAPI.updateCardLabels.mockResolvedValue({
      data: { payload: labels },
    });
    const wrapper = await mountModal();

    await labelButtons(wrapper)[1].trigger('click');
    await saveLabelsButton(wrapper).trigger('click');
    await flushPromises();

    expect(KanbanBoardsAPI.updateCardLabels).toHaveBeenCalledWith(10, 501, [
      'hot',
      'enterprise',
    ]);
  });

  it('labels save preserves scalar form state', async () => {
    const wrapper = await mountModal();

    await subjectInput(wrapper).setValue('Modified subject');
    await descriptionInput(wrapper).setValue('Modified description');
    await saveLabelsButton(wrapper).trigger('click');
    await flushPromises();

    expect(subjectInput(wrapper).element.value).toBe('Modified subject');
    expect(descriptionInput(wrapper).element.value).toBe(
      'Modified description'
    );
    expect(startsAtInput(wrapper).element.value).toBe('2026-06-01T09:00');
    expect(dueAtInput(wrapper).element.value).toBe('2026-06-05T18:00');
  });

  it('does not render an add-note action', async () => {
    const wrapper = await mountModal();

    expect(
      wrapper.find('[data-testid="kanban-opportunity-add-note"]').exists()
    ).toBe(false);
    expect(wrapper.text()).not.toContain('Add note');
  });

  it('emits close from cancel and close actions', async () => {
    const wrapper = await mountModal();

    await wrapper
      .find('[data-testid="kanban-opportunity-cancel"]')
      .trigger('click');
    await wrapper
      .find('[data-testid="kanban-opportunity-close"]')
      .trigger('click');

    expect(wrapper.emitted('close')).toHaveLength(2);
  });
});
