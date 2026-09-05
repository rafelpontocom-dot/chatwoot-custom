import { flushPromises, mount } from '@vue/test-utils';
import KanbanOpportunityDetailsModal from '../KanbanOpportunityDetailsModal.vue';
import KanbanBoardsAPI from 'dashboard/api/kanbanBoards';
import ContactAPI from 'dashboard/api/contacts';
import FinanceAPI from 'dashboard/api/finance';
import FormsAPI from 'dashboard/api/forms';
import { copyTextToClipboard } from 'shared/helpers/clipboard';

const storeMocks = vi.hoisted(() => ({
  labels: [],
  attributeDefinitions: [],
  currentAccount: { permissions: ['administrator'] },
  dispatch: vi.fn(),
}));
const formsInvitationMocks = vi.hoisted(() => ({
  open: vi.fn(),
}));
const formsSubmissionMocks = vi.hoisted(() => ({
  open: vi.fn(),
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
        'KANBAN.OPPORTUNITY_DETAILS.PIPELINE_AND_STAGE': 'Pipeline and stage',
        'KANBAN.OPPORTUNITY_DETAILS.CURRENT_PIPELINE': 'Current',
        'KANBAN.OPPORTUNITY_DETAILS.NO_PIPELINE_STAGES': 'No pipeline stages',
        'KANBAN.OPPORTUNITY_DETAILS.DAYS_IN_STAGE': '{count} days in stage',
        'KANBAN.OPPORTUNITY_DETAILS.SAVE_BEFORE_TRANSFER':
          'Save before transfer',
        'KANBAN.OPPORTUNITY_DETAILS.CUSTOM_FIELDS': 'Custom fields',
        'KANBAN.OPPORTUNITY_DETAILS.TABS.GENERAL': 'General',
        'KANBAN.OPPORTUNITY_DETAILS.TABS.MARKETING': 'Marketing',
        'KANBAN.OPPORTUNITY_DETAILS.TABS.TIMELINE': 'Timeline',
        'KANBAN.OPPORTUNITY_DETAILS.EXPECTED_CLOSE_DATE': 'Expected close date',
        'KANBAN.OPPORTUNITY_DETAILS.TIMELINE.EMPTY': 'No changes yet',
        'KANBAN.OPPORTUNITY_DETAILS.TIMELINE.ENTERED_STAGE': 'Entered {stage}',
        'KANBAN.OPPORTUNITY_DETAILS.TIMELINE.CREATED_IN_STAGE':
          'Created in {stage}',
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
        'KANBAN.OPPORTUNITY_DETAILS.GROUPS.COMMERCIAL': 'Commercial',
        'KANBAN.OPPORTUNITY_DETAILS.QUESTIONS.OWNER': 'Owner',
        'KANBAN.OPPORTUNITY_DETAILS.OWNER_NONE': 'No owner',
        'KANBAN.OPPORTUNITY_DETAILS.QUESTIONS.AGREEMENT': 'What was agreed?',
        'KANBAN.OPPORTUNITY_DETAILS.FIELD_AMOUNT_HINT':
          'Forecast value of the sale, not the issued charge.',
        'KANBAN.OPPORTUNITY_DETAILS.QUESTIONS.SCENARIO':
          'What is the commercial outlook?',
        'KANBAN.OPPORTUNITY_DETAILS.QUESTIONS.NEXT_ACTION':
          'What needs to happen now?',
        'KANBAN.OPPORTUNITY_DETAILS.CADENCE.TITLE': 'Follow-up cadence',
        'KANBAN.OPPORTUNITY_DETAILS.CADENCE.DESCRIPTION':
          'Internal reminders only. No automatic customer messages.',
        'KANBAN.OPPORTUNITY_DETAILS.CADENCE.SELECT': 'Select a cadence',
        'KANBAN.OPPORTUNITY_DETAILS.CADENCE.START': 'Start cadence',
        'KANBAN.OPPORTUNITY_DETAILS.CADENCE.CANCEL': 'Pause cadence',
        'KANBAN.OPPORTUNITY_DETAILS.CADENCE.NONE':
          'No active cadence is configured for this board.',
        'KANBAN.OPPORTUNITY_DETAILS.CADENCE.STATUS': 'Status: {status}',
        'KANBAN.OPPORTUNITY_DETAILS.CADENCE.NEXT_STEP': 'Next step: {date}',
        'KANBAN.OPPORTUNITY_DETAILS.CADENCE.LOAD_ERROR':
          'Could not load follow-up cadences.',
        'KANBAN.OPPORTUNITY_DETAILS.CADENCE.SAVE_ERROR':
          'Could not update the follow-up cadence.',
        'KANBAN.OPPORTUNITY_DETAILS.UNSAVED_CHANGES.TITLE':
          'Discard unsaved changes?',
        'KANBAN.OPPORTUNITY_DETAILS.UNSAVED_CHANGES.DESCRIPTION':
          'Your changes will be lost if you close this opportunity.',
        'KANBAN.OPPORTUNITY_DETAILS.UNSAVED_CHANGES.KEEP_EDITING':
          'Keep editing',
        'KANBAN.OPPORTUNITY_DETAILS.UNSAVED_CHANGES.DISCARD': 'Discard',
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
    transferCardById: vi.fn(),
    getCardTimeline: vi.fn(),
    getCardLabels: vi.fn(),
    updateCardLabels: vi.fn(),
    getCadences: vi.fn(),
    getCardCadence: vi.fn(),
    enrollCardInCadence: vi.fn(),
    cancelCardCadence: vi.fn(),
  },
}));

vi.mock('dashboard/api/contacts', () => ({
  default: {
    update: vi.fn(),
  },
}));

vi.mock('dashboard/api/finance', () => ({
  default: {
    getModule: vi.fn(),
    getProviderConnections: vi.fn(),
    getPayments: vi.fn(),
    getPayment: vi.fn(),
  },
}));

vi.mock('dashboard/api/forms', () => ({
  default: {
    getCardContext: vi.fn(),
    resolvePendingAction: vi.fn(),
    revokeInvitation: vi.fn(),
  },
}));

vi.mock('shared/helpers/clipboard', () => ({
  copyTextToClipboard: vi.fn(),
}));

vi.mock('dashboard/composables/store', async () => {
  const { computed } = await vi.importActual('vue');

  return {
    useStore: () => ({ dispatch: storeMocks.dispatch }),
    useMapGetter: key => {
      if (key === 'getCurrentAccount') {
        return computed(() => storeMocks.currentAccount);
      }

      if (key === 'attributes/getAttributesByModel') {
        return computed(
          () => model =>
            storeMocks.attributeDefinitions.filter(
              definition => definition.attribute_model === model
            )
        );
      }

      return computed(() => storeMocks.labels);
    },
  };
});

