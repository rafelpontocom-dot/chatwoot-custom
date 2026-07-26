import { shallowMount } from '@vue/test-utils';
import { vi } from 'vitest';

import KanbanWorkflowNode from '../components/KanbanWorkflowNode.vue';

describe('KanbanWorkflowNode', () => {
  it('shows the node category and icon as part of the canvas card', () => {
    const wrapper = shallowMount(KanbanWorkflowNode, {
      props: {
        data: {
          kind: 'send_message',
          category: 'CUSTOMER',
          icon: 'i-lucide-message-square-text',
          label: 'Enviar mensagem',
          summary: 'WhatsApp para o contato',
          state: 'valid',
          stateLabel: 'Pronto',
          chips: ['WhatsApp', 'Olá, Ana'],
          canAddAfter: false,
        },
      },
    });

    expect(
      wrapper
        .find('[data-testid="kanban-workflow-node-card"]')
        .attributes('data-category')
    ).toBe('CUSTOMER');
    expect(
      wrapper.find('[data-testid="kanban-workflow-node-icon"]').classes()
    ).toContain('i-lucide-message-square-text');
    expect(wrapper.text()).toContain('WhatsApp para o contato');
    expect(
      wrapper.find('[data-testid="kanban-workflow-node-state"]').text()
    ).toBe('Pronto');
    expect(
      wrapper.findAll('[data-testid="kanban-workflow-node-chip"]')
    ).toHaveLength(2);
  });

  it('opens its contextual configuration with Enter or Space', async () => {
    const select = vi.fn();
    const wrapper = shallowMount(KanbanWorkflowNode, {
      props: {
        data: {
          id: 'message',
          kind: 'send_message',
          category: 'CUSTOMER',
          label: 'Enviar mensagem',
          select,
        },
      },
    });

    const card = wrapper.find('[data-testid="kanban-workflow-node-card"]');
    expect(card.attributes('tabindex')).toBe('0');
    expect(card.attributes('role')).toBe('group');

    await card.trigger('keydown.enter');
    await card.trigger('keydown.space');

    expect(select).toHaveBeenCalledTimes(2);
    expect(select).toHaveBeenCalledWith('message');
  });
});
