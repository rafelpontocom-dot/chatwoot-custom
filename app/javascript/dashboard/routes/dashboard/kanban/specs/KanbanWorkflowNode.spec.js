import { shallowMount } from '@vue/test-utils';

import KanbanWorkflowNode from '../components/KanbanWorkflowNode.vue';

const montar = (data = {}) =>
  shallowMount(KanbanWorkflowNode, {
    props: {
      data: {
        id: 'message',
        kind: 'send_message',
        category: 'CUSTOMER',
        categoryLabel: 'Cliente',
        label: 'Enviar mensagem de seguimento no WhatsApp',
        summary: 'Modelo oficial · fora do horário silencioso',
        state: 'draft',
        stateLabel: 'Rascunho',
        icon: 'i-lucide-message-circle',
        ...data,
      },
    },
  });

const cartao = wrapper =>
  wrapper.find('[data-testid="kanban-workflow-node-card"]');

const icone = wrapper =>
  wrapper.find('[data-testid="kanban-workflow-node-icon"]').classes();

describe('KanbanWorkflowNode', () => {
  it('keeps the commercial node readable and stable on the canvas', () => {
    const wrapper = montar();

    expect(cartao(wrapper).classes()).toContain('w-[9.5rem]');
    expect(cartao(wrapper).classes()).toContain('py-2');
  });

  it('separates at rest with a ring, never a shadow', () => {
    const classes = cartao(montar()).classes();

    expect(classes).toContain('ring-1');
    expect(classes).toContain('ring-n-weak');
    expect(classes.some(name => name.startsWith('shadow'))).toBe(false);
  });

  it('tells the category by its icon, not by a hue of its own', () => {
    const classes = cartao(montar({ category: 'DECISION' })).classes();

    // Oito matizes de categoria nunca validadas para daltonismo. A cor passou a
    // significar uma coisa só — o estado — e a categoria é o ícone.
    expect(classes.some(name => name.startsWith('border-t'))).toBe(false);
    expect(
      classes.some(name => /^(bg|border|ring)-n-(violet|iris|cyan)/.test(name))
    ).toBe(false);
    expect(
      icone(montar({ category: 'DECISION', icon: 'i-lucide-git-branch' }))
    ).toContain('i-lucide-git-branch');
  });

  it('gives each state its own icon, so the three twin colours stay apart', () => {
    const iconeDoEstado = state =>
      montar({ state, stateLabel: state })
        .find('[data-testid="kanban-workflow-node-state"] i')
        .classes();

    // valid e completed partilham o verde; invalid e failed o rubi; draft e
    // skipped o cinzento. Sem ícone eram três pares indistinguíveis.
    expect(iconeDoEstado('valid')).toContain('i-lucide-check');
    expect(iconeDoEstado('completed')).toContain('i-lucide-circle-check');
    expect(iconeDoEstado('invalid')).toContain('i-lucide-circle-alert');
    expect(iconeDoEstado('failed')).toContain('i-lucide-x');
    expect(iconeDoEstado('draft')).toContain('i-lucide-pencil-line');
    expect(iconeDoEstado('skipped')).toContain('i-lucide-skip-forward');
  });

  it('holds its height whether the node is bare or fully configured', () => {
    const vazio = montar({ summary: '', stateLabel: '', chips: [] });
    const cheio = montar({ chips: ['Modelo', 'Janela', 'Limite'] });

    // Nome em duas linhas fixas, resumo numa, rodapé sempre presente.
    expect(cheio.find('.line-clamp-2').classes()).toContain('min-h-8');
    expect(vazio.find('.line-clamp-2').classes()).toContain('min-h-8');
    expect(vazio.find('.min-h-5').exists()).toBe(true);
    expect(cheio.find('.min-h-5').exists()).toBe(true);

    // A fila de chips virou contagem — era ela que empurrava o cartão.
    const chips = cheio.find('[data-testid="kanban-workflow-node-chips"]');
    expect(chips.text()).toBe('3');
    expect(chips.attributes('title')).toBe('Modelo · Janela · Limite');
  });
});
