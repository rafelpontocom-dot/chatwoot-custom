import { flushPromises, mount } from '@vue/test-utils';
import KanbanBoardsAPI from 'dashboard/api/kanbanBoards';
import ContactAPI from 'dashboard/api/contacts';
import KanbanContactOpportunityDialog from '../KanbanContactOpportunityDialog.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, params = {}) =>
      Object.entries(params).reduce(
        (texto, [nome, valor]) => texto.replace(`{${nome}}`, valor),
        {
          'KANBAN.CONTACT_OPPORTUNITY.INBOX_HINT':
            "The one from the contact's last conversation.",
          'KANBAN.CONTACT_OPPORTUNITY.DUPLICATE':
            '«{subject}» already exists in {stage}.',
        }[key] || key
      ),
  }),
}));

vi.mock('dashboard/api/kanbanBoards', () => ({
  default: {
    getBoards: vi.fn(),
    showBoard: vi.fn(),
    createManualCard: vi.fn(),
  },
}));

vi.mock('dashboard/api/contacts', () => ({
  default: {
    getConversations: vi.fn(),
    getContactableInboxes: vi.fn(),
  },
}));

const caixas = {
  4: { id: 4, name: 'WhatsApp Alysson' },
  9: { id: 9, name: 'Instagram' },
};
vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({
    getters: { 'inboxes/getInboxById': id => caixas[id] },
  }),
}));

// O jsdom não implementa o <dialog> modal. Funções simples, não `vi.fn`: o
// `mockReset` da configuração apagaria a implementação entre testes.
HTMLDialogElement.prototype.showModal = function abrir() {
  this.open = true;
};
HTMLDialogElement.prototype.close = function fechar() {
  this.open = false;
};

const montados = [];
const montar = async () => {
  const wrapper = mount(KanbanContactOpportunityDialog, {
    props: { contactId: 7, contactName: 'Carla Souza' },
    // `vitest.setup.js` troca o NextButton por um stub; aqui o botão é o real.
    global: { stubs: { Avatar: true, NextButton: false } },
    // Ligado ao documento: só assim o clique em «Criar» submete o formulário.
    attachTo: document.body,
  });
  montados.push(wrapper);
  await wrapper.vm.open();
  await flushPromises();
  return wrapper;
};

const campo = (wrapper, nome) =>
  wrapper.get(`[data-testid="kanban-contact-opportunity-${nome}"]`);

