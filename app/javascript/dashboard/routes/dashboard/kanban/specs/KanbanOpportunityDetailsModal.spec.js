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
  uiSettings: {},
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
        'KANBAN.OPPORTUNITY_DETAILS.TIMELINE.CUSTOM_FIELD_CHANGED':
          '{field} changed',
        'KANBAN.OPPORTUNITY_DETAILS.TIMELINE.CHANGE_TRANSITION':
          '{before} → {after}',
        'KANBAN.OPPORTUNITY_DETAILS.FIELD_EMPTY': 'Not filled in',
        'RAEVO_AI.OPPORTUNITY.FIELDS.STATUS': 'Service status',
        'RAEVO_AI.OPPORTUNITY.VALUES.EM_ATENDIMENTO': 'In service',
        'KANBAN.OPPORTUNITY_DETAILS.DESCRIPTION_PLACEHOLDER':
          'Add a single note for this card',
        'KANBAN.OPPORTUNITY_DETAILS.ASSIGNEE': 'Agent',
        'KANBAN.OPPORTUNITY_DETAILS.UNASSIGNED': 'Unassigned',
        'KANBAN.OPPORTUNITY_DETAILS.CONVERSATION': 'Conversation',
        'KANBAN.OPPORTUNITY_DETAILS.CONVERSATION_ID': 'Conversation #{id}',
        'KANBAN.OPPORTUNITY_DETAILS.CONTACT': 'Contact',
        'KANBAN.OPPORTUNITY_DETAILS.NO_CONTACT': 'No contact linked',
        'KANBAN.OPPORTUNITY_DETAILS.DATES': 'Dates',
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
        'KANBAN.OPPORTUNITY_DETAILS.CREATE_LABEL': 'Create and add “{title}”',
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
        'KANBAN.OPPORTUNITY_DETAILS.REQUIRED_IN_STAGE':
          'Required in this stage',
        'KANBAN.OPPORTUNITY_DETAILS.REQUIRED_FIELDS_MISSING':
          'Fill in before saving: {fields}.',
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
        'KANBAN.OPPORTUNITY_DETAILS.COMPLETE_FLOW.QUICK_ANSWERED': 'Answered',
        'KANBAN.OPPORTUNITY_DETAILS.COMPLETE_FLOW.DONE': '{type} completed',
        'KANBAN.OPPORTUNITY_DETAILS.COMPLETE_FLOW.ERROR':
          'Could not complete. What you wrote is still here.',
        'KANBAN.OPPORTUNITY_DETAILS.COMPLETE_FLOW.RETRY': 'Try again',
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
    // A coluna da direita guarda a ORDEM em `ui_settings`, e isso passa pelo
    // `useUISettings`, que lê por `useStoreGetters`. Não ter isto aqui foi o que
    // me fez recuar da persistência na primeira tentativa — era falha do duplo,
    // não razão para não guardar a preferência.
    useStoreGetters: () => ({
      getUISettings: computed(() => storeMocks.uiSettings),
    }),
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
  contactFieldKeys = [],
  attributeDefinitions = [],
  attachTo,
  opportunitySectionOrder = [],
} = {}) => {
  storeMocks.attributeDefinitions = attributeDefinitions;
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
    attachTo,
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
      contactFieldKeys,
      ownerOptions: [
        { value: 7, label: 'Jane Agent' },
        { value: 8, label: 'Ana Paula' },
      ],
      canManageFields: true,
      calendarEnabled,
      opportunitySectionOrder,
    },
    global: {
      stubs: {
        NextInput: nextInputStub,
        NextButton: nextButtonStub,
        KanbanCalendarAppointmentsSection: {
          props: ['contactName'],
          template:
            '<section data-testid="kanban-opportunity-calendar-tab-content" :data-contact-name="contactName" />',
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
const labelSearchInput = wrapper =>
  wrapper.find('[data-testid="kanban-opportunity-label-search"]');
const createLabelButton = wrapper =>
  wrapper.find('[data-testid="kanban-opportunity-create-label"]');
const saveLabelsButton = wrapper =>
  wrapper.find('[data-testid="kanban-opportunity-save-labels"]');
const openLabels = wrapper =>
  wrapper
    .find('[data-testid="kanban-opportunity-toggle-labels"]')
    .trigger('click');
// O Contato saiu da barra de abas e passou a secção da coluna da direita
// (cartão 123jpnbcb57). Nasce aberta, por isso abrir deixou de ser um clique —
// mas o ajudante fica, a garantir que está aberta antes de cada asserção.
const openContactTab = async wrapper => {
  const secao = wrapper.find(
    '[data-testid="kanban-opportunity-section-contact-details"]'
  );
  if (secao.attributes('aria-expanded') === 'false')
    await secao.trigger('click');
};
const selectHeaderStage = (wrapper, stageId) =>
  wrapper
    .findComponent({ name: 'KanbanOpportunityPipelineMenu' })
    .vm.$emit('selectStage', { boardId: 10, stageId });

describe('KanbanOpportunityDetailsModal', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    storeMocks.labels = [];
    storeMocks.currentAccount = { permissions: ['administrator'] };
    storeMocks.uiSettings = {};
  });

  it('uses a single-column layout so opportunity details stay readable', async () => {
    const wrapper = await mountModal();
    const layout = wrapper.find('[data-testid="kanban-opportunity-layout"]');

    expect(
      layout.classes().some(className => className.startsWith('xl:grid-cols-'))
    ).toBe(false);
  });

  // A ordem é do FUNIL, das Configurações — decisão do Pedro na noite de
  // 07/10: «reordenar somente nas configurações». A ficha não reordena.
  describe('section order', () => {
    const secoesNaOrdem = wrapper =>
      wrapper
        .findAll('[data-testid^="kanban-opportunity-section-"]')
        .map(node => node.attributes('data-testid'))
        .map(testid => testid.replace('kanban-opportunity-section-', ''));

    it('starts in the default order: next action, the field sections, then the rest', async () => {
      FinanceAPI.getProviderConnections.mockResolvedValue({ data: [] });
      const wrapper = await mountModal({
        calendarEnabled: true,
        financeModule: { enabled: true },
      });

      expect(secoesNaOrdem(wrapper)).toEqual([
        'next-action',
        'details',
        'contact-details',
        'calendar',
        'finance',
        'forms',
        'timeline',
      ]);
    });

    it('follows the order the funnel saved', async () => {
      const wrapper = await mountModal({
        calendarEnabled: true,
        opportunitySectionOrder: ['timeline', 'contact-details'],
      });

      expect(secoesNaOrdem(wrapper)).toEqual([
        'timeline',
        'contact-details',
        'next-action',
        'details',
        'calendar',
        'forms',
      ]);
    });

    it('does not offer to reorder here', async () => {
      const wrapper = await mountModal({ calendarEnabled: true });

      expect(wrapper.find('[data-testid*="-section-up-"]').exists()).toBe(
        false
      );
      expect(wrapper.find('[data-testid*="-section-down-"]').exists()).toBe(
        false
      );
    });

    it('opens next action and General, and closes a section on click', async () => {
      const wrapper = await mountModal();
      const cabecalho = key =>
        wrapper.find(`[data-testid="kanban-opportunity-section-${key}"]`);

      expect(cabecalho('next-action').attributes('aria-expanded')).toBe('true');
      expect(cabecalho('details').attributes('aria-expanded')).toBe('true');
      expect(cabecalho('contact-details').attributes('aria-expanded')).toBe(
        'false'
      );

      await cabecalho('details').trigger('click');

      expect(cabecalho('details').attributes('aria-expanded')).toBe('false');
      expect(
        wrapper
          .find('[data-testid="kanban-opportunity-commercial-group"]')
          .exists()
      ).toBe(false);
    });
  });

  it('shows finance as a side-column section when the module is active', async () => {
    FinanceAPI.getProviderConnections.mockResolvedValue({ data: [] });
    const wrapper = await mountModal({ financeModule: { enabled: true } });

    expect(
      wrapper
        .find('[data-testid="kanban-opportunity-section-finance"]')
        .exists()
    ).toBe(true);
  });

  it('does not offer charge creation to a financial read-only custom role', async () => {
    storeMocks.currentAccount = { permissions: ['finance_view'] };
    const wrapper = await mountModal({
      financeModule: { enabled: true },
      financeConnections: [{ id: 11, provider: 'asaas', status: 'connected' }],
    });

    await wrapper
      .find('[data-testid="kanban-opportunity-section-finance"]')
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
      .find('[data-testid="kanban-opportunity-section-finance"]')
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
      .find('[data-testid="kanban-opportunity-section-finance"]')
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
        .find('[data-testid="kanban-opportunity-section-contact-details"]')
        .text()
    ).toContain('Contact');
    expect(
      wrapper
        .find('[data-testid="kanban-opportunity-tab-agent-details"]')
        .exists()
    ).toBe(false);

    await openContactTab(wrapper);

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
      data: {
        payload: {
          id: 91,
          name: 'Acme Updated',
          phone_number: '+55 62 98888-0000',
        },
      },
    });
    const wrapper = await mountModal({ calendarEnabled: true });

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

    await wrapper
      .find('[data-testid="kanban-opportunity-section-calendar"]')
      .trigger('click');
    expect(
      wrapper
        .find('[data-testid="kanban-opportunity-calendar-tab-content"]')
        .attributes('data-contact-name')
    ).toBe('Acme Updated');
  });

  it('shows Calendar as a side-column section, closed until it is opened', async () => {
    const wrapper = await mountModal({ calendarEnabled: true });

    expect(
      wrapper
        .find('[data-testid="kanban-opportunity-section-calendar"]')
        .exists()
    ).toBe(true);
    expect(
      wrapper
        .find('[data-testid="kanban-opportunity-calendar-tab-content"]')
        .exists()
    ).toBe(false);

    await wrapper
      .find('[data-testid="kanban-opportunity-section-calendar"]')
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
  });

  it('offers contextual field management to administrators', async () => {
    const wrapper = await mountModal();

    await wrapper
      .find('[data-testid="kanban-opportunity-manage-fields"]')
      .trigger('click');

    expect(wrapper.emitted('manageFields')).toHaveLength(1);
  });

  // Como no painel de contacto do Chatwoot: o Marketing tem perto de trinta
  // campos, quase todos vazios. Fica à vista o que tem valor, o que a etapa
  // exige e o que é importante; o resto fica atrás de «Mostrar mais».
  describe('empty fields', () => {
    const definicoes = [
      {
        key: 'origem',
        label: 'Origem',
        fieldType: 'text',
        layout: { section: 'marketing' },
      },
      {
        key: 'utm_term',
        label: 'utm_term',
        fieldType: 'text',
        layout: { section: 'marketing' },
      },
      {
        key: 'gclid',
        label: 'gclid',
        fieldType: 'text',
        layout: { section: 'marketing' },
      },
      {
        key: 'procedimento',
        label: 'Procedimento',
        fieldType: 'text',
        requiredStageIds: [1],
        layout: { section: 'marketing' },
      },
    ];
    const abrirMarketing = async wrapper => {
      await wrapper
        .find('[data-testid="kanban-opportunity-section-marketing"]')
        .trigger('click');
    };
    const linha = (wrapper, key) =>
      wrapper.find(`[data-testid="kanban-row-${key}"]`);

    it('hides them behind a button that says how many there are', async () => {
      const wrapper = await mountModal({
        card: buildCard({
          kanbanStageId: 1,
          customFieldValues: { origem: 'Meta Ads' },
        }),
        customFieldDefinitions: definicoes,
      });
      await abrirMarketing(wrapper);

      expect(linha(wrapper, 'origem').exists()).toBe(true);
      expect(linha(wrapper, 'utm_term').exists()).toBe(false);
      const botao = wrapper.find(
        '[data-testid="kanban-opportunity-show-more-marketing"]'
      );
      expect(botao.attributes('aria-expanded')).toBe('false');

      await botao.trigger('click');

      expect(linha(wrapper, 'utm_term').exists()).toBe(true);
      expect(linha(wrapper, 'gclid').exists()).toBe(true);
    });

    it('keeps an empty field the current stage requires in sight', async () => {
      const wrapper = await mountModal({
        card: buildCard({ kanbanStageId: 1, customFieldValues: {} }),
        customFieldDefinitions: definicoes,
      });
      await abrirMarketing(wrapper);

      expect(linha(wrapper, 'procedimento').exists()).toBe(true);
      expect(linha(wrapper, 'gclid').exists()).toBe(false);
    });
  });

  it('lists the sections the clinic created, in the same list', async () => {
    const wrapper = await mountModal({
      customFieldDefinitions: [
        {
          key: 'dente',
          label: 'Dente',
          fieldType: 'text',
          layout: { section: 'consulta' },
        },
        {
          key: 'origem',
          label: 'Origem',
          fieldType: 'text',
          layout: { section: 'marketing' },
        },
      ],
      customFieldSections: [{ key: 'consulta', label: 'Consulta' }],
    });

    expect(
      wrapper.find('[data-testid="kanban-opportunity-section-consulta"]').text()
    ).toBe('Consulta');
    expect(
      wrapper
        .find('[data-testid="kanban-opportunity-section-marketing"]')
        .text()
    ).toBe('Marketing');
    expect(
      wrapper.find('[data-testid="kanban-opportunity-add-tab"]').exists()
    ).toBe(false);
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
      .find('[data-testid="kanban-opportunity-section-ai"]')
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
      wrapper.findAll('[data-testid="kanban-opportunity-section-details"]')
    ).toHaveLength(1);
    expect(
      wrapper.findAll('[data-testid="kanban-opportunity-section-marketing"]')
    ).toHaveLength(1);
    expect(wrapper.text()).not.toContain('Detail');
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

  it('shows the immutable commercial timeline in its own side-column section', async () => {
    const wrapper = await mountModal();

    await wrapper
      .find('[data-testid="kanban-opportunity-section-timeline"]')
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
      .find('[data-testid="kanban-opportunity-section-timeline"]')
      .trigger('click');

    expect(
      wrapper.find('[data-testid="kanban-opportunity-timeline"]').text()
    ).toContain('Entered Proposta enviada');
  });

  it('shows the localized field and before/after values for custom-field changes', async () => {
    const wrapper = await mountModal({
      customFieldDefinitions: [
        {
          key: 'raevo_ai_status',
          label: 'Persisted label',
          fieldType: 'select',
          options: ['em_atendimento'],
        },
      ],
      timeline: [
        {
          id: 11,
          event_type: 'custom_fields_changed',
          occurred_at: '2026-07-21T12:00:00Z',
          actor: null,
          changes: {
            custom_field_values: [{}, { raevo_ai_status: 'em_atendimento' }],
          },
        },
      ],
    });

    await wrapper
      .find('[data-testid="kanban-opportunity-section-timeline"]')
      .trigger('click');

    const timeline = wrapper.get('[data-testid="kanban-opportunity-timeline"]');
    expect(timeline.text()).toContain('Service status changed');
    expect(timeline.text()).toContain('Not filled in → In service');
    expect(timeline.text()).not.toContain('Custom fields changed');
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
    ).toEqual(expect.arrayContaining(['flex', 'flex-col', 'min-h-full']));
    expect(
      wrapper.find('[data-testid="kanban-opportunity-layout"]').classes()
    ).not.toContain('xl:grid-cols-[minmax(0,1fr)_18rem]');
  });

  // Duas dívidas registadas ao aprovar a tela 2, a 20/09. Ambas silenciosas: o
  // assunto cortado parece só apertado, e a tira de abas a crescer só se nota
  // quando há módulos suficientes ligados.
  it('never truncates the opportunity subject in the header', async () => {
    const wrapper = await mountModal();
    const titulo = wrapper.find('h2');

    expect(titulo.classes()).toContain('break-words');
    expect(titulo.classes()).not.toContain('truncate');
  });

  // A tira rolava, e rolar sem aviso era o defeito: medido na gaveta do
  // Pipeline, 571px de abas em 197px úteis — 374px invisíveis, sem seta nem
  // contagem. Agora o que não cabe desce para «+N mais». O que esta asserção
  // trava é o que continua proibido nos dois casos: crescer em altura.

  // O bloco «Últimos eventos» gastava 104px do painel para mostrar UM evento e um
  // link «Ver histórico completo» — para o separador Histórico, que está na
  // mesma tira, a dois centímetros dali. O histórico inteiro continua lá.
  it('does not repeat the timeline inside the general tab', async () => {
    const wrapper = await mountModal();

    expect(
      wrapper
        .find('[data-testid="kanban-opportunity-recent-activity"]')
        .exists()
    ).toBe(false);
    expect(
      wrapper
        .find('[data-testid="kanban-opportunity-section-timeline"]')
        .exists()
    ).toBe(true);
  });

  // O `+` de criar secção morava no MEIO da tira, entre as abas e o Histórico
  // preso à direita — lia-se como se pertencesse ao Histórico. Sem transbordo
  // fica no fim da tira; com transbordo desce para o fim do menu.

  it('keeps drawer content in one column so the commercial context cannot overlap fields', async () => {
    const wrapper = await mountModal();
    await wrapper.setProps({ drawerMode: true });

    // Verificava só o literal `_18rem`. A coluna lateral voltou a 07/10 como
    // `_20rem`, este teste ficou verde, e a ficha passou a ter 200px no
    // Pipeline e 0px na conversa. Qualquer segunda coluna na gaveta reprova.
    expect(
      wrapper
        .find('[data-testid="kanban-opportunity-layout"]')
        .classes()
        .filter(classe => classe.includes('grid-cols'))
    ).toEqual([]);
  });

  describe('contact fields', () => {
    const atributos = [
      {
        attribute_key: 'data_nascimento',
        attribute_display_name: 'Data de nascimento',
        attribute_model: 'contact_attribute',
        attribute_display_type: 'date',
      },
      {
        attribute_key: 'waha_whatsapp_jid',
        attribute_display_name: 'WAHA JID',
        attribute_model: 'contact_attribute',
        attribute_display_type: 'text',
      },
    ];

    const irParaContato = async wrapper => {
      await openContactTab(wrapper);
    };

    it('no longer asks the user to add a field before filling it', async () => {
      const wrapper = await mountModal({ attributeDefinitions: atributos });
      await irParaContato(wrapper);

      expect(
        wrapper
          .find('[data-testid="kanban-opportunity-add-attribute"]')
          .exists()
      ).toBe(false);
    });

    // Sem esta camada a aba mostrava qualquer atributo da conta — inclusive os
    // técnicos do WAHA, lidos como se fossem dados de negócio.
    it('shows only the contact fields the board places, in that order', async () => {
      const wrapper = await mountModal({
        attributeDefinitions: atributos,
        contactFieldKeys: ['data_nascimento'],
      });
      await irParaContato(wrapper);

      expect(
        wrapper.find('[data-testid="kanban-row-attr-data_nascimento"]').exists()
      ).toBe(true);
      expect(
        wrapper
          .find('[data-testid="kanban-row-attr-waha_whatsapp_jid"]')
          .exists()
      ).toBe(false);
    });

    // O teste acima cobre o funil que ESCOLHE campos. Em produção o funil da
    // conta 1 não escolhia nenhum, e aí a aba caía em «mostra tudo» — foi assim
    // que o Chat ID voltou a aparecer depois de eu ter dado o cartão por
    // fechado, com a ficha do contato já limpa.
    it('hides the WhatsApp addressing even when the board places nothing', async () => {
      const wrapper = await mountModal({
        attributeDefinitions: [
          ...atributos,
          {
            attribute_key: 'waha_whatsapp_chat_id',
            attribute_display_name: 'WhatsApp Chat ID',
            attribute_model: 'contact_attribute',
            attribute_display_type: 'text',
          },
        ],
        contactFieldKeys: [],
      });
      await irParaContato(wrapper);

      expect(wrapper.text()).not.toContain('WhatsApp Chat ID');
      expect(wrapper.text()).not.toContain('WAHA JID');
    });

    it.each([[[]], [['waha_whatsapp_jid', 'data_nascimento']]])(
      'hides saved addressing values including orphaned definitions with placement %j',
      async contactFieldKeys => {
        const wrapper = await mountModal({
          card: buildCard({
            contact: {
              id: 55,
              name: 'Pedro',
              custom_attributes: {
                waha_whatsapp_jid: 'internal-jid',
                waha_whatsapp_lid: 'internal-lid',
                waha_whatsapp_chat_id: 'internal-chat',
                data_nascimento: '1990-01-01',
              },
              additional_attributes: { waha_whatsapp_extra: 'internal-extra' },
            },
          }),
          attributeDefinitions: atributos,
          contactFieldKeys,
        });
        await irParaContato(wrapper);

        ['jid', 'lid', 'chat_id', 'extra'].forEach(key => {
          expect(
            wrapper
              .find(`[data-testid="kanban-row-attr-waha_whatsapp_${key}"]`)
              .exists()
          ).toBe(false);
        });
        expect(
          wrapper
            .find('[data-testid="kanban-row-attr-data_nascimento"]')
            .exists()
        ).toBe(true);
      }
    );

    it('draws a placed but empty field as a dash instead of hiding it', async () => {
      const wrapper = await mountModal({
        attributeDefinitions: atributos,
        contactFieldKeys: ['data_nascimento'],
      });
      await irParaContato(wrapper);

      const linha = wrapper.find(
        '[data-testid="kanban-row-attr-data_nascimento"]'
      );
      expect(linha.exists()).toBe(true);
      // O traço é desenhado pelo RaevoFieldRow; aqui o i18n devolve a chave.
      expect(linha.text()).toContain('RAEVO.FIELD_ROW.EMPTY');
    });

    // Board ainda não configurado não pode esvaziar de um dia para o outro.
    it('falls back to whatever has a value while the board has no placement', async () => {
      const wrapper = await mountModal({
        attributeDefinitions: atributos,
        contactFieldKeys: [],
      });
      await irParaContato(wrapper);

      expect(
        wrapper
          .find('[data-testid="kanban-opportunity-add-attribute"]')
          .exists()
      ).toBe(false);
    });
  });

  it('renders title, compact description, and amount controls', async () => {
    const wrapper = await mountModal();
    await abrirLinhas(wrapper);

    expect(wrapper.find('h2').text()).toContain('Enterprise expansion');
    await wrapper
      .find('[data-testid="kanban-opportunity-edit-subject"]')
      .trigger('click');
    expect(subjectInput(wrapper).classes()).toContain('w-full');
    // Em ficha densa o campo não desenha casca: mesma tipografia da linha,
    // sem fundo nem contorno. A pílula/`rounded-lg` do design system vale para
    // formulário, não aqui. Ver docs/raevo-design-system.md §3.
    expect(descriptionInput(wrapper).classes()).toEqual(
      expect.arrayContaining([
        'w-full',
        'min-h-20',
        'bg-transparent',
        'border-0',
        'text-sm',
      ])
    );
    expect(descriptionInput(wrapper).classes()).not.toContain('rounded-lg');
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

  // Nenhuma das duas era lida por regra nenhuma. A consulta vive na Agenda, que
  // espelha a data no campo do card sozinha — digitar à mão só desincronizava.
  it('no longer offers internal planning dates', async () => {
    const wrapper = await mountModal();

    expect(
      wrapper.find('[data-testid="kanban-opportunity-due-at"]').exists()
    ).toBe(false);
    expect(
      wrapper.find('[data-testid="kanban-opportunity-starts-at"]').exists()
    ).toBe(false);
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
      wrapper.find('[data-testid="kanban-opportunity-section-details"]').text()
    ).toContain('General');
    expect(
      wrapper
        .find('[data-testid="kanban-opportunity-section-marketing"]')
        .text()
    ).toContain('Marketing');
    expect((await customFieldInput(wrapper, 'qualificacao')).exists()).toBe(
      true
    );
    // O Marketing nasce fechado: o campo só existe depois de se abrir a secção.
    expect((await customFieldInput(wrapper, 'gclid')).exists()).toBe(false);

    await wrapper
      .find('[data-testid="kanban-opportunity-section-marketing"]')
      .trigger('click');

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
      .find('[data-testid="kanban-opportunity-section-consulta"]')
      .trigger('click');

    const group = wrapper.find(
      '[data-testid="kanban-opportunity-custom-fields-consulta"] section'
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
      .find('[data-testid="kanban-opportunity-section-financeiro"]')
      .trigger('click');

    const customFields = wrapper.find(
      '[data-testid="kanban-opportunity-custom-fields-financeiro"]'
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

  // RAEVO 5h: concluir pergunta «Como foi?» antes de gravar, e abre logo a
  // próxima ação. O clique no botão já não grava sozinho.
  const concluirAcao = async (wrapper, resultado = '') => {
    await wrapper
      .find('[data-testid="kanban-opportunity-complete-next-action"]')
      .trigger('click');
    if (resultado) {
      await wrapper
        .find('[data-testid="kanban-completion-result"]')
        .setValue(resultado);
    }
    await wrapper
      .find('[data-testid="kanban-completion-confirm"]')
      .trigger('click');
    await flushPromises();
  };

  it('marks the current next action as completed', async () => {
    KanbanBoardsAPI.updateCardDetailsById.mockResolvedValue({
      data: buildCard({ nextActionCompletedAt: '2026-07-21T16:00:00.000Z' }),
    });
    const wrapper = await mountModal();

    await concluirAcao(wrapper);

    expect(KanbanBoardsAPI.updateCardDetailsById).toHaveBeenCalledWith(
      10,
      501,
      expect.objectContaining({
        next_action_completed_at: expect.any(String),
        complete_next_action: true,
      })
    );
  });

  // Registar a ação não é editar a oportunidade: um campo que a etapa exige e
  // ainda está vazio não pode impedir ninguém de registar a chamada que fez.
  // Em produção era assim que «Concluir» não gravava nada (09/10).
  const exigeProcedimento = [
    {
      key: 'procedimento',
      label: 'Procedimento',
      fieldType: 'text',
      requiredStageIds: [1],
    },
  ];

  it('completes the action even when the stage still requires an empty field, sending only the action', async () => {
    KanbanBoardsAPI.updateCardDetailsById.mockResolvedValue({
      data: buildCard({
        kanbanStageId: 1,
        nextActionCompletedAt: '2026-07-21T16:00:00.000Z',
      }),
    });
    const wrapper = await mountModal({
      card: buildCard({ kanbanStageId: 1, customFieldValues: {} }),
      customFieldDefinitions: exigeProcedimento,
    });

    await concluirAcao(wrapper);

    const enviado =
      KanbanBoardsAPI.updateCardDetailsById.mock.calls.at(-1)?.[2];
    expect(Object.keys(enviado || {}).sort()).toEqual([
      'complete_next_action',
      'next_action_completed_at',
    ]);
    expect(
      wrapper
        .find('[data-testid="kanban-next-action-completion"]')
        .attributes('data-step')
    ).toBe('next');
  });

  it('schedules the next action without the fields the stage requires', async () => {
    KanbanBoardsAPI.updateCardDetailsById.mockResolvedValue({
      data: buildCard({ kanbanStageId: 1, nextActionType: 'Ligar' }),
    });
    const wrapper = await mountModal({
      card: buildCard({ kanbanStageId: 1, customFieldValues: {} }),
      customFieldDefinitions: exigeProcedimento,
    });
    await concluirAcao(wrapper);
    const fluxo = wrapper.find('[data-testid="kanban-next-action-completion"]');
    const tipo = fluxo.find('[data-testid="kanban-completion-next-type"]');
    await tipo.setValue(
      tipo
        .findAll('option')
        .map(option => option.element.value)
        .find(Boolean)
    );
    await fluxo
      .find('[data-testid="kanban-completion-next-at"]')
      .setValue('2026-10-10T09:00');
    await fluxo
      .find('[data-testid="kanban-completion-save-next"]')
      .trigger('click');
    await flushPromises();

    expect(
      Object.keys(
        KanbanBoardsAPI.updateCardDetailsById.mock.calls.at(-1)[2]
      ).sort()
    ).toEqual(['next_action_at', 'next_action_note', 'next_action_type']);
  });

  it('asks how the action went before completing it', async () => {
    const wrapper = await mountModal();

    await wrapper
      .find('[data-testid="kanban-opportunity-complete-next-action"]')
      .trigger('click');
    await flushPromises();

    const fluxo = wrapper.find('[data-testid="kanban-next-action-completion"]');
    expect(fluxo.attributes('data-step')).toBe('result');
    expect(
      fluxo.find('[data-testid="kanban-completion-action"]').text()
    ).toContain('Enviar proposta');
    expect(KanbanBoardsAPI.updateCardDetailsById).not.toHaveBeenCalled();
    expect(
      wrapper.find('[data-testid="kanban-row-next-action-at"]').exists()
    ).toBe(false);
  });

  it('sends the result written with the quick answer to the history', async () => {
    KanbanBoardsAPI.updateCardDetailsById.mockResolvedValue({
      data: buildCard({ nextActionCompletedAt: '2026-07-21T16:00:00.000Z' }),
    });
    const wrapper = await mountModal();

    await wrapper
      .find('[data-testid="kanban-opportunity-complete-next-action"]')
      .trigger('click');
    const atendeu = wrapper.find(
      '[data-testid="kanban-completion-quick-answered"]'
    );
    await atendeu.trigger('click');
    expect(atendeu.attributes('aria-pressed')).toBe('true');
    const resultado = wrapper.find('[data-testid="kanban-completion-result"]');
    await resultado.setValue(
      `${resultado.element.value}Quer avaliar na sexta.`
    );
    await wrapper
      .find('[data-testid="kanban-completion-confirm"]')
      .trigger('click');
    await flushPromises();

    expect(
      KanbanBoardsAPI.updateCardDetailsById.mock.calls.at(-1)[2]
    ).toMatchObject({
      complete_next_action: true,
      next_action_completion_note: 'Answered. Quer avaliar na sexta.',
    });
  });

  it('opens the next action right after completing and saves it', async () => {
    KanbanBoardsAPI.updateCardDetailsById.mockResolvedValueOnce({
      data: buildCard({
        nextActionCompletedAt: '2026-07-21T16:00:00.000Z',
        nextActionType: null,
        nextActionAt: null,
        nextActionNote: null,
      }),
    });
    KanbanBoardsAPI.updateCardDetailsById.mockResolvedValueOnce({
      data: buildCard({
        nextActionType: 'Ligar',
        nextActionAt: '2026-10-10T12:00:00.000Z',
        nextActionNote: 'Confirmar presença na véspera.',
      }),
    });
    const wrapper = await mountModal();

    await concluirAcao(wrapper);

    const fluxo = wrapper.find('[data-testid="kanban-next-action-completion"]');
    expect(fluxo.attributes('data-step')).toBe('next');
    expect(fluxo.find('[data-testid="kanban-completion-done"]').text()).toBe(
      'Enviar proposta completed'
    );

    const tipo = fluxo.find('[data-testid="kanban-completion-next-type"]');
    const primeiroTipo = tipo
      .findAll('option')
      .map(option => option.element.value)
      .find(Boolean);
    await tipo.setValue(primeiroTipo);
    await fluxo
      .find('[data-testid="kanban-completion-next-at"]')
      .setValue('2026-10-10T09:00');
    await fluxo
      .find('[data-testid="kanban-completion-next-note"]')
      .setValue('Confirmar presença na véspera.');
    await fluxo
      .find('[data-testid="kanban-completion-save-next"]')
      .trigger('click');
    await flushPromises();

    expect(KanbanBoardsAPI.updateCardDetailsById).toHaveBeenCalledTimes(2);
    expect(
      KanbanBoardsAPI.updateCardDetailsById.mock.calls.at(-1)[2]
    ).toMatchObject({
      next_action_type: primeiroTipo,
      next_action_at: expect.any(String),
      next_action_note: 'Confirmar presença na véspera.',
    });
    expect(
      KanbanBoardsAPI.updateCardDetailsById.mock.calls.at(-1)[2]
    ).not.toHaveProperty('complete_next_action');
    expect(
      wrapper.find('[data-testid="kanban-next-action-completion"]').exists()
    ).toBe(false);
  });

  it('closes without saving again when there is no next action', async () => {
    KanbanBoardsAPI.updateCardDetailsById.mockResolvedValue({
      data: buildCard({
        nextActionCompletedAt: '2026-07-21T16:00:00.000Z',
        nextActionType: null,
        nextActionAt: null,
        nextActionNote: null,
      }),
    });
    const wrapper = await mountModal();

    await concluirAcao(wrapper);
    await wrapper
      .find('[data-testid="kanban-completion-skip"]')
      .trigger('click');
    await flushPromises();

    expect(KanbanBoardsAPI.updateCardDetailsById).toHaveBeenCalledTimes(1);
    expect(
      wrapper.find('[data-testid="kanban-next-action-completion"]').exists()
    ).toBe(false);
    expect(
      wrapper
        .find('[data-testid="kanban-opportunity-next-action-empty"]')
        .exists()
    ).toBe(true);
  });

  it('says there is no action set and opens the form to set one', async () => {
    KanbanBoardsAPI.updateCardDetailsById.mockResolvedValue({
      data: buildCard({
        nextActionType: 'Ligar',
        nextActionAt: '2026-10-10T12:00:00.000Z',
      }),
    });
    const wrapper = await mountModal({
      card: buildCard({
        nextActionType: null,
        nextActionAt: null,
        nextActionNote: null,
      }),
    });

    expect(
      wrapper
        .find('[data-testid="kanban-opportunity-next-action-empty"]')
        .exists()
    ).toBe(true);
    expect(
      wrapper.find('[data-testid="kanban-row-next-action-at"]').exists()
    ).toBe(false);

    await wrapper
      .find('[data-testid="kanban-opportunity-schedule-next-action"]')
      .trigger('click');
    const fluxo = wrapper.find('[data-testid="kanban-next-action-completion"]');
    expect(fluxo.attributes('data-step')).toBe('schedule');
    expect(fluxo.find('[data-testid="kanban-completion-done"]').exists()).toBe(
      false
    );
    expect(fluxo.find('[data-testid="kanban-completion-skip"]').exists()).toBe(
      false
    );

    await fluxo
      .find('[data-testid="kanban-completion-next-at"]')
      .setValue('2026-10-10T09:00');
    await fluxo
      .find('[data-testid="kanban-completion-save-next"]')
      .trigger('click');
    await flushPromises();

    const payload = KanbanBoardsAPI.updateCardDetailsById.mock.calls.at(-1)[2];
    expect(payload).toMatchObject({ next_action_at: expect.any(String) });
    expect(payload).not.toHaveProperty('complete_next_action');
    expect(
      wrapper.find('[data-testid="kanban-row-next-action-at"]').exists()
    ).toBe(true);
  });

  it('does not read the empty type option as the action type', async () => {
    const wrapper = await mountModal({
      card: buildCard({ nextActionType: null }),
    });

    expect(
      wrapper.find('[data-testid="kanban-row-next-action-type"]').text()
    ).not.toContain('Select action');
  });

  it('keeps the written result and explains when completing fails', async () => {
    KanbanBoardsAPI.updateCardDetailsById.mockRejectedValue(
      new Error('Network Error')
    );
    const wrapper = await mountModal();

    await concluirAcao(wrapper, 'Não atendeu. Caixa de mensagens.');

    const fluxo = wrapper.find('[data-testid="kanban-next-action-completion"]');
    expect(fluxo.attributes('data-step')).toBe('result');
    expect(
      fluxo.find('[data-testid="kanban-completion-result"]').element.value
    ).toBe('Não atendeu. Caixa de mensagens.');
    expect(fluxo.find('[role="alert"]').text()).toBe(
      'Could not complete. What you wrote is still here.'
    );
    // O motivo concreto continua no rodapé da ficha.
    expect(wrapper.text()).toContain('Network Error');
    expect(fluxo.find('[data-testid="kanban-completion-confirm"]').text()).toBe(
      'Try again'
    );
  });

  // 5j: a lista das ações concluídas mora no Histórico, com o resultado e quem
  // fez; a linha do tempo por baixo deixa de repetir a conclusão como evento.
  it('lists completed actions in the history section, once', async () => {
    const wrapper = await mountModal({
      card: buildCard({
        nextActionHistory: [
          {
            type: 'Ligar',
            note: 'Confirmar avaliação',
            scheduled_at: '2026-10-08T13:00:00.000Z',
            completed_at: '2026-10-08T13:12:00.000Z',
            completion_note: 'Atendeu. Quer avaliar na sexta.',
            completed_by: { id: 7, name: 'Alysson' },
          },
        ],
      }),
      timeline: [
        {
          id: 20,
          event_type: 'next_action_completed',
          occurred_at: '2026-10-08T13:12:00Z',
          actor: { name: 'Alysson' },
        },
        {
          id: 21,
          event_type: 'stage_changed',
          occurred_at: '2026-10-08T12:00:00Z',
          actor: { name: 'Jane Agent' },
          metadata: { to_stage: { name: 'Proposta enviada' } },
        },
      ],
    });

    expect(
      wrapper
        .find('[data-testid="kanban-opportunity-next-action-section"]')
        .text()
    ).not.toContain('Atendeu. Quer avaliar na sexta.');

    await wrapper
      .find('[data-testid="kanban-opportunity-section-timeline"]')
      .trigger('click');

    const historico = wrapper.get('[data-testid="kanban-action-history"]');
    expect(
      historico.findAll('[data-testid="kanban-action-history-item"]')
    ).toHaveLength(1);
    expect(
      historico.get('[data-testid="kanban-action-history-result"]').text()
    ).toBe('Atendeu. Quer avaliar na sexta.');
    expect(
      historico.get('[data-testid="kanban-action-history-who"]').text()
    ).toBe('Alysson');

    const linhaDoTempo = wrapper.get(
      '[data-testid="kanban-opportunity-timeline"]'
    );
    expect(linhaDoTempo.text()).toContain('Entered Proposta enviada');
    expect(linhaDoTempo.text()).not.toContain('Next action completed');
  });

  it('preserves the stored seconds when saving an unchanged next action date', async () => {
    const scheduledAt = '2026-07-22T11:30:47.123Z';
    const wrapper = await mountModal({
      card: buildCard({ nextActionAt: scheduledAt }),
    });

    await wrapper.find('form').trigger('submit');
    await flushPromises();

    expect(
      KanbanBoardsAPI.updateCardDetailsById.mock.calls.at(-1)[2]
    ).not.toHaveProperty('next_action_at');
  });

  // Quem conclui vai marcar a ação seguinte a seguir. Os campos ficavam com o
  // que acabou de ser feito, e era preciso apagar três antes de escrever — ou
  // gravava-se sem reparar e a «próxima ação» era a anterior outra vez. O
  // servidor passou a devolvê-los vazios; a tela segue o servidor.
  it('comes back with the next action fields empty after completing one', async () => {
    KanbanBoardsAPI.updateCardDetailsById.mockResolvedValue({
      data: buildCard({
        nextActionCompletedAt: '2026-07-21T16:00:00.000Z',
        nextActionType: null,
        nextActionAt: null,
        nextActionNote: null,
      }),
    });
    const wrapper = await mountModal();

    await concluirAcao(wrapper);

    expect(wrapper.vm.nextActionType).toBe('');
    expect(wrapper.vm.nextActionAt).toBe('');
    expect(wrapper.vm.nextActionNote).toBe('');
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

    await wrapper
      .find('[data-testid="kanban-opportunity-section-timeline"]')
      .trigger('click');

    // Sem resultado escrito, a ação mostra o que estava previsto fazer.
    const history = wrapper.find('[data-testid="kanban-action-history"]');
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

  // Mudar de etapa na ficha devolvia o erro cru do modelo, «procedimento is
  // required»: em inglês, com a chave, e sem dizer onde estava o campo.
  describe('fields the chosen stage requires', () => {
    const definicoes = [
      {
        key: 'procedimento',
        label: 'Procedimento',
        fieldType: 'text',
        requiredStageIds: [2],
      },
    ];

    it('says which field the stage requires as soon as the stage changes', async () => {
      const wrapper = await mountModal({
        card: buildCard({ kanbanStageId: 1, customFieldValues: {} }),
        customFieldDefinitions: definicoes,
      });
      expect(wrapper.text()).not.toContain('Required in this stage');

      await selectHeaderStage(wrapper, 2);

      expect(
        wrapper.find('[data-testid="kanban-row-procedimento"]').exists()
      ).toBe(true);
      expect(wrapper.text()).toContain('Required in this stage');
    });

    it('does not send the move while the field is empty, and names it', async () => {
      const wrapper = await mountModal({
        card: buildCard({ kanbanStageId: 1, customFieldValues: {} }),
        customFieldDefinitions: definicoes,
      });

      await selectHeaderStage(wrapper, 2);
      await wrapper.find('form').trigger('submit');
      await flushPromises();

      expect(KanbanBoardsAPI.updateCardDetailsById).not.toHaveBeenCalled();
      expect(
        wrapper.find('[data-testid="kanban-opportunity-save-error"]').text()
      ).toBe('Fill in before saving: Procedimento.');
    });
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
    await openContactTab(wrapper);

    expect(
      (await contactInput(wrapper, 'name', 'kanban-opportunity-contact-name'))
        .element.value
    ).toBe('Acme Buyer');
  });

  it('opens the invitation creator from the forms tab for administrators', async () => {
    const wrapper = await mountModal();

    await wrapper
      .find('[data-testid="kanban-opportunity-section-forms"]')
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
      .find('[data-testid="kanban-opportunity-section-forms"]')
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
      .find('[data-testid="kanban-opportunity-section-forms"]')
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
      .find('[data-testid="kanban-opportunity-section-forms"]')
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
      .find('[data-testid="kanban-opportunity-section-forms"]')
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
      .find('[data-testid="kanban-opportunity-section-forms"]')
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

  it('closes on an outside click without leaving unsaved labels selected', async () => {
    const host = document.createElement('div');
    document.body.append(host);
    const wrapper = await mountModal({ attachTo: host });
    try {
      await openLabels(wrapper);
      await labelButtons(wrapper)[1].trigger('click');
      expect(wrapper.find('#kanban-opportunity-labels-popover').exists()).toBe(
        true
      );
      // VueUse releases its click-processing guard on the next event-loop turn.
      await new Promise(resolve => {
        setTimeout(resolve, 0);
      });
      document.body.dispatchEvent(
        new MouseEvent('pointerdown', { bubbles: true })
      );
      document.body.dispatchEvent(
        new MouseEvent('click', { bubbles: true, detail: 1 })
      );
      await flushPromises();
      expect(wrapper.find('#kanban-opportunity-labels-popover').exists()).toBe(
        false
      );
      await openLabels(wrapper);
      expect(labelButtons(wrapper)[1].attributes('aria-pressed')).toBe('false');
      expect(KanbanBoardsAPI.updateCardLabels).not.toHaveBeenCalled();
    } finally {
      wrapper.unmount();
      host.remove();
    }
  });
  it('closes it on Escape as well', async () => {
    const wrapper = await mountModal();
    await openLabels(wrapper);

    await wrapper
      .find('#kanban-opportunity-labels-popover')
      .trigger('keydown.esc');

    expect(wrapper.find('#kanban-opportunity-labels-popover').exists()).toBe(
      false
    );
  });

  it('Escape dismisses labels without opening the opportunity discard dialog', async () => {
    const wrapper = await mountModal();
    await subjectInput(wrapper).setValue('Modified subject');
    await openLabels(wrapper);
    await wrapper
      .find('#kanban-opportunity-labels-popover')
      .trigger('keydown', { key: 'Escape' });

    expect(
      wrapper
        .find('[data-testid="kanban-opportunity-unsaved-changes"]')
        .exists()
    ).toBe(false);
    expect(subjectInput(wrapper).element.value).toBe('Modified subject');
    expect(wrapper.emitted('close')).toBeUndefined();
  });

  it('keeps saved labels when the popover is dismissed and reopened', async () => {
    KanbanBoardsAPI.updateCardLabels.mockResolvedValue({
      data: { payload: labels },
    });
    const wrapper = await mountModal();
    await openLabels(wrapper);
    await labelButtons(wrapper)[1].trigger('click');
    await saveLabelsButton(wrapper).trigger('click');
    await flushPromises();
    await openLabels(wrapper);
    await openLabels(wrapper);

    expect(labelButtons(wrapper)[1].attributes('aria-pressed')).toBe('true');
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

  it('filters labels by the typed text', async () => {
    const wrapper = await mountModal();
    await openLabels(wrapper);

    await labelSearchInput(wrapper).setValue('ENTER');

    expect(labelButtons(wrapper).map(button => button.text())).toEqual([
      'enterprise',
    ]);
    expect(createLabelButton(wrapper).exists()).toBe(true);

    await labelSearchInput(wrapper).setValue('Hot');
    expect(createLabelButton(wrapper).exists()).toBe(false);
  });

  it('creates a missing label from the card and applies it', async () => {
    KanbanBoardsAPI.updateCardLabels.mockResolvedValue({
      data: { payload: ['hot', 'paciente-vip'] },
    });
    const wrapper = await mountModal();
    await openLabels(wrapper);

    await labelSearchInput(wrapper).setValue('  Paciente VIP ');
    expect(createLabelButton(wrapper).text()).toContain('paciente-vip');

    await createLabelButton(wrapper).trigger('click');
    await flushPromises();

    expect(storeMocks.dispatch).toHaveBeenCalledWith(
      'labels/create',
      expect.objectContaining({ title: 'paciente-vip', show_on_sidebar: false })
    );
    expect(KanbanBoardsAPI.updateCardLabels).toHaveBeenCalledWith(10, 501, [
      'hot',
      'paciente-vip',
    ]);
    expect(labelSearchInput(wrapper).element.value).toBe('');
  });

  it('keeps the typed label when creating it fails', async () => {
    const wrapper = await mountModal();
    storeMocks.dispatch.mockImplementation(action =>
      action === 'labels/create'
        ? Promise.reject(new Error('Title has already been taken'))
        : Promise.resolve()
    );
    await openLabels(wrapper);

    await labelSearchInput(wrapper).setValue('vip');
    await createLabelButton(wrapper).trigger('click');
    await flushPromises();

    expect(KanbanBoardsAPI.updateCardLabels).not.toHaveBeenCalled();
    expect(labelSearchInput(wrapper).element.value).toBe('vip');
    expect(wrapper.text()).toContain('Title has already been taken');
  });

  it('explains label naming instead of offering an invalid label', async () => {
    const wrapper = await mountModal();
    await openLabels(wrapper);

    await labelSearchInput(wrapper).setValue('vip!');

    expect(createLabelButton(wrapper).exists()).toBe(false);
    expect(
      wrapper.find('[data-testid="kanban-opportunity-label-invalid"]').exists()
    ).toBe(true);
  });

  it('does not offer label creation to agents', async () => {
    storeMocks.currentAccount = { permissions: ['agent'] };
    const wrapper = await mountModal();
    await openLabels(wrapper);

    await labelSearchInput(wrapper).setValue('vip');

    expect(createLabelButton(wrapper).exists()).toBe(false);
    expect(
      wrapper
        .find('[data-testid="kanban-opportunity-label-admin-only"]')
        .exists()
    ).toBe(true);
  });

  it('labels save preserves scalar form state', async () => {
    const wrapper = await mountModal();
    await abrirLinhas(wrapper);

    await subjectInput(wrapper).setValue('Modified subject');
    await descriptionInput(wrapper).setValue('Modified description');
    await openLabels(wrapper);
    await saveLabelsButton(wrapper).trigger('click');
    await flushPromises();

    expect(subjectInput(wrapper).element.value).toBe('Modified subject');
    expect(descriptionInput(wrapper).element.value).toBe(
      'Modified description'
    );
  });

  it('does not render an add-note action', async () => {
    const wrapper = await mountModal();

    expect(
      wrapper.find('[data-testid="kanban-opportunity-add-note"]').exists()
    ).toBe(false);
    expect(wrapper.text()).not.toContain('Add note');
  });

  it('hides the save bar again when an empty custom field is typed and cleared', async () => {
    const wrapper = await mountModal({
      card: buildCard({ customFieldValues: { consulta_realizada: 'Sim' } }),
    });
    const footer = () =>
      wrapper.find('[data-testid="kanban-opportunity-save-bar"]');
    // Vazio, o campo está atrás de «Mostrar mais».
    await wrapper
      .find('[data-testid="kanban-opportunity-show-more-details"]')
      .trigger('click');
    const campo = await customFieldInput(wrapper, 'observacao_venda');

    await campo.setValue('Pagou sinal');
    expect(footer().exists()).toBe(true);

    await campo.setValue('');
    expect(footer().exists()).toBe(false);
  });

  it('emits close from the close action when nothing changed', async () => {
    const wrapper = await mountModal();

    await wrapper
      .find('[data-testid="kanban-opportunity-close"]')
      .trigger('click');

    expect(wrapper.emitted('close')).toHaveLength(1);
  });

  it('only offers cancel and save while there are unsaved changes', async () => {
    const updatedCard = buildCard({ subject: 'Modified subject' });
    KanbanBoardsAPI.updateCardDetailsById.mockResolvedValue({
      data: updatedCard,
    });
    const wrapper = await mountModal();
    const footer = () =>
      wrapper.find('[data-testid="kanban-opportunity-save-bar"]');

    expect(footer().exists()).toBe(false);

    const original = subjectInput(wrapper).element.value;
    await subjectInput(wrapper).setValue('Modified subject');
    expect(footer().exists()).toBe(true);
    expect(saveButton(wrapper).exists()).toBe(true);

    await subjectInput(wrapper).setValue(original);
    expect(footer().exists()).toBe(false);

    await subjectInput(wrapper).setValue('Modified subject');
    await wrapper.find('form').trigger('submit');
    await flushPromises();

    expect(KanbanBoardsAPI.updateCardDetailsById).toHaveBeenCalledTimes(1);
    expect(footer().exists()).toBe(false);
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

  // Abrir a conversa fecha a ficha (123jpnbcfr0). Sem perguntar, o que se
  // escreveu e não se gravou perdia-se sem aviso — antes sobrevivia por baixo.
  it('asks before leaving for the conversation with unsaved changes', async () => {
    const wrapper = await mountModal({ attachTo: document.body });

    await subjectInput(wrapper).setValue('Modified subject');
    const conversationButton = wrapper.find(
      '[data-testid="kanban-opportunity-header-open-conversation"]'
    );
    conversationButton.element.focus();
    await conversationButton.trigger('click');

    expect(wrapper.emitted('openConversation')).toBeUndefined();
    expect(
      wrapper
        .find('[data-testid="kanban-opportunity-unsaved-changes"]')
        .exists()
    ).toBe(true);

    await wrapper
      .find('[data-testid="kanban-opportunity-keep-editing"]')
      .trigger('click');
    await flushPromises();
    expect(wrapper.emitted('openConversation')).toBeUndefined();
    expect(document.activeElement).toBe(
      wrapper.find(
        '[data-testid="kanban-opportunity-header-open-conversation"]'
      ).element
    );

    await wrapper
      .find('[data-testid="kanban-opportunity-header-open-conversation"]')
      .trigger('click');
    await wrapper
      .find('[data-testid="kanban-opportunity-discard-changes"]')
      .trigger('click');

    expect(wrapper.emitted('openConversation')).toHaveLength(1);
    expect(wrapper.emitted('close')).toBeUndefined();
  });
});
it('does not load or display the legacy follow-up cadence in opportunity details', async () => {
  const wrapper = await mountModal();

  expect(KanbanBoardsAPI.getCadences).not.toHaveBeenCalled();
  expect(
    wrapper.find('[data-testid="kanban-opportunity-cadence"]').exists()
  ).toBe(false);
});
