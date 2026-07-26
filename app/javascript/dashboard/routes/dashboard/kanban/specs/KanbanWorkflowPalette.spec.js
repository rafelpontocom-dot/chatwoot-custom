import { shallowMount } from '@vue/test-utils';

import KanbanWorkflowPalette from '../components/KanbanWorkflowPalette.vue';

describe('KanbanWorkflowPalette', () => {
  it('filters categories and emits the selected node type', async () => {
    const wrapper = shallowMount(KanbanWorkflowPalette, {
      props: {
        groups: [
          {
            key: 'CUSTOMER',
            label: 'Cliente',
            icon: 'i-lucide-message-circle',
            nodes: [
              {
                type: 'send_message',
                label: 'Enviar mensagem',
                icon: 'i-lucide-message-square-text',
              },
            ],
          },
          {
            key: 'INTEGRATION',
            label: 'Integrações',
            icon: 'i-lucide-webhook',
            nodes: [{ type: 'webhook', label: 'Webhook' }],
          },
        ],
        title: 'Blocos',
        searchPlaceholder: 'Buscar bloco',
        emptyLabel: 'Nenhum bloco encontrado.',
      },
    });

    await wrapper
      .find('[data-testid="kanban-workflow-palette-search"]')
      .setValue('mensagem');
    expect(wrapper.text()).toContain('Enviar mensagem');
    expect(wrapper.text()).not.toContain('Webhook');
    expect(
      wrapper
        .find('[data-testid="kanban-workflow-palette-node-icon"]')
        .classes()
    ).toContain('i-lucide-message-square-text');

    await wrapper
      .find('[data-testid="kanban-workflow-palette-node"]')
      .trigger('click');
    expect(wrapper.emitted('add')).toEqual([['send_message']]);
  });

  it('publishes the node type when a palette item starts dragging', async () => {
    const wrapper = shallowMount(KanbanWorkflowPalette, {
      props: {
        groups: [
          {
            key: 'CUSTOMER',
            label: 'Cliente',
            icon: 'i-lucide-message-circle',
            nodes: [
              {
                type: 'send_message',
                label: 'Enviar mensagem',
                icon: 'i-lucide-message-square-text',
              },
            ],
          },
        ],
        title: 'Blocos',
        searchPlaceholder: 'Buscar bloco',
        emptyLabel: 'Nenhum bloco encontrado.',
      },
    });
    const dataTransfer = { effectAllowed: '', setData: vi.fn() };

    await wrapper
      .find('[data-testid="kanban-workflow-palette-node"]')
      .trigger('dragstart', { dataTransfer });

    expect(dataTransfer.effectAllowed).toBe('move');
    expect(dataTransfer.setData).toHaveBeenCalledWith(
      'application/x-kanban-workflow-node',
      'send_message'
    );
    expect(wrapper.emitted('drag-start')).toEqual([['send_message']]);
  });

  it('renders a translated label for the operation category', () => {
    const wrapper = shallowMount(KanbanWorkflowPalette, {
      props: {
        groups: [
          {
            key: 'OPERATION',
            label: 'Operação',
            icon: 'i-lucide-notebook-pen',
            nodes: [
              {
                type: 'audit_log',
                label: 'Adicionar nota interna à linha do tempo',
                icon: 'i-lucide-notebook-pen',
              },
            ],
          },
        ],
        title: 'Blocos',
        searchPlaceholder: 'Buscar bloco',
        emptyLabel: 'Nenhum bloco encontrado.',
      },
    });

    expect(wrapper.text()).toContain('Operação');
    expect(wrapper.text()).not.toContain('KANBAN.SETTINGS');
  });
});
