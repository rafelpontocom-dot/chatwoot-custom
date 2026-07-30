import { shallowMount } from '@vue/test-utils';
import KanbanListView from '../KanbanListView.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, values = {}) => {
      const translations = {
        'KANBAN.CARD.UNKNOWN_CONTACT': 'Contato desconhecido',
        'KANBAN.CARD.UNASSIGNED': 'Sem responsável',
        'KANBAN.CARD.NEXT_ACTION.MISSING': 'Sem próxima ação',
        'KANBAN.CARD.NEXT_ACTION.FUTURE': 'Próxima ação',
        'KANBAN.CARD.UNKNOWN_LAST_ACTIVITY': 'Sem atividade',
        'KANBAN.LIST.SELECT': 'Selecionar',
        'KANBAN.LIST.SELECT_VISIBLE': 'Selecionar oportunidades visíveis',
        'KANBAN.LIST.OPPORTUNITY': 'Oportunidade',
        'KANBAN.LIST.STAGE': 'Etapa',
        'KANBAN.LIST.VALUE': 'Valor',
        'KANBAN.LIST.NO_VALUE': 'Sem valor',
        'KANBAN.LIST.NEXT_ACTION': 'Próxima ação',
        'KANBAN.LIST.OWNER': 'Responsável',
        'KANBAN.LIST.ACTIONS': 'Ações',
        'KANBAN.LIST.EMPTY': 'Nenhuma oportunidade',
        'KANBAN.LIST.OPEN': 'Abrir conversa',
        'KANBAN.LIST.PAGINATION_NOTE':
          'Mais oportunidades podem ser carregadas',
        'KANBAN.OVERVIEW.SEPARATOR': '•',
        'KANBAN.LIST.SELECT_OPPORTUNITY': `Selecionar ${values.name}`,
      };

      return translations[key] || key;
    },
  }),
}));

const buildCard = overrides => ({
  id: 10,
  subject: 'Avaliação inicial',
  contact: { name: 'Ana Silva' },
  conversationId: 15,
  nextActionStatus: 'future',
  nextActionType: 'Retornar contato',
  ...overrides,
});

const mountList = ({ card = buildCard() } = {}) =>
  shallowMount(KanbanListView, {
    props: {
      stages: [{ id: 1, name: 'Qualificação', cards: [card] }],
    },
  });

describe('KanbanListView', () => {
  it('shows a clear empty value instead of formatting an unset amount as zero', () => {
    const wrapper = mountList();

    expect(wrapper.text()).toContain('Sem valor');
    expect(wrapper.text()).not.toContain('R$ 0,00');
  });

  it('formats a configured opportunity amount', () => {
    const wrapper = mountList({ card: buildCard({ amountCents: 125000 }) });

    expect(wrapper.text()).toContain('R$ 1.250,00');
  });

  it('selects every visible opportunity without assuming unloaded cards', async () => {
    const wrapper = shallowMount(KanbanListView, {
      props: {
        stages: [
          {
            id: 1,
            name: 'Qualificação',
            cards: [buildCard(), buildCard({ id: 11 })],
          },
        ],
      },
    });

    await wrapper
      .find('[data-testid="kanban-list-select-visible"]')
      .setValue(true);

    expect(wrapper.emitted('toggleVisibleSelection')).toEqual([
      [[10, 11], true],
    ]);
  });

  it('does not offer a conversation action for a manual opportunity', () => {
    const wrapper = mountList({ card: buildCard({ conversationId: null }) });

    expect(wrapper.find('[title="Abrir conversa"]').exists()).toBe(false);
  });
});