const nextInputStub = {
  inheritAttrs: false,
  props: [
    'modelValue',
    'label',
    'message',
    'messageType',
    'type',
    'autofocus',
    'placeholder',
  ],
  emits: ['update:modelValue', 'input'],
  template: `
    <label>
      <span>{{ label }}</span>
      <input
        v-bind="$attrs"
        :type="type || 'text'"
        :value="modelValue"
        :placeholder="placeholder"
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
  expectedCloseDate: '2026-08-15',
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
  timeline = [
    {
      id: 1,
      event_type: 'card_created',
      occurred_at: '2026-07-21T12:00:00Z',
      actor: { name: 'Jane Agent' },
      changes: {},
    },
  ],
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
  customFieldSections = [],
  calendarEnabled = false,
  boards = [],
  financeModule = { enabled: false },
  financeConnections = [],
  financePayments = [],
} = {}) => {
  storeMocks.labels = accountLabels;
  storeMocks.dispatch.mockResolvedValue();
  KanbanBoardsAPI.getCadences.mockResolvedValue({ data: [] });
  KanbanBoardsAPI.getCardCadence.mockResolvedValue({
    data: { enrollment: null },
  });
  FinanceAPI.getModule.mockResolvedValue({ data: financeModule });
  FinanceAPI.getProviderConnections.mockResolvedValue({
    data: financeConnections,
  });
  FinanceAPI.getPayments.mockResolvedValue({ data: financePayments });
  FormsAPI.getCardContext.mockResolvedValue({
    data: { invitations: [], submissions: [] },
  });

  if (resolveLabels) {
    KanbanBoardsAPI.getCardLabels.mockResolvedValue({
      data: { payload: assignedLabels },
    });
  }

  if (resolveLoad) {
    KanbanBoardsAPI.showCardById.mockResolvedValue({ data: card });
    KanbanBoardsAPI.getCardTimeline.mockResolvedValue({ data: timeline });
  }

  const wrapper = mount(KanbanOpportunityDetailsModal, {
    props: {
      boardId: 10,
      boardName: 'Sales funnel',
      boards,
      cardId: 501,
      stages: [
        { id: 1, name: 'Qualification', category: 'open' },
        { id: 2, name: 'Proposal sent', category: 'open' },
        { id: 3, name: 'Won', category: 'won' },
        { id: 4, name: 'Lost', category: 'lost' },
      ],
      nextActionTypes: ['Enviar proposta', 'Enviar link de pagamento'],
      lostReasonOptions: ['Preço', 'Sem resposta'],
      customFieldDefinitions,
      customFieldSections,
      ownerOptions: [
        { value: 7, label: 'Jane Agent' },
        { value: 8, label: 'Ana Paula' },
      ],
      canManageFields: true,
      calendarEnabled,
    },
    global: {
      stubs: {
        NextInput: nextInputStub,
        NextButton: nextButtonStub,
        KanbanCalendarAppointmentsSection: {
          template:
            '<section data-testid="kanban-opportunity-calendar-tab-content" />',
        },
        FinancePaymentDialog: {
          template: '<section data-testid="finance-payment-dialog" />',
        },
        FinancePaymentDetailsDialog: {
          setup(_, { expose }) {
            expose({ open: vi.fn() });
          },
          template: '<section data-testid="finance-payment-details-dialog" />',
        },
        FormsInvitationDialog: {
          setup(_, { expose }) {
            expose({ open: formsInvitationMocks.open });
          },
          template: '<section data-testid="forms-invitation-dialog" />',
        },
        FormsSubmissionDetailsDialog: {
          setup(_, { expose }) {
            expose({ open: formsSubmissionMocks.open });
          },
          template: '<section data-testid="forms-submission-details-dialog" />',
        },
      },
    },
  });

  if (resolveLoad) await flushPromises();

  return wrapper;
};

// Os campos do bloco comercial agora leem como linha de 32px e só viram campo
// ao serem abertos. Como cada linha guarda o seu próprio estado, abrir todas de
// uma vez devolve ao teste exatamente o DOM que ele esperava antes.
const abrirLinhas = async wrapper => {
  await Promise.all(
    wrapper
      .findAll('[data-testid^="kanban-row-"]')
      .map(linha => linha.trigger('click'))
  );
  await wrapper.vm.$nextTick();
  return wrapper;
};

const subjectInput = wrapper =>
  wrapper.find('[data-testid="kanban-opportunity-header-subject"]');
const descriptionInput = wrapper =>
  wrapper.find('[data-testid="kanban-opportunity-description"]');
const amountInput = wrapper =>
  wrapper.find('[data-testid="kanban-opportunity-amount"]');
// Os campos personalizados passaram a usar o `RaevoFieldRow`, como os nativos:
// a linha está em repouso e o controlo só existe depois de se carregar nela.
// O ajudante abre a linha, para as asserções continuarem a falar de controlos.
const contactInput = async (wrapper, key, testid) => {
  const existente = wrapper.find(`[data-testid="${testid}"]`);
  if (existente.exists()) return existente;

  const linha = wrapper.find(`[data-testid="kanban-row-contact-${key}"]`);
  if (linha.exists()) await linha.trigger('click');

  return wrapper.find(`[data-testid="${testid}"]`);
};

const customFieldInput = async (wrapper, key) => {
  const existente = wrapper.find(`[data-testid="kanban-custom-field-${key}"]`);
  if (existente.exists()) return existente;

  const linha = wrapper.find(`[data-testid="kanban-row-${key}"]`);
  if (linha.exists()) await linha.trigger('click');

  return wrapper.find(`[data-testid="kanban-custom-field-${key}"]`);
};
const startsAtInput = wrapper =>
  wrapper.find('[data-testid="kanban-opportunity-starts-at"]');
const dueAtInput = wrapper =>
  wrapper.find('[data-testid="kanban-opportunity-due-at"]');
const expectedCloseDateInput = wrapper =>
  wrapper.find('[data-testid="kanban-opportunity-expected-close-date"]');
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
const openLabels = wrapper =>
  wrapper
    .find('[data-testid="kanban-opportunity-toggle-labels"]')
    .trigger('click');
const openContactTab = wrapper =>
  wrapper
    .find('[data-testid="kanban-opportunity-tab-contact-details"]')
    .trigger('click');
const selectHeaderStage = (wrapper, stageId) =>
  wrapper
    .findComponent({ name: 'KanbanOpportunityPipelineMenu' })
    .vm.$emit('selectStage', { boardId: 10, stageId });

describe('KanbanOpportunityDetailsModal', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    storeMocks.labels = [];
    storeMocks.currentAccount = { permissions: ['administrator'] };
  });

  it('uses a single-column layout so opportunity details stay readable', async () => {
    const wrapper = await mountModal();
    const layout = wrapper.find('[data-testid="kanban-opportunity-layout"]');

    expect(
      layout.classes().some(className => className.startsWith('xl:grid-cols-'))
    ).toBe(false);
  });

  it('shows finance as a dedicated opportunity tab when the module is active', async () => {
    FinanceAPI.getProviderConnections.mockResolvedValue({ data: [] });
    const wrapper = await mountModal({ financeModule: { enabled: true } });

    expect(
      wrapper.find('[data-testid="kanban-opportunity-tab-finance"]').exists()
    ).toBe(true);
  });

  it('does not offer charge creation to a financial read-only custom role', async () => {
    storeMocks.currentAccount = { permissions: ['finance_view'] };
    const wrapper = await mountModal({
      financeModule: { enabled: true },
      financeConnections: [{ id: 11, provider: 'asaas', status: 'connected' }],
    });

    await wrapper
      .find('[data-testid="kanban-opportunity-tab-finance"]')
      .trigger('click');

    expect(
      wrapper.find('[data-testid="kanban-opportunity-new-payment"]').exists()
    ).toBe(false);
  });

  it('loads charges scoped to the open opportunity', async () => {
    copyTextToClipboard.mockResolvedValue();
    const wrapper = await mountModal({
      financeModule: { enabled: true },
      financePayments: [
        {
          id: 31,
          amount_cents: 15025,
          currency: 'BRL',
          description: 'Consulta',
          due_on: '2026-09-01',
          invoice_url: 'https://pay.example/31',
          status: 'pending',
        },
      ],
    });

    await wrapper
      .find('[data-testid="kanban-opportunity-tab-finance"]')
      .trigger('click');
    await flushPromises();

    expect(FinanceAPI.getPayments).toHaveBeenCalledWith({
      kanban_card_id: 501,
    });
    expect(
      wrapper.find('[data-testid="kanban-opportunity-finance"]').text()
    ).toContain('Consulta');
    await wrapper
      .find('[data-testid="kanban-opportunity-copy-payment-link"]')
      .trigger('click');
    expect(copyTextToClipboard).toHaveBeenCalledWith('https://pay.example/31');
    await wrapper
      .find('[data-testid="kanban-opportunity-payment-details"]')
      .trigger('click');
    expect(wrapper.vm.$refs.paymentDetailsDialog.open).toHaveBeenCalledWith(31);
    await wrapper
      .find('[data-testid="kanban-opportunity-send-payment-link"]')
      .trigger('click');
    expect(wrapper.emitted('sendPaymentLink')).toEqual([
      [
        {
          card: expect.objectContaining({ id: 501, conversationId: 42 }),
          payment: expect.objectContaining({ id: 31 }),
        },
      ],
    ]);
  });

  it('shows read-only financial indicators derived from linked charges', async () => {
    const wrapper = await mountModal({
      financeModule: { enabled: true },
      financePayments: [
        {
          id: 31,
          amount_cents: 15025,
          currency: 'BRL',
          status: 'received',
          paid_at: '2026-09-01T10:30:00Z',
        },
      ],
    });

    await wrapper
      .find('[data-testid="kanban-opportunity-tab-finance"]')
      .trigger('click');
    await flushPromises();

    const summary = wrapper.get(
      '[data-testid="kanban-opportunity-finance-summary"]'
    );
    expect(summary.text()).toContain('FINANCE.SUMMARY.STATUS');
    expect(summary.text()).toContain('FINANCE.PAYMENTS.STATUS.RECEIVED');
    expect(summary.text()).toContain('FINANCE.SUMMARY.RECEIVED_AMOUNT');
  });

  it('keeps the pipeline stage in the compact header instead of a side context panel', async () => {
    const wrapper = await mountModal();

    expect(
      wrapper.find('[data-testid="kanban-opportunity-header-stage"]').exists()
    ).toBe(true);
    expect(
      wrapper
        .find('[data-testid="kanban-opportunity-commercial-context"]')
        .exists()
    ).toBe(false);
  });

  it('puts conversation access beside the title controls', async () => {
    const wrapper = await mountModal();

    const conversationButton = wrapper.find(
      '[data-testid="kanban-opportunity-header-open-conversation"]'
    );
    expect(conversationButton.exists()).toBe(true);

    await conversationButton.trigger('click');

    expect(wrapper.emitted('openConversation')).toHaveLength(1);
  });

  it('keeps contact editable and removes the one-field conversation agent tab', async () => {
    const wrapper = await mountModal({
      card: buildCard({
        contact: {
          id: 91,
          name: 'Acme Buyer',
          email: 'buyer@example.com',
          phone_number: '+55 62 99999-0000',
        },
      }),
    });

    expect(
      wrapper
        .find('[data-testid="kanban-opportunity-tab-contact-details"]')
        .text()
    ).toBe('Contact');
    expect(
      wrapper
        .find('[data-testid="kanban-opportunity-tab-agent-details"]')
        .exists()
    ).toBe(false);

    await wrapper
      .find('[data-testid="kanban-opportunity-tab-contact-details"]')
      .trigger('click');

    expect(
      (await contactInput(wrapper, 'email', 'kanban-opportunity-contact-email'))
        .element.value
    ).toBe('buyer@example.com');
    expect(
      (await contactInput(wrapper, 'phone', 'kanban-opportunity-contact-phone'))
        .element.value
    ).toBe('+55 62 99999-0000');
    expect(
      (
        await contactInput(wrapper, 'name', 'kanban-opportunity-contact-name')
      ).exists()
    ).toBe(true);
  });

  it('saves basic contact details from the opportunity contact tab', async () => {
    ContactAPI.update.mockResolvedValue({
      data: { id: 91, name: 'Acme Updated', phone_number: '+55 62 98888-0000' },
    });
    const wrapper = await mountModal();

    await openContactTab(wrapper);
    await (
      await contactInput(wrapper, 'name', 'kanban-opportunity-contact-name')
    ).setValue('Acme Updated');
    await wrapper
      .find('[data-testid="kanban-opportunity-save-contact"]')
      .trigger('click');
    await flushPromises();

    expect(ContactAPI.update).toHaveBeenCalledWith(
      91,
      expect.objectContaining({ name: 'Acme Updated' })
    );
  });

  it('shows Calendar as its own tab instead of rendering it in General', async () => {
    const wrapper = await mountModal({ calendarEnabled: true });

    expect(
      wrapper.find('[data-testid="kanban-opportunity-tab-calendar"]').exists()
    ).toBe(true);
    expect(
      wrapper
        .find('[data-testid="kanban-opportunity-calendar-tab-content"]')
        .exists()
    ).toBe(false);

    await wrapper
      .find('[data-testid="kanban-opportunity-tab-calendar"]')
      .trigger('click');

    expect(
      wrapper
        .find('[data-testid="kanban-opportunity-calendar-tab-content"]')
        .exists()
    ).toBe(true);
  });

  it('renders contact data as a vertical list and keeps values from overlapping', async () => {
    const wrapper = await mountModal({
      card: buildCard({
        contact: {
          id: 91,
          name: 'Acme Buyer',
          phone_number: '+55 62 99999-9999',
          email: 'contato-com-endereco-muito-longo@example.com',
        },
      }),
    });

    await openContactTab(wrapper);
    const contactDetails = wrapper.find(
      '[data-testid="kanban-opportunity-contact-details"]'
    );

    expect(contactDetails.classes()).toContain('grid');
    // O contacto usa a mesma linha dos restantes campos: o valor lê-se em
    // repouso, e o controlo só existe depois de se abrir a linha.
    expect(
      wrapper.find('[data-testid="kanban-row-contact-email"]').text()
    ).toContain('contato-com-endereco-muito-longo@example.com');
    expect(
      (await contactInput(wrapper, 'email', 'kanban-opportunity-contact-email'))
        .element.value
    ).toBe('contato-com-endereco-muito-longo@example.com');
  });

  it('uses compact in-field instructions for commercial and planning fields', async () => {
    const wrapper = await mountModal();
    await abrirLinhas(wrapper);

    // O nome do campo vive no rotulo acima dele, nunca repetido como
    // placeholder: era o "Valor / Valor" que a auditoria apontou.
    expect(amountInput(wrapper).attributes('placeholder')).toBeUndefined();
    const amountId = amountInput(wrapper).attributes('id');
    expect(wrapper.find(`label[for="${amountId}"]`).text()).toContain('Value');

    const closeId = expectedCloseDateInput(wrapper).attributes('id');
    expect(wrapper.find(`label[for="${closeId}"]`).text()).toContain(
      'Expected close date'
    );
    expect(startsAtInput(wrapper).attributes('aria-label')).toBe('Start date');
  });

  it('offers contextual field management to administrators', async () => {
    const wrapper = await mountModal();

    await wrapper
      .find('[data-testid="kanban-opportunity-manage-fields"]')
      .trigger('click');

    expect(wrapper.emitted('manageFields')).toHaveLength(1);
  });

  it('renders custom tabs and offers a plus shortcut to create another tab', async () => {
    const wrapper = await mountModal({
      customFieldSections: [{ key: 'consulta', label: 'Consulta' }],
    });

    expect(
      wrapper.find('[data-testid="kanban-opportunity-tab-consulta"]').text()
    ).toBe('Consulta');
    expect(
      wrapper.find('[data-testid="kanban-opportunity-tab-marketing"]').text()
    ).toBe('Marketing');
    await wrapper
      .find('[data-testid="kanban-opportunity-add-tab"]')
      .trigger('click');

    expect(wrapper.emitted('manageFields').at(-1)).toEqual([
      { action: 'newTab' },
    ]);
  });

  it('shows the read-only IA tab when the board has IA fields and the runtime is inactive', async () => {
    const aiDefinitions = [
      {
        key: 'raevo_ai_summary',
        label: 'Resumo do atendimento',
        fieldType: 'textarea',
        layout: { section: 'ai', position: 1, width: 'full' },
      },
      {
        key: 'raevo_ai_status',
        label: 'Status do atendimento',
        fieldType: 'select',
        layout: { section: 'ai', position: 2, width: 'full' },
      },
    ];
    const card = buildCard({
      customFieldValues: {
        raevo_ai_summary: 'Paciente quer atendimento à tarde.',
        raevo_ai_status: 'pre_agendado',
      },
    });

    const inactive = await mountModal({
      card,
      customFieldDefinitions: aiDefinitions,
      customFieldSections: [{ key: 'ai', label: 'IA' }],
    });
    await inactive
      .find('[data-testid="kanban-opportunity-tab-ai"]')
      .trigger('click');

    expect(
      inactive.find('[data-testid="raevo-ai-opportunity-panel"]').text()
    ).toContain('Paciente quer atendimento à tarde.');
    expect(
      inactive
        .find('[data-testid="raevo-ai-opportunity-panel"]')
        .find('input, textarea, select')
        .exists()
    ).toBe(false);
  });

  it('merges legacy aliases into the standard general and marketing tabs', async () => {
    const wrapper = await mountModal({
      customFieldDefinitions: [
        {
          key: 'resumo',
          label: 'Resumo',
          fieldType: 'text',
          layout: { section: 'Detail' },
        },
        {
          key: 'origem',
          label: 'Origem',
          fieldType: 'text',
          layout: { section: 'Marketing' },
        },
      ],
      customFieldSections: [
        { key: 'Geral', label: 'Geral' },
        { key: 'Marketing', label: 'Marketing' },
      ],
    });

    expect(
      wrapper.findAll('[data-testid="kanban-opportunity-tab-details"]')
    ).toHaveLength(1);
    expect(
      wrapper.findAll('[data-testid="kanban-opportunity-tab-marketing"]')
    ).toHaveLength(1);
    expect(wrapper.text()).not.toContain('Detail');
  });

  it('links the active opportunity tab to its content panel', async () => {
    const wrapper = await mountModal();
    const detailsTab = wrapper.find(
      '[data-testid="kanban-opportunity-tab-details"]'
    );
    const layout = wrapper.find('[data-testid="kanban-opportunity-layout"]');

    expect(detailsTab.attributes('aria-controls')).toBe(
      'kanban-opportunity-tab-panel'
    );
    expect(layout.attributes('role')).toBe('tabpanel');
    expect(layout.attributes('aria-labelledby')).toBe(
      'kanban-opportunity-tab-details'
    );
  });

  it('navigates opportunity tabs with the keyboard', async () => {
    const wrapper = await mountModal();

    await wrapper
      .find('[data-testid="kanban-opportunity-tab-details"]')
      .trigger('keydown', { key: 'ArrowRight' });

    expect(
      wrapper
        .find('[data-testid="kanban-opportunity-tab-contact-details"]')
        .attributes('aria-selected')
    ).toBe('true');
  });

  it('loads detail through showCardById', async () => {
    await mountModal();

    expect(KanbanBoardsAPI.showCardById).toHaveBeenCalledWith(10, 501);
    expect(KanbanBoardsAPI.getCardTimeline).toHaveBeenCalledWith(10, 501);
  });

  it('edits the expected close date and sends it with the card', async () => {
    KanbanBoardsAPI.updateCardDetailsById.mockResolvedValue({
      data: buildCard({ expectedCloseDate: '2026-09-01' }),
    });
    const wrapper = await mountModal();
    await abrirLinhas(wrapper);

    expect(expectedCloseDateInput(wrapper).element.value).toBe('2026-08-15');
    await expectedCloseDateInput(wrapper).setValue('2026-09-01');
    await wrapper.find('form').trigger('submit');
    await flushPromises();

    expect(KanbanBoardsAPI.updateCardDetailsById).toHaveBeenCalledWith(
      10,
      501,
      expect.objectContaining({ expected_close_date: '2026-09-01' })
    );
  });

  it('shows the immutable commercial timeline in its own tab', async () => {
    const wrapper = await mountModal();

    await wrapper
      .find('[data-testid="kanban-opportunity-tab-timeline"]')
      .trigger('click');

    expect(
      wrapper.find('[data-testid="kanban-opportunity-timeline"]').text()
    ).toContain('Jane Agent');
  });

  it('uses the immutable stage snapshot in the timeline label', async () => {
    const wrapper = await mountModal({
      timeline: [
        {
          id: 10,
          event_type: 'stage_changed',
          occurred_at: '2026-07-21T12:00:00Z',
          actor: { name: 'Jane Agent' },
          metadata: { to_stage: { name: 'Proposta enviada' } },
        },
      ],
    });

    await wrapper
      .find('[data-testid="kanban-opportunity-tab-timeline"]')
      .trigger('click');

    expect(
      wrapper.find('[data-testid="kanban-opportunity-timeline"]').text()
    ).toContain('Entered Proposta enviada');
  });

  it('renders a responsive single-column layout', async () => {
    const wrapper = await mountModal();

    expect(wrapper.text()).toContain('Enterprise expansion');
    expect(wrapper.classes()).toEqual(
      expect.arrayContaining([
        'mx-auto',
        'w-full',
        'max-w-[calc(100vw-1rem)]',
        '2xl:max-w-[88rem]',
      ])
    );
    expect(
      wrapper.find('[data-testid="kanban-opportunity-form"]').classes()
    ).toContain('grid');
    expect(
      wrapper.find('[data-testid="kanban-opportunity-layout"]').classes()
    ).not.toContain('xl:grid-cols-[minmax(0,1fr)_18rem]');
  });

  it('keeps drawer content in one column so the commercial context cannot overlap fields', async () => {
    const wrapper = await mountModal();
    await wrapper.setProps({ drawerMode: true });

    expect(
      wrapper.find('[data-testid="kanban-opportunity-layout"]').classes()
    ).not.toContain('lg:grid-cols-[minmax(0,1fr)_18rem]');
  });

  it('renders title, compact description, and amount controls', async () => {
    const wrapper = await mountModal();
    await abrirLinhas(wrapper);

    expect(wrapper.find('h2').text()).toContain('Enterprise expansion');
    await wrapper
      .find('[data-testid="kanban-opportunity-edit-subject"]')
      .trigger('click');
    expect(subjectInput(wrapper).classes()).toContain('w-full');
    // A casca do textarea agora vem do RaevoField, unica para todo o produto.
    expect(descriptionInput(wrapper).classes()).toEqual(
      expect.arrayContaining(['w-full', 'min-h-20', 'rounded-lg'])
    );
    expect(descriptionInput(wrapper).attributes('rows')).toBe('3');
    expect(amountInput(wrapper).element.value).toBe('125.50');
  });

  it('organizes the summary around commercial questions instead of a generic form card', async () => {
    const wrapper = await mountModal();
    const group = wrapper.find(
      '[data-testid="kanban-opportunity-commercial-group"]'
    );

    expect(group.exists()).toBe(true);
    // Em repouso os rótulos já são legíveis: a linha mostra rótulo e valor.
    await abrirLinhas(wrapper);
    expect(group.classes()).not.toContain('rounded-lg');
    expect(group.text()).toContain('Owner');
    expect(group.text()).toContain('What was agreed?');
    // Valor e Previsao ficam no Geral, lado a lado, sem titulo de secao proprio:
    // eles sao previsao comercial, nao a cobranca emitida (essa vive no Financeiro).
    expect(group.text()).toContain('Value');
    expect(group.text()).toContain('Expected close date');
    expect(group.text()).not.toContain('What is the commercial outlook?');
    // O rotulo nao pode se repetir como placeholder do proprio campo.
    expect(
      group
        .find('[data-testid="kanban-opportunity-amount"]')
        .attributes('placeholder')
    ).toBeUndefined();
  });

  it('puts the next action before commercial context in the summary', async () => {
    const wrapper = await mountModal();
    const details = wrapper.text();

    expect(details).toContain('What needs to happen now?');
    expect(details.indexOf('What needs to happen now?')).toBeLessThan(
      details.indexOf('Owner')
    );
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
    await abrirLinhas(wrapper);

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

    expect(wrapper.text()).not.toContain('Custom fields');
    expect(
      (await customFieldInput(wrapper, 'consulta_realizada')).element.value
    ).toBe('Sim');
    expect(
      (await customFieldInput(wrapper, 'observacao_venda')).element.value
    ).toBe('Cliente quer fechar no WhatsApp');
  });

  it('organizes custom fields in tabs using their configured section', async () => {
    const wrapper = await mountModal({
      card: buildCard({
        customFieldValues: {
          qualificacao: 'Pronto para comprar',
          gclid: 'google-click-123',
        },
      }),
      customFieldDefinitions: [
        {
          key: 'qualificacao',
          label: 'Qualificação',
          fieldType: 'text',
          layout: { section: 'details', position: 1, width: 'full' },
        },
        {
          key: 'gclid',
          label: 'gclid',
          fieldType: 'text',
          layout: { section: 'marketing', position: 1, width: 'full' },
        },
      ],
    });

    expect(
      wrapper.find('[data-testid="kanban-opportunity-tab-details"]').text()
    ).toContain('General');
    expect(
      wrapper.find('[data-testid="kanban-opportunity-tab-marketing"]').text()
    ).toContain('Marketing');
    expect((await customFieldInput(wrapper, 'qualificacao')).exists()).toBe(
      true
    );
    expect((await customFieldInput(wrapper, 'gclid')).exists()).toBe(false);

    await wrapper
      .find('[data-testid="kanban-opportunity-tab-marketing"]')
      .trigger('click');

    expect((await customFieldInput(wrapper, 'qualificacao')).exists()).toBe(
      false
    );
    expect((await customFieldInput(wrapper, 'gclid')).element.value).toBe(
      'google-click-123'
    );
  });

  it('renders grouped custom fields as compact decision rows', async () => {
    const wrapper = await mountModal({
      card: buildCard({ customFieldValues: { data_consulta: '2026-08-20' } }),
      customFieldDefinitions: [
        {
          key: 'data_consulta',
          label: 'Data da consulta',
          fieldType: 'date',
          layout: { section: 'consulta', group: 'agenda', position: 1 },
        },
      ],
      customFieldSections: [
        {
          key: 'consulta',
          label: 'Consulta',
          groups: [{ key: 'agenda', label: 'Agenda', color: 'teal' }],
        },
      ],
    });

    await wrapper
      .find('[data-testid="kanban-opportunity-tab-consulta"]')
      .trigger('click');

    const group = wrapper.find(
      '[data-testid="kanban-opportunity-custom-fields"] section'
    );
    expect(group.text()).toContain('Agenda');
    expect(group.classes()).toContain('border-l-2');
    // A linha do campo personalizado é a mesma dos nativos: um só tratamento
    // de campo no painel, em vez de uma grelha própria por tipo de campo.
    expect(
      group.findAll('[data-testid="raevo-field-row"]').length
    ).toBeGreaterThan(0);
  });

  it('uses a configurable Financeiro tab for a financial workflow, not one tab per field', async () => {
    const wrapper = await mountModal({
      card: buildCard({
        customFieldValues: {
          forma_pagamento: 'Pix',
          data_pagamento: '2026-08-11',
        },
      }),
      customFieldDefinitions: [
        {
          key: 'forma_pagamento',
          label: 'Forma de pagamento',
          fieldType: 'select',
          options: ['Pix', 'Cartão'],
          layout: { section: 'financeiro', group: 'como_sera_pago' },
        },
        {
          key: 'data_pagamento',
          label: 'Data de pagamento',
          fieldType: 'date',
          layout: { section: 'financeiro', group: 'pagamento_aconteceu' },
        },
      ],
      customFieldSections: [
        {
          key: 'financeiro',
          label: 'Financeiro',
          groups: [
            { key: 'como_sera_pago', label: 'Como será pago?' },
            { key: 'pagamento_aconteceu', label: 'O pagamento aconteceu?' },
          ],
        },
      ],
    });

    await wrapper
      .find('[data-testid="kanban-opportunity-tab-financeiro"]')
      .trigger('click');

    const customFields = wrapper.find(
      '[data-testid="kanban-opportunity-custom-fields"]'
    );
    expect(customFields.text()).toContain('Como será pago?');
    expect(customFields.text()).toContain('O pagamento aconteceu?');
    expect(
      (await customFieldInput(wrapper, 'forma_pagamento')).element.value
    ).toBe('Pix');
    expect(
      (await customFieldInput(wrapper, 'data_pagamento')).element.value
    ).toBe('2026-08-11');
  });

  it('loads next action fields', async () => {
    const wrapper = await mountModal();
    await abrirLinhas(wrapper);

    expect(nextActionTypeInput(wrapper).element.value).toBe('Enviar proposta');
    expect(nextActionAtInput(wrapper).element.value).toBe('2026-07-20T15:00');
    expect(nextActionNoteInput(wrapper).element.value).toBe(
      'Send proposal by WhatsApp'
    );
  });

  it('loads owner field', async () => {
    const wrapper = await mountModal();
    await abrirLinhas(wrapper);

    expect(ownerInput(wrapper).element.value).toBe('7');
    expect(ownerInput(wrapper).text()).toContain('Ana Paula');
  });

  it('saves description with existing scalar fields', async () => {
    KanbanBoardsAPI.updateCardDetailsById.mockResolvedValue({
      data: buildCard({ description: 'Updated card note' }),
    });
    const wrapper = await mountModal();
    await abrirLinhas(wrapper);

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
    await abrirLinhas(wrapper);

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
    await abrirLinhas(wrapper);

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
    await abrirLinhas(wrapper);

    await amountInput(wrapper).setValue('199.90');
    await (
      await customFieldInput(wrapper, 'consulta_realizada')
    ).setValue('Não');
    await (
      await customFieldInput(wrapper, 'observacao_venda')
    ).setValue('Fechamento sem reunião');
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
    await abrirLinhas(wrapper);

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

  it('keeps the next action completion control in the section header', async () => {
    const wrapper = await mountModal();
    const section = wrapper.find(
      '[data-testid="kanban-opportunity-next-action-section"]'
    );

    expect(section.exists()).toBe(true);
    expect(
      section
        .find('[data-testid="kanban-opportunity-complete-next-action"]')
        .exists()
    ).toBe(true);
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

    expect(
      (await customFieldInput(wrapper, 'prioridade')).attributes('type')
    ).toBe('checkbox');
    expect(
      (await customFieldInput(wrapper, 'prioridade')).element.checked
    ).toBe(true);
    expect((await customFieldInput(wrapper, 'produtos')).element.multiple).toBe(
      true
    );
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

    expect((await customFieldInput(wrapper, 'aceitou')).element.checked).toBe(
      false
    );
    expect((await customFieldInput(wrapper, 'motivo')).exists()).toBe(true);
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

  it('records a won opportunity through the selected pipeline stage', async () => {
    KanbanBoardsAPI.updateCardDetailsById.mockResolvedValue({
      data: buildCard({ kanbanStageId: 3, wonAt: '2026-07-23T12:00:00.000Z' }),
    });
    const wrapper = await mountModal();

    await selectHeaderStage(wrapper, 3);
    await wrapper.find('form').trigger('submit');
    await flushPromises();

    expect(KanbanBoardsAPI.updateCardDetailsById).toHaveBeenCalledWith(
      10,
      501,
      expect.objectContaining({
        kanban_stage_id: 3,
      })
    );
  });

  it('transfers an opportunity when a stage from another pipeline is selected', async () => {
    KanbanBoardsAPI.transferCardById.mockResolvedValue({
      data: buildCard({ kanbanBoardId: 22, kanbanStageId: 23 }),
    });
    const wrapper = await mountModal({
      boards: [
        { id: 10, name: 'Sales funnel', stages_summary: [] },
        {
          id: 22,
          name: 'Onboarding',
          stages_summary: [{ id: 23, name: 'Activation' }],
        },
      ],
    });

    await wrapper
      .findComponent({ name: 'KanbanOpportunityPipelineMenu' })
      .vm.$emit('selectStage', { boardId: 22, stageId: 23 });
    await flushPromises();

    expect(KanbanBoardsAPI.transferCardById).toHaveBeenCalledWith(
      10,
      501,
      expect.objectContaining({ kanban_board_id: 22, kanban_stage_id: 23 })
    );
    expect(wrapper.emitted('transferred')).toEqual([
      [expect.objectContaining({ boardId: 22 })],
    ]);
  });

  it('asks for the loss reason before transferring an opportunity to a lost stage in another pipeline', async () => {
    KanbanBoardsAPI.transferCardById.mockResolvedValue({
      data: buildCard({ kanbanBoardId: 22, kanbanStageId: 24 }),
    });
    const wrapper = await mountModal({
      boards: [
        { id: 10, name: 'Sales funnel', stages_summary: [] },
        {
          id: 22,
          name: 'Onboarding',
          stages_summary: [{ id: 24, name: 'Not a fit', category: 'lost' }],
        },
      ],
    });

    await wrapper
      .findComponent({ name: 'KanbanOpportunityPipelineMenu' })
      .vm.$emit('selectStage', {
        boardId: 22,
        stageId: 24,
        stage: { id: 24, name: 'Not a fit', category: 'lost' },
      });
    await flushPromises();

    expect(KanbanBoardsAPI.transferCardById).not.toHaveBeenCalled();
    expect(
      wrapper
        .find('[data-testid="kanban-opportunity-transfer-lost-reason"]')
        .exists()
    ).toBe(true);

    await wrapper
      .find('[data-testid="kanban-opportunity-transfer-lost-reason"]')
      .setValue('Preço');
    await wrapper
      .find('[data-testid="kanban-opportunity-confirm-transfer"]')
      .trigger('click');
    await flushPromises();

    expect(KanbanBoardsAPI.transferCardById).toHaveBeenCalledWith(
      10,
      501,
      expect.objectContaining({
        kanban_board_id: 22,
        kanban_stage_id: 24,
        lost_reason: 'Preço',
      })
    );
  });

  it('requires a reason before saving an opportunity in a lost stage', async () => {
    const wrapper = await mountModal();

    await selectHeaderStage(wrapper, 4);
    await wrapper.find('form').trigger('submit');

    expect(KanbanBoardsAPI.updateCardDetailsById).not.toHaveBeenCalled();
    expect(wrapper.text()).toContain('Enter a lost reason.');
  });

  it('records a lost opportunity through the selected pipeline stage', async () => {
    KanbanBoardsAPI.updateCardDetailsById.mockResolvedValue({
      data: buildCard({
        kanbanStageId: 4,
        lostAt: '2026-07-23T12:00:00.000Z',
        lostReason: 'Preço',
      }),
    });
    const wrapper = await mountModal();

    await selectHeaderStage(wrapper, 4);
    expect(lostReasonInput(wrapper).text()).toContain('Sem resposta');
    await lostReasonInput(wrapper).setValue('Preço');
    await wrapper.find('form').trigger('submit');
    await flushPromises();

    expect(KanbanBoardsAPI.updateCardDetailsById).toHaveBeenCalledWith(
      10,
      501,
      expect.objectContaining({
        kanban_stage_id: 4,
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

  it('renders linked conversation as a compact title action', async () => {
    const wrapper = await mountModal();

    expect(
      wrapper
        .find('[data-testid="kanban-opportunity-header-open-conversation"]')
        .attributes('aria-label')
    ).toBe('Open conversation');
  });

  it('emits open conversation with card payload', async () => {
    const card = buildCard();
    const wrapper = await mountModal({ card });

    await wrapper
      .find('[data-testid="kanban-opportunity-header-open-conversation"]')
      .trigger('click');

    expect(wrapper.emitted('openConversation')).toEqual([[card]]);
  });

  it('renders no linked conversation for unlinked card', async () => {
    const wrapper = await mountModal({
      card: buildCard({ conversationId: null, conversation: null }),
    });

    expect(
      wrapper
        .find('[data-testid="kanban-opportunity-header-open-conversation"]')
        .exists()
    ).toBe(false);
  });

  it('renders linked contact details in the contact tab', async () => {
    const wrapper = await mountModal();
    await wrapper
      .find('[data-testid="kanban-opportunity-tab-contact-details"]')
      .trigger('click');

    expect(
      (await contactInput(wrapper, 'name', 'kanban-opportunity-contact-name'))
        .element.value
    ).toBe('Acme Buyer');
  });

  it('opens the invitation creator from the forms tab for administrators', async () => {
    const wrapper = await mountModal();

    await wrapper
      .find('[data-testid="kanban-opportunity-tab-forms"]')
      .trigger('click');
    await wrapper
      .find('[data-testid="kanban-opportunity-send-form"]')
      .trigger('click');

    expect(
      wrapper.find('[data-testid="kanban-opportunity-forms"]').exists()
    ).toBe(true);
    expect(formsInvitationMocks.open).toHaveBeenCalledTimes(1);
  });

  it('loads invitation and submission summaries when the forms tab opens', async () => {
    const wrapper = await mountModal();
    FormsAPI.getCardContext.mockResolvedValue({
      data: {
        invitations: [
          {
            id: 11,
            form_name: 'Pré-consulta',
            status: 'active',
            uses_count: 0,
            max_uses: 1,
            created_at: '2026-08-29T12:00:00Z',
            expires_at: '2026-08-31T12:00:00Z',
            sent_at: '2026-08-29T12:01:00Z',
            opened_at: '2026-08-29T12:03:00Z',
          },
        ],
        submissions: [
          { id: 12, form_name: 'Pré-consulta', status: 'submitted' },
        ],
      },
    });

    await wrapper
      .find('[data-testid="kanban-opportunity-tab-forms"]')
      .trigger('click');
    await flushPromises();

    expect(FormsAPI.getCardContext).toHaveBeenCalledWith(501);
    expect(wrapper.text()).toContain('Pré-consulta');
    expect(wrapper.text()).toContain('FORMS.INVITATION.CREATED_AT');
    expect(wrapper.text()).toContain('FORMS.INVITATION.EXPIRES_ON');
    expect(wrapper.text()).toContain('FORMS.INVITATION.SENT_AT');
    expect(wrapper.text()).toContain('FORMS.INVITATION.OPENED_AT');
  });

  it('revokes an available invitation from the opportunity history', async () => {
    const wrapper = await mountModal();
    FormsAPI.getCardContext.mockResolvedValue({
      data: {
        invitations: [
          {
            id: 11,
            form_name: 'Pré-consulta',
            status: 'active',
            uses_count: 0,
            max_uses: 1,
          },
        ],
        submissions: [],
      },
    });
    FormsAPI.revokeInvitation.mockResolvedValue({
      data: { id: 11, status: 'revoked' },
    });

    await wrapper
      .find('[data-testid="kanban-opportunity-tab-forms"]')
      .trigger('click');
    await flushPromises();
    await wrapper
      .find('[data-testid="kanban-opportunity-revoke-form-invitation-11"]')
      .trigger('click');
    await wrapper
      .find('[data-testid="form-invitation-revoke-confirm"]')
      .trigger('click');
    await flushPromises();

    expect(FormsAPI.revokeInvitation).toHaveBeenCalledWith(11);
    expect(
      wrapper
        .find('[data-testid="kanban-opportunity-form-invitation-status-11"]')
        .text()
    ).toBe('FORMS.INVITATION.STATUS.REVOKED');
  });

  it('opens a received form response without leaving the opportunity', async () => {
    const wrapper = await mountModal();
    FormsAPI.getCardContext.mockResolvedValue({
      data: {
        invitations: [],
        submissions: [
          { id: 12, form_name: 'Pré-consulta', status: 'submitted' },
        ],
      },
    });

    await wrapper
      .find('[data-testid="kanban-opportunity-tab-forms"]')
      .trigger('click');
    await flushPromises();
    await wrapper
      .find('[data-testid="kanban-opportunity-open-form-submission-12"]')
      .trigger('click');

    expect(formsSubmissionMocks.open).toHaveBeenCalledWith(12);
  });

  it('offers to confirm or dismiss what the form proposed but did not apply', async () => {
    const wrapper = await mountModal();
    FormsAPI.getCardContext.mockResolvedValue({
      data: {
        invitations: [],
        submissions: [
          {
            id: 12,
            form_name: 'Pré-consulta',
            status: 'submitted',
            pending_actions: [{ index: 0, kind: 'move_stage' }],
          },
        ],
      },
    });
    FormsAPI.resolvePendingAction.mockResolvedValue({
      data: { pending_actions: [] },
    });

    await wrapper
      .find('[data-testid="kanban-opportunity-tab-forms"]')
      .trigger('click');
    await flushPromises();

    expect(
      wrapper.find('[data-testid="kanban-pending-action-12-0"]').exists()
    ).toBe(true);

    await wrapper
      .find('[data-testid="kanban-pending-confirm-12-0"]')
      .trigger('click');
    await flushPromises();

    expect(FormsAPI.resolvePendingAction).toHaveBeenCalledWith(
      12,
      0,
      'confirm'
    );
    // Confirmar pode ter movido a etapa: quem abriu o card tem de reler.
    expect(wrapper.emitted('updated')).toBeTruthy();
    expect(
      wrapper.find('[data-testid="kanban-pending-action-12-0"]').exists()
    ).toBe(false);
  });

  it('drops a proposed action without applying it when it is dismissed', async () => {
    const wrapper = await mountModal();
    FormsAPI.getCardContext.mockResolvedValue({
      data: {
        invitations: [],
        submissions: [
          {
            id: 12,
            form_name: 'Pré-consulta',
            status: 'submitted',
            pending_actions: [{ index: 0, kind: 'apply_label' }],
          },
        ],
      },
    });
    FormsAPI.resolvePendingAction.mockResolvedValue({
      data: { pending_actions: [] },
    });

    await wrapper
      .find('[data-testid="kanban-opportunity-tab-forms"]')
      .trigger('click');
    await flushPromises();
    await wrapper
      .find('[data-testid="kanban-pending-dismiss-12-0"]')
      .trigger('click');
    await flushPromises();

    expect(FormsAPI.resolvePendingAction).toHaveBeenCalledWith(
      12,
      0,
      'dismiss'
    );
    // Descartar não mexe no card, por isso não pede releitura.
    expect(wrapper.emitted('updated')).toBeFalsy();
  });

  it('keeps stage and commercial ownership editable without a conversation-agent tab', async () => {
    const wrapper = await mountModal();

    expect(
      wrapper.find('[data-testid="kanban-opportunity-header-stage"]').exists()
    ).toBe(true);
    // O responsável continua editável — agora a partir da linha, não de um
    // campo sempre aberto.
    expect(wrapper.find('[data-testid="kanban-row-owner"]').exists()).toBe(
      true
    );
    await abrirLinhas(wrapper);
    expect(
      wrapper.find('[data-testid="kanban-opportunity-owner"]').exists()
    ).toBe(true);
    expect(
      wrapper
        .find('[data-testid="kanban-opportunity-tab-agent-details"]')
        .exists()
    ).toBe(false);
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
    await openLabels(wrapper);
    const firstLabel = labelButtons(wrapper)[0];

    expect(firstLabel.text()).toContain('hot');
    expect(firstLabel.find('span').element.style.backgroundColor).toBe(
      'rgb(255, 0, 0)'
    );
  });

  it('marks assigned labels as selected', async () => {
    const wrapper = await mountModal();
    await openLabels(wrapper);

    expect(labelButtons(wrapper)[0].attributes('aria-pressed')).toBe('true');
    expect(labelButtons(wrapper)[1].attributes('aria-pressed')).toBe('false');
  });

  it('labels continue saving through updateCardLabels', async () => {
    KanbanBoardsAPI.updateCardLabels.mockResolvedValue({
      data: { payload: labels },
    });
    const wrapper = await mountModal();
    await openLabels(wrapper);

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
    await abrirLinhas(wrapper);

    await subjectInput(wrapper).setValue('Modified subject');
    await descriptionInput(wrapper).setValue('Modified description');
    await openLabels(wrapper);
    await saveLabelsButton(wrapper).trigger('click');
    await flushPromises();
    await wrapper
      .find('[data-testid="kanban-opportunity-tab-details"]')
      .trigger('click');

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

  it('asks before closing when the opportunity has unsaved changes', async () => {
    const wrapper = await mountModal();

    await subjectInput(wrapper).setValue('Modified subject');
    await wrapper
      .find('[data-testid="kanban-opportunity-cancel"]')
      .trigger('click');

    expect(
      wrapper
        .find('[data-testid="kanban-opportunity-unsaved-changes"]')
        .exists()
    ).toBe(true);
    expect(wrapper.emitted('close')).toBeUndefined();

    await wrapper
      .find('[data-testid="kanban-opportunity-keep-editing"]')
      .trigger('click');
    expect(
      wrapper
        .find('[data-testid="kanban-opportunity-unsaved-changes"]')
        .exists()
    ).toBe(false);

    await wrapper
      .find('[data-testid="kanban-opportunity-cancel"]')
      .trigger('click');
    await wrapper
      .find('[data-testid="kanban-opportunity-discard-changes"]')
      .trigger('click');

    expect(wrapper.emitted('close')).toHaveLength(1);
  });
});
it('does not load or display the legacy follow-up cadence in opportunity details', async () => {
  const wrapper = await mountModal();

  expect(KanbanBoardsAPI.getCadences).not.toHaveBeenCalled();
  expect(
    wrapper.find('[data-testid="kanban-opportunity-cadence"]').exists()
  ).toBe(false);
});
