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
        'KANBAN.LIST.EMPTY': 'Ainda não há oportunidades',
        'KANBAN.LIST.EMPTY_HINT': 'Aparecem aqui quando forem criadas.',
        'KANBAN.LIST.EMPTY_FILTERED': 'Nenhuma oportunidade com estes filtros',
        'KANBAN.LIST.EMPTY_FILTERED_HINT': 'Quase sempre é um filtro a mais.',
        'KANBAN.LIST.CLEAR_FILTERS': 'Limpar filtros',
        'KANBAN.LIST.REVIEW_FILTERS': 'Rever filtros',
        'KANBAN.CARD.NEXT_ACTION.OVERDUE': 'Em atraso',
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

const mountList = ({ card = buildCard(), stage = {}, ...props } = {}) =>
  shallowMount(KanbanListView, {
    props: {
      stages: [
        { id: 1, name: 'Qualificação', cards: card ? [card] : [], ...stage },
      ],
      ...props,
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

  // As quatro correções aprovadas a 20/09 para a vista de lista.

  it('lets a long subject wrap to two lines instead of cutting it', () => {
    const wrapper = mountList({
      card: buildCard({
        subject: 'Implante múltiplo — três elementos no maxilar superior',
      }),
    });

    const assunto = wrapper.find('.line-clamp-2');

    expect(assunto.exists()).toBe(true);
    expect(assunto.classes()).not.toContain('truncate');
    expect(assunto.text()).toContain('maxilar superior');
  });

  it('carries the stage colour into the list, as the board and the drawer do', () => {
    const wrapper = mountList({ stage: { color: 'teal' } });

    const selo = wrapper.find('.rounded-full.bg-n-teal-3');

    expect(selo.exists()).toBe(true);
    expect(selo.text()).toContain('Qualificação');
    expect(selo.find('.bg-n-teal-9').exists()).toBe(true);
  });

  it('shows the next action with an icon, never colour alone', () => {
    const wrapper = mountList({
      card: buildCard({ nextActionStatus: 'overdue', nextActionType: null }),
    });

    const selo = wrapper.find('.bg-n-ruby-3');

    expect(selo.exists()).toBe(true);
    expect(selo.find('i').classes()).toContain('i-lucide-clock-alert');
    expect(selo.text()).toContain('Em atraso');
  });

  it('offers a way back when filters emptied the list', async () => {
    const wrapper = mountList({ card: null, hasActiveFilters: true });

    expect(wrapper.text()).toContain('Nenhuma oportunidade com estes filtros');

    await wrapper
      .find('[data-testid="kanban-list-clear-filters"]')
      .trigger('click');
    await wrapper
      .find('[data-testid="kanban-list-review-filters"]')
      .trigger('click');

    expect(wrapper.emitted('clearFilters')).toHaveLength(1);
    expect(wrapper.emitted('openFilters')).toHaveLength(1);
  });

  it('does not promise a way back when there is no filter to clear', () => {
    const wrapper = mountList({ card: null });

    expect(wrapper.text()).toContain('Ainda não há oportunidades');
    expect(
      wrapper.find('[data-testid="kanban-list-clear-filters"]').exists()
    ).toBe(false);
  });
});