describe('KanbanContactOpportunityDialog', () => {
  afterEach(() => {
    montados.splice(0).forEach(wrapper => wrapper.unmount());
  });

  // No telemóvel o painel do contato é uma gaveta que fecha a qualquer clique
  // fora dela. Teleportado para o <body>, o diálogo contava como «fora»: o
  // primeiro toque fechava a gaveta e desmontava o diálogo antes de gravar.
  it('opens inside the panel, not teleported out of it', async () => {
    const wrapper = await montar();

    const dialogo = wrapper.find('dialog');
    expect(dialogo.exists()).toBe(true);
    expect(dialogo.element.open).toBe(true);
    expect(dialogo.attributes('aria-labelledby')).toBeTruthy();
  });

  it('closes on cancel without creating', async () => {
    const wrapper = await montar();

    await campo(wrapper, 'cancel').trigger('click');

    expect(wrapper.find('dialog').element.open).toBe(false);
    expect(KanbanBoardsAPI.createManualCard).not.toHaveBeenCalled();
  });

  beforeEach(() => {
    KanbanBoardsAPI.getBoards.mockResolvedValue({
      data: [
        { id: 1, name: 'Captação', active: true },
        { id: 2, name: 'Antigo', active: false },
      ],
    });
    KanbanBoardsAPI.showBoard.mockResolvedValue({
      data: {
        stages: [
          { id: 11, name: 'Lead', active: true },
          { id: 12, name: 'Agendado', active: true },
        ],
        custom_field_definitions: [],
      },
    });
    // A mais recente primeiro, como o servidor as devolve.
    ContactAPI.getConversations.mockResolvedValue({
      data: {
        payload: [
          { id: 30, inbox_id: 4 },
          { id: 29, inbox_id: 9 },
          { id: 28, inbox_id: 4 },
        ],
      },
    });
    KanbanBoardsAPI.createManualCard.mockResolvedValue({ data: { id: 55 } });
  });

  it('starts with the contact, the first stage and the inbox of the last conversation', async () => {
    const wrapper = await montar();

    expect(wrapper.text()).toContain('Carla Souza');
    expect(campo(wrapper, 'board').findAll('option')).toHaveLength(1);
    expect(campo(wrapper, 'stage').element.value).toBe('11');
    expect(campo(wrapper, 'subject').element.value).toBe('Carla Souza');
    expect(campo(wrapper, 'inbox').element.value).toBe('4');
    expect(
      campo(wrapper, 'inbox')
        .findAll('option')
        .map(option => option.text())
    ).toEqual(['WhatsApp Alysson', 'Instagram']);
    expect(wrapper.text()).toContain(
      "The one from the contact's last conversation."
    );
  });

  it('creates the opportunity with the value written the Brazilian way', async () => {
    const wrapper = await montar();

    await campo(wrapper, 'stage').setValue('12');
    await campo(wrapper, 'subject').setValue('Carla Souza — avaliação');
    await campo(wrapper, 'amount').setValue('1.200,50');
    await campo(wrapper, 'create').trigger('click');
    await flushPromises();

    expect(KanbanBoardsAPI.createManualCard).toHaveBeenCalledWith(1, {
      card: {
        kanban_stage_id: 12,
        contact_id: 7,
        inbox_id: 4,
        subject: 'Carla Souza — avaliação',
        amount_cents: 120050,
      },
    });
    expect(wrapper.emitted('created')).toEqual([[{ id: 55, boardId: 1 }]]);
  });

  it('does not create with a value that is not a number', async () => {
    const wrapper = await montar();

    await campo(wrapper, 'amount').setValue('mil');

    expect(campo(wrapper, 'create').attributes('disabled')).toBeDefined();
  });

  it('offers the inboxes the contact is in when there is no conversation', async () => {
    ContactAPI.getConversations.mockResolvedValue({ data: { payload: [] } });
    ContactAPI.getContactableInboxes.mockResolvedValue({
      data: { payload: [{ inbox: { id: 9, name: 'Instagram' } }] },
    });
    const wrapper = await montar();

    expect(campo(wrapper, 'inbox').element.value).toBe('9');
    expect(wrapper.text()).not.toContain(
      "The one from the contact's last conversation."
    );
  });

  it('asks for the fields the stage requires and keeps the form', async () => {
    KanbanBoardsAPI.createManualCard.mockRejectedValue({
      response: {
        data: {
          missing_fields: ['origem'],
          field_definitions: [
            {
              key: 'origem',
              label: 'Origem do lead',
              field_type: 'select',
              options: ['Instagram', 'Indicação'],
            },
          ],
        },
      },
    });
    const wrapper = await montar();

    await campo(wrapper, 'subject').setValue('Carla Souza — avaliação');
    await campo(wrapper, 'create').trigger('click');
    await flushPromises();

    expect(campo(wrapper, 'field-origem').exists()).toBe(true);
    expect(campo(wrapper, 'subject').element.value).toBe(
      'Carla Souza — avaliação'
    );
    expect(campo(wrapper, 'error').text()).toBe(
      'KANBAN.CONTACT_OPPORTUNITY.REQUIRED_PENDING'
    );
    expect(wrapper.emitted('created')).toBeUndefined();
  });

  it('names the existing opportunity when the title repeats', async () => {
    KanbanBoardsAPI.createManualCard.mockRejectedValue({
      response: {
        data: {
          code: 'possible_duplicate',
          duplicate_card: { subject: 'Carla Souza', stage_name: 'Lead' },
        },
      },
    });
    const wrapper = await montar();

    await campo(wrapper, 'create').trigger('click');
    await flushPromises();

    expect(campo(wrapper, 'error').text()).toBe(
      '«Carla Souza» already exists in Lead.'
    );
  });
});
