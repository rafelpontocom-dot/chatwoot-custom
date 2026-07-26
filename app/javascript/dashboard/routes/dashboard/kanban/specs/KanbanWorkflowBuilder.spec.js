import { shallowMount } from '@vue/test-utils';
import KanbanWorkflowBuilder from '../components/KanbanWorkflowBuilder.vue';
import KanbanWorkflowPalette from '../components/KanbanWorkflowPalette.vue';

const translations = {
  'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.QUIET_TIMEZONE':
    'Fuso do horario silencioso',
  'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.TEMPLATE_NAME':
    'Template oficial do WhatsApp',
  'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.TEMPLATE_LANGUAGE':
    'Idioma do template',
  'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.TEMPLATE_CATEGORY':
    'Categoria do template',
  'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.TEMPLATE_NAMESPACE':
    'Namespace do template',
  'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.FREQUENCY_LIMIT':
    'Intervalo minimo entre mensagens (horas)',
  'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.QUIET_START': 'Nao enviar depois de',
  'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.QUIET_END': 'Voltar a enviar as',
};

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => translations[key] || key }),
}));

describe('KanbanWorkflowBuilder', () => {
  it('renders the visual canvas and opens the node selector', async () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: { modelValue: {} },
    });

    expect(
      wrapper.find('[data-testid="kanban-workflow-builder"]').exists()
    ).toBe(true);
    await wrapper
      .find('[data-testid="kanban-workflow-add-node"]')
      .trigger('click');
    expect(
      wrapper.find('[data-testid="kanban-workflow-node-menu"]').exists()
    ).toBe(true);
    expect(wrapper.findAllComponents(KanbanWorkflowPalette)).toHaveLength(1);
  });

  it('keeps the add control inside a full-height visual canvas', () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: { modelValue: {} },
    });

    const canvas = wrapper.find('[data-testid="kanban-workflow-canvas"]');

    expect(canvas.exists()).toBe(true);
    expect(canvas.classes()).toContain('h-full');
    expect(
      canvas.find('[data-testid="kanban-workflow-add-node"]').exists()
    ).toBe(true);
    expect(wrapper.text()).not.toContain(
      'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.TITLE'
    );
  });

  it('exposes the visual canvas as a named region for assistive technology', () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: { modelValue: {} },
    });

    const canvas = wrapper.find('[data-testid="kanban-workflow-canvas"]');

    expect(canvas.attributes('role')).toBe('region');
    expect(canvas.attributes('aria-label')).toBe(
      'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.CANVAS_LABEL'
    );
  });

  it('uses the custom workflow edge for all canvas connections', () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: { modelValue: {} },
    });

    expect(wrapper.vm.edgeTypes).toHaveProperty('kanbanWorkflow');
    expect(wrapper.vm.edges[0].type).toBe('kanbanWorkflow');
  });

  it('starts with a valid trigger-to-end flow instead of an incomplete message', () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: { modelValue: {} },
    });

    expect(wrapper.vm.nodes.map(node => node.type)).toEqual(['trigger', 'end']);
    expect(wrapper.vm.edges).toEqual([
      expect.objectContaining({ source: 'trigger', target: 'end' }),
    ]);
  });

  it('configures the semantic outcome of an end node', async () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: { modelValue: {} },
    });
    wrapper.vm.selectNode(wrapper.vm.nodes.find(node => node.type === 'end'));
    await wrapper.vm.$nextTick();

    expect(wrapper.text()).toContain(
      'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.END_OUTCOME'
    );
  });

  it('undoes and redoes a canvas node insertion', async () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: { modelValue: {} },
    });

    wrapper.vm.addNodeOfType('delay');
    await wrapper.vm.$nextTick();
    wrapper.vm.undoCanvas();

    expect(wrapper.vm.nodes.map(node => node.type)).toEqual(['trigger', 'end']);
    expect(
      wrapper
        .find('[data-testid="kanban-workflow-redo"]')
        .attributes('disabled')
    ).toBe('');

    wrapper.vm.redoCanvas();

    expect(wrapper.vm.nodes.map(node => node.type)).toContain('delay');
  });

  it('supports undo and redo shortcuts while the canvas has focus', async () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: { modelValue: {} },
    });

    wrapper.vm.addNodeOfType('delay');
    await wrapper.vm.$nextTick();

    await wrapper
      .find('[data-testid="kanban-workflow-builder"]')
      .trigger('keydown', { key: 'z', ctrlKey: true });
    expect(wrapper.vm.nodes.map(node => node.type)).toEqual(['trigger', 'end']);

    await wrapper
      .find('[data-testid="kanban-workflow-builder"]')
      .trigger('keydown', { key: 'z', ctrlKey: true, shiftKey: true });
    expect(wrapper.vm.nodes.map(node => node.type)).toContain('delay');
  });

  it('removes a selected editable node with the Delete key', async () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: { modelValue: {} },
    });

    wrapper.vm.addNodeOfType('delay');
    await wrapper.vm.$nextTick();

    await wrapper
      .find('[data-testid="kanban-workflow-builder"]')
      .trigger('keydown', { key: 'Delete' });

    expect(wrapper.vm.nodes.map(node => node.type)).toEqual(['trigger', 'end']);
  });

  it('moves a selected node with arrow keys and supports undo', async () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: {
        modelValue: {
          nodes: [
            {
              id: 'delay',
              type: 'delay',
              position: { x: 100, y: 100 },
              data: { delay_hours: 24 },
            },
          ],
          edges: [],
        },
      },
    });
    await wrapper.vm.$nextTick();
    wrapper.vm.selectNode(wrapper.vm.nodes[0]);
    await wrapper.vm.$nextTick();

    const inspector = wrapper.find(
      '[data-testid="kanban-workflow-node-drawer"]'
    );
    expect(inspector.attributes('role')).toBe('dialog');
    expect(inspector.attributes('aria-labelledby')).toBe(
      'kanban-workflow-inspector-title'
    );
    expect(inspector.find('#kanban-workflow-inspector-title').text()).toContain(
      wrapper.vm.selectedNode.data.label
    );

    await wrapper
      .find('[data-testid="kanban-workflow-builder"]')
      .trigger('keydown', { key: 'ArrowRight' });

    expect(wrapper.vm.nodes[0].position.x).toBe(116);
    wrapper.vm.undoCanvas();
    expect(wrapper.vm.nodes[0].position.x).toBe(100);
  });

  it('automatically arranges the canvas without losing the previous layout', () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: { modelValue: {} },
    });

    wrapper.vm.autoArrangeCanvas();

    expect(wrapper.vm.nodes[0].position).toEqual({ x: 48, y: 120 });
    expect(wrapper.vm.nodes[1].position).toEqual({ x: 320, y: 120 });

    wrapper.vm.undoCanvas();

    expect(wrapper.vm.nodes[0].position).toEqual({ x: 32, y: 180 });
  });

  it('decorates canvas nodes from the shared node registry', () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: {
        modelValue: {
          nodes: [
            { id: 'message', type: 'send_message', data: {} },
            { id: 'router', type: 'condition', data: {} },
          ],
          edges: [],
        },
      },
    });

    expect(wrapper.vm.nodes).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          id: 'message',
          data: expect.objectContaining({
            icon: 'i-lucide-message-square-text',
            category: 'CUSTOMER',
          }),
        }),
        expect.objectContaining({
          id: 'router',
          data: expect.objectContaining({
            icon: 'i-lucide-git-branch',
            category: 'DECISION',
          }),
        }),
      ])
    );
  });

  it('keeps the trigger inspector closed until the user selects a node', () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: { modelValue: {} },
    });

    expect(
      wrapper.find('[data-testid="kanban-workflow-node-drawer"]').exists()
    ).toBe(false);
  });

  it('returns focus to the workflow editor when the inspector closes', async () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: { modelValue: {} },
      attachTo: document.body,
    });

    wrapper.vm.selectNode(wrapper.vm.nodes[0]);
    await wrapper.vm.$nextTick();
    wrapper.vm.closeInspector();
    await wrapper.vm.$nextTick();

    expect(document.activeElement).toBe(
      wrapper.find('[data-testid="kanban-workflow-builder"]').element
    );
    wrapper.unmount();
  });

  it('separates node configuration, preview, and state in inspector tabs', async () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: {
        modelValue: {
          nodes: [
            {
              id: 'wait',
              type: 'delay',
              data: { delay_hours: 24 },
            },
          ],
          edges: [],
        },
      },
    });

    wrapper.vm.selectNode(wrapper.vm.nodes[0]);
    await wrapper.vm.$nextTick();

    await wrapper
      .find('[data-testid="kanban-workflow-inspector-tab-test"]')
      .trigger('click');
    expect(
      wrapper.find('[data-testid="kanban-workflow-inspector-test"]').exists()
    ).toBe(true);

    await wrapper
      .find('[data-testid="kanban-workflow-inspector-tab-history"]')
      .trigger('click');
    expect(
      wrapper.find('[data-testid="kanban-workflow-inspector-history"]').exists()
    ).toBe(true);
  });

  it('shows safe execution history for the selected node only', async () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: {
        executionHistory: [
          {
            nodeId: 'wait',
            status: 'waiting',
            executedAt: '2026-07-25T22:00:00.000Z',
            reason: 'quiet_hours',
            authorization: 'must-not-be-rendered',
          },
          { nodeId: 'other', status: 'succeeded' },
        ],
        modelValue: {
          nodes: [
            {
              id: 'wait',
              type: 'delay',
              data: { delay_hours: 24 },
            },
          ],
          edges: [],
        },
      },
    });

    wrapper.vm.selectNode(wrapper.vm.nodes[0]);
    await wrapper.vm.$nextTick();
    await wrapper
      .find('[data-testid="kanban-workflow-inspector-tab-history"]')
      .trigger('click');

    const history = wrapper.find(
      '[data-testid="kanban-workflow-inspector-history"]'
    );
    expect(history.text()).not.toContain('must-not-be-rendered');
  });

  it('only shows the minimap for a workflow that needs spatial context', async () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: {
        modelValue: {
          nodes: [
            { id: 'trigger', type: 'trigger', data: {} },
            { id: 'wait', type: 'delay', data: { delay_hours: 24 } },
            { id: 'filter', type: 'filter', data: {} },
            { id: 'message', type: 'send_message', data: {} },
            { id: 'end', type: 'end', data: {} },
          ],
          edges: [],
        },
      },
    });

    await wrapper.vm.$nextTick();

    expect(wrapper.vm.showMiniMap).toBe(true);
  });

  it('lets the user choose the rule trigger from the trigger node', async () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: {
        modelValue: {},
        triggerValue: 'kanban.card.stage_changed',
        triggerOptions: [
          {
            value: 'kanban.card.stage_changed',
            label: 'Stage changed',
          },
          { value: 'kanban.card.won', label: 'Card won' },
        ],
      },
    });

    wrapper.vm.selectNode(wrapper.vm.nodes[0]);
    await wrapper.vm.$nextTick();
    await wrapper
      .find('[data-testid="kanban-workflow-trigger-select"]')
      .setValue('kanban.card.won');

    expect(wrapper.emitted('update:triggerValue')).toEqual([
      ['kanban.card.won'],
    ]);
  });

  it('summarizes the selected trigger directly on the canvas node', () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: {
        triggerValue: 'kanban.card.stage_changed',
        triggerOptions: [
          {
            value: 'kanban.card.stage_changed',
            label: 'Etapa alterada',
          },
        ],
        modelValue: {
          nodes: [{ id: 'trigger', type: 'trigger', data: {} }],
          edges: [],
        },
      },
    });

    expect(wrapper.vm.nodes[0].data.summary).toBe('Etapa alterada');
  });

  it('uses a human-readable summary for a date wait before an appointment', () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: {
        dateFields: [{ key: 'consultation_at', label: 'Consulta' }],
        modelValue: {
          nodes: [
            {
              id: 'wait',
              type: 'wait_until_field',
              data: { field_key: 'consultation_at', offset_hours: -24 },
            },
          ],
          edges: [],
        },
      },
    });

    expect(wrapper.vm.nodes[0].data.summary).toBe(
      'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.DATE_OFFSET_BEFORE'
    );
  });

  it('adds an unavailable-date branch only when the date wait is configured to route failures', async () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: {
        dateFields: [{ key: 'consultation_at', label: 'Consulta' }],
        modelValue: {
          nodes: [
            {
              id: 'wait',
              type: 'wait_until_field',
              data: { field_key: 'consultation_at', offset_hours: -24 },
            },
          ],
          edges: [],
        },
      },
    });

    expect(wrapper.vm.nodes[0].data.canAddAfter).toBe(true);
    wrapper.vm.selectNode(wrapper.vm.nodes[0]);
    await wrapper.vm.$nextTick();
    await wrapper
      .find('[data-testid="kanban-workflow-date-failure-mode"]')
      .setValue('route');

    expect(wrapper.vm.nodes[0].data.canAddAfter).toBe(false);
    expect(wrapper.vm.nodes[0].data.outputs).toEqual([
      expect.objectContaining({ id: 'succeeded' }),
      expect.objectContaining({ id: 'failed' }),
    ]);
    expect(wrapper.vm.selectedNodeOutputOptions).toEqual([
      expect.objectContaining({ value: 'succeeded' }),
      expect.objectContaining({ value: 'failed' }),
    ]);
  });

  it('adds response and timeout branches only when the response wait is configured to route timeouts', async () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: {
        modelValue: {
          nodes: [
            {
              id: 'reply',
              type: 'wait_for_response',
              data: { timeout_hours: 24 },
            },
          ],
          edges: [],
        },
      },
    });

    wrapper.vm.selectNode(wrapper.vm.nodes[0]);
    await wrapper.vm.$nextTick();
    await wrapper
      .find('[data-testid="kanban-workflow-response-timeout-mode"]')
      .setValue('route');

    expect(wrapper.vm.nodes[0].data.outputs).toEqual([
      expect.objectContaining({ id: 'received' }),
      expect.objectContaining({ id: 'timeout' }),
    ]);
    expect(wrapper.vm.selectedNodeOutputOptions).toEqual([
      expect.objectContaining({ value: 'received' }),
      expect.objectContaining({ value: 'timeout' }),
    ]);
  });

  it('adds inactivity and response branches only when the inactivity wait is configured to route interruptions', async () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: {
        modelValue: {
          nodes: [
            {
              id: 'inactive',
              type: 'wait_for_inactivity',
              data: { timeout_hours: 24 },
            },
          ],
          edges: [],
        },
      },
    });

    wrapper.vm.selectNode(wrapper.vm.nodes[0]);
    await wrapper.vm.$nextTick();
    await wrapper
      .find('[data-testid="kanban-workflow-inactivity-interruption-mode"]')
      .setValue('route');

    expect(wrapper.vm.nodes[0].data.outputs).toEqual([
      expect.objectContaining({ id: 'inactive' }),
      expect.objectContaining({ id: 'responded' }),
    ]);
  });

  it('adds available and unavailable branches when business hours route failures', async () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: {
        modelValue: {
          nodes: [
            {
              id: 'business-hours',
              type: 'wait_for_business_hours',
              data: {
                weekdays: [1, 2, 3, 4, 5],
                start_time: '09:00',
                end_time: '18:00',
                timezone: 'America/Sao_Paulo',
              },
            },
          ],
          edges: [],
        },
      },
    });

    wrapper.vm.selectNode(wrapper.vm.nodes[0]);
    await wrapper.vm.$nextTick();
    await wrapper
      .find('[data-testid="kanban-workflow-business-hours-failure-mode"]')
      .setValue('route');

    expect(wrapper.vm.nodes[0].data.outputs).toEqual([
      expect.objectContaining({ id: 'succeeded' }),
      expect.objectContaining({ id: 'failed' }),
    ]);
  });

  it('keeps the newly added node selected after the parent syncs the flow', async () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: { modelValue: {} },
    });

    wrapper.vm.addNodeOfType('send_message');
    await wrapper.vm.$nextTick();
    const emittedFlow = wrapper.emitted('update:modelValue').at(-1)[0];
    await wrapper.setProps({ modelValue: emittedFlow });

    expect(wrapper.vm.selectedNode.type).toBe('send_message');
    expect(
      wrapper.find('[data-testid="kanban-workflow-node-drawer"]').text()
    ).toContain('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODES.MESSAGE');
  });

  it('opens a connection pop-up and removes the selected connection', async () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: {
        modelValue: {
          nodes: [
            { id: 'trigger', type: 'trigger', data: {} },
            { id: 'end', type: 'end', data: {} },
          ],
          edges: [{ id: 'trigger-end', source: 'trigger', target: 'end' }],
        },
      },
    });

    await wrapper.vm.onEdgeClick({ edge: { id: 'trigger-end' } });

    expect(
      wrapper.find('[data-testid="kanban-workflow-connection-dialog"]').exists()
    ).toBe(true);
    wrapper.vm.removeSelectedEdge();

    expect(wrapper.vm.edges).toEqual([]);
  });

  it('connects existing nodes through the keyboard-accessible inspector control', async () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: {
        modelValue: {
          nodes: [
            { id: 'trigger', type: 'trigger', data: {} },
            { id: 'message', type: 'send_message', data: { content: 'Olá' } },
            { id: 'end', type: 'end', data: {} },
          ],
          edges: [],
        },
      },
    });

    wrapper.vm.selectNode(wrapper.vm.nodes.find(node => node.id === 'trigger'));
    await wrapper.vm.$nextTick();
    await wrapper
      .find('[data-testid="kanban-workflow-connect-node"]')
      .trigger('click');
    await wrapper
      .find('[data-testid="kanban-workflow-connect-target"]')
      .setValue('message');
    await wrapper
      .find('[data-testid="kanban-workflow-connect-confirm"]')
      .trigger('click');

    expect(wrapper.vm.edges).toEqual([
      expect.objectContaining({ source: 'trigger', target: 'message' }),
    ]);
  });

  it('rejects a keyboard connection that would create a workflow cycle', async () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: {
        modelValue: {
          nodes: [
            { id: 'trigger', type: 'trigger', data: {} },
            { id: 'message', type: 'send_message', data: { content: 'Olá' } },
          ],
          edges: [{ source: 'trigger', target: 'message' }],
        },
      },
    });

    wrapper.vm.selectNode(wrapper.vm.nodes.find(node => node.id === 'message'));
    await wrapper.vm.$nextTick();
    await wrapper
      .find('[data-testid="kanban-workflow-connect-node"]')
      .trigger('click');
    await wrapper
      .find('[data-testid="kanban-workflow-connect-target"]')
      .setValue('trigger');
    await wrapper
      .find('[data-testid="kanban-workflow-connect-confirm"]')
      .trigger('click');

    expect(wrapper.vm.edges).toHaveLength(1);
    expect(wrapper.vm.connectionError).toBe(
      'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.CONNECTION_CYCLE_ERROR'
    );
  });

  it('renders the action inspector for a selected node', async () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: {
        modelValue: {
          nodes: [
            {
              id: 'action',
              type: 'action',
              data: { action_name: 'archive_card' },
            },
          ],
          edges: [],
        },
      },
    });

    wrapper.vm.selectNode(wrapper.vm.nodes[0]);
    await wrapper.vm.$nextTick();

    expect(
      wrapper.find('[data-testid="kanban-workflow-node-drawer"]').exists()
    ).toBe(true);
    expect(
      wrapper.find('[data-testid="kanban-workflow-node-drawer"]').classes()
    ).toContain('max-w-4xl');
    expect(
      wrapper.find('[data-testid="kanban-workflow-inspector-icon"]').classes()
    ).toContain('i-lucide-briefcase-business');
    expect(
      wrapper.find('[data-testid="kanban-workflow-node-drawer"]').text()
    ).not.toContain('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODE_SETTINGS');
    expect(wrapper.text()).toContain(
      'KANBAN.SETTINGS.AUTOMATIONS.ACTIONS.ARCHIVE_CARD'
    );
  });

  it('uses the selected commercial action as the canvas node title', () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: {
        modelValue: {
          nodes: [
            {
              id: 'move-stage',
              type: 'action',
              data: {
                action_name: 'move_stage',
                action_params: { stage_id: '' },
              },
            },
          ],
          edges: [],
        },
      },
    });

    expect(wrapper.vm.nodes[0].data.label).toBe(
      'KANBAN.SETTINGS.AUTOMATIONS.ACTIONS.MOVE_STAGE'
    );
  });

  it('summarizes the configured target of commercial actions on the canvas', () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: {
        stages: [{ id: 5, name: 'Proposta enviada' }],
        agents: [{ id: 9, name: 'Ana Paula' }],
        nextActionTypes: ['Ligar para o cliente'],
        modelValue: {
          nodes: [
            {
              id: 'move',
              type: 'action',
              data: {
                action_name: 'move_stage',
                action_params: { stage_id: 5 },
              },
            },
            {
              id: 'assign',
              type: 'action',
              data: {
                action_name: 'assign_owner',
                action_params: { owner_id: 9 },
              },
            },
          ],
          edges: [],
        },
      },
    });

    expect(
      wrapper.vm.nodes.find(node => node.id === 'move').data.chips
    ).toEqual(['Proposta enviada']);
    expect(
      wrapper.vm.nodes.find(node => node.id === 'assign').data.chips
    ).toEqual(['Ana Paula']);
  });

  it('keeps conditional rules inside the inspector instead of exposing them on the card', () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: {
        modelValue: {
          nodes: [
            {
              id: 'router',
              type: 'condition',
              data: {
                branches: [
                  {
                    id: 'qualified',
                    label: 'Qualificado',
                    match_mode: 'all',
                    conditions: [
                      {
                        field_key: 'origem',
                        operator: 'equals',
                        value: 'Google',
                      },
                      {
                        field_key: 'valor',
                        operator: 'greater_than',
                        value: '100',
                      },
                    ],
                  },
                ],
                fallback_id: 'otherwise',
              },
            },
          ],
          edges: [],
        },
      },
    });

    expect(wrapper.vm.nodes[0].data.chips).toEqual([]);
    expect(wrapper.vm.nodes[0].data.summary).toBe('');
  });

  it('offers known contact attributes before a custom attribute key', async () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: {
        modelValue: {
          nodes: [
            {
              id: 'contact',
              type: 'update_contact',
              data: { action_params: { attribute_key: '', value: '' } },
            },
          ],
          edges: [],
        },
      },
    });

    wrapper.vm.selectNode(wrapper.vm.nodes[0]);
    await wrapper.vm.$nextTick();
    await wrapper
      .find('[data-testid="kanban-workflow-contact-attribute-select"]')
      .setValue('date_of_birth');

    expect(wrapper.vm.selectedNode.data.action_params.attribute_key).toBe(
      'date_of_birth'
    );
  });

  it('uses a boolean control for a contact consent attribute', async () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: {
        modelValue: {
          nodes: [
            {
              id: 'contact',
              type: 'update_contact',
              data: { action_params: { attribute_key: '', value: '' } },
            },
          ],
          edges: [],
        },
      },
    });

    wrapper.vm.selectNode(wrapper.vm.nodes[0]);
    await wrapper.vm.$nextTick();
    await wrapper
      .find('[data-testid="kanban-workflow-contact-attribute-select"]')
      .setValue('marketing_messages_opt_in');
    await wrapper.vm.$nextTick();
    await wrapper
      .find('[data-testid="kanban-workflow-contact-value-boolean"]')
      .setValue(true);

    expect(wrapper.vm.selectedNode.data.action_params.value).toBe(true);
  });

  it('summarizes a disabled contact consent on the canvas', () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: {
        modelValue: {
          nodes: [
            {
              id: 'contact',
              type: 'update_contact',
              data: {
                action_params: {
                  attribute_key: 'marketing_messages_opt_in',
                  value: false,
                },
              },
            },
          ],
          edges: [],
        },
      },
    });

    expect(wrapper.vm.nodes[0].data.chips).toEqual([
      'marketing_messages_opt_in',
      'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.CONTACT_VALUE_DISABLED',
    ]);
  });

  it('summarizes the official template selected for a WhatsApp message', () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: {
        modelValue: {
          nodes: [
            {
              id: 'message',
              type: 'send_message',
              data: {
                channel: 'whatsapp',
                content: '',
                whatsapp_template_params: { name: 'consulta_confirmacao' },
              },
            },
          ],
          edges: [],
        },
      },
    });

    expect(wrapper.vm.nodes[0].data.chips).toEqual([
      'whatsapp',
      'consulta_confirmacao',
    ]);
  });

  it('summarizes the channel and consent checked by message eligibility', () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: {
        modelValue: {
          nodes: [
            {
              id: 'eligible',
              type: 'message_eligibility',
              data: {
                channel: 'whatsapp',
                opt_in_attribute_key: 'marketing_messages_opt_in',
              },
            },
          ],
          edges: [],
        },
      },
    });

    expect(wrapper.vm.nodes[0].data.chips).toEqual([
      'whatsapp',
      'marketing_messages_opt_in',
    ]);
  });

  it('shows the safe reason when message eligibility blocks a path', () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: {
        executionHistory: [
          {
            nodeId: 'eligible',
            status: 'skipped',
            reason: 'opt_in_required',
          },
        ],
        modelValue: {
          nodes: [
            {
              id: 'eligible',
              type: 'message_eligibility',
              data: {
                channel: 'whatsapp',
                opt_in_attribute_key: 'marketing_messages_opt_in',
              },
            },
          ],
          edges: [],
        },
      },
    });

    expect(wrapper.vm.nodes[0].data.chips).toContain(
      'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.MESSAGE_BLOCKED_OPT_IN'
    );
  });

  it('focuses the invalid step so its configuration can be corrected', async () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: {
        modelValue: {
          nodes: [
            { id: 'trigger', type: 'trigger', data: {} },
            {
              id: 'message',
              type: 'send_message',
              data: { content: '', opt_in_attribute_key: '' },
            },
          ],
          edges: [
            { id: 'trigger-message', source: 'trigger', target: 'message' },
          ],
        },
        invalidNodeIds: ['message'],
      },
    });

    await wrapper.vm.$nextTick();

    expect(wrapper.vm.selectedNode.id).toBe('message');
    expect(wrapper.vm.selectedNode.data.invalid).toBe(true);
    expect(
      wrapper.find('[data-testid="kanban-workflow-node-drawer"]').exists()
    ).toBe(true);
  });

  it('records a snapshot before editing a node setting', async () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: {
        modelValue: {
          nodes: [
            {
              id: 'delay',
              type: 'delay',
              position: { x: 0, y: 0 },
              data: { delay_hours: 24 },
            },
          ],
          edges: [],
        },
      },
    });
    await wrapper.vm.$nextTick();

    wrapper.vm.recordInspectorState({ target: { tagName: 'INPUT' } });

    expect(wrapper.vm.canUndo).toBe(true);
  });

  it('closes the configuration drawer with Escape', () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: {
        modelValue: {
          nodes: [{ id: 'trigger', type: 'trigger', data: {} }],
          edges: [],
        },
      },
    });
    const preventDefault = vi.fn();

    wrapper.vm.handleInspectorKeydown({ key: 'Escape', preventDefault });

    expect(preventDefault).toHaveBeenCalled();
    expect(wrapper.vm.selectedNode).toBeUndefined();
  });

  it('inserts emoji and opportunity variables in a message node', async () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: {
        modelValue: {
          nodes: [
            {
              id: 'message',
              type: 'send_message',
              data: {
                channel: 'whatsapp',
                content: 'Olá ',
                opt_in_attribute_key: 'marketing_messages_opt_in',
                quiet_hours: {},
                whatsapp_template_params: {},
              },
            },
          ],
          edges: [],
        },
        customFields: [{ key: 'origem', label: 'Origem', fieldType: 'text' }],
      },
    });

    wrapper.vm.selectNode(wrapper.vm.nodes[0]);
    await wrapper.vm.$nextTick();

    expect(
      wrapper.find('[data-testid="kanban-message-emoji-button"]').exists()
    ).toBe(true);
    await wrapper
      .find('[data-testid="kanban-message-variable-button"]')
      .trigger('click');
    expect(wrapper.text()).toContain('Origem');

    wrapper.vm.insertMessageText('{{field.origem}}');

    expect(wrapper.vm.selectedNode.data.content).toContain('{{field.origem}}');
  });

  it('does not expose the legacy cadence action in the visual builder', () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: {
        modelValue: {
          nodes: [
            {
              id: 'action',
              type: 'action',
              data: {
                action_name: 'set_next_action',
                action_params: {},
              },
            },
          ],
          edges: [],
        },
      },
    });

    expect(wrapper.text()).not.toContain(
      'KANBAN.SETTINGS.AUTOMATIONS.ACTIONS.ENROLL_CADENCE'
    );
  });

  it('offers business hours for commercial follow-ups', async () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: { modelValue: {} },
    });

    await wrapper
      .find('[data-testid="kanban-workflow-add-node"]')
      .trigger('click');

    expect(
      wrapper.vm.paletteGroups
        .flatMap(group => group.nodes)
        .map(node => node.type)
    ).toContain('wait_for_business_hours');
  });

  it('configures inactivity separately from a response wait', async () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: {
        modelValue: {
          nodes: [
            {
              id: 'inactivity',
              type: 'wait_for_inactivity',
              data: { timeout_hours: 24 },
            },
          ],
          edges: [],
        },
      },
    });

    wrapper.vm.selectNode(wrapper.vm.nodes[0]);
    await wrapper.vm.$nextTick();

    expect(wrapper.text()).toContain(
      'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.INACTIVITY_TIMEOUT_HOURS'
    );
    expect(wrapper.vm.nodes[0].data.summary).toBe(
      'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.INACTIVITY_TIMEOUT'
    );
  });

  it('configures a terminal handoff to a human agent', async () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: {
        agents: [{ id: 7, name: 'Ana Paula' }],
        modelValue: {
          nodes: [
            {
              id: 'handoff',
              type: 'human_handoff',
              data: { owner_id: 7, note: 'Assumir atendimento' },
            },
          ],
          edges: [],
        },
      },
    });

    wrapper.vm.selectNode(wrapper.vm.nodes[0]);
    await wrapper.vm.$nextTick();

    expect(
      wrapper.find('[data-testid="kanban-workflow-handoff-owner"]').exists()
    ).toBe(true);
    expect(wrapper.vm.nodes[0].data.summary).toBe('Ana Paula');
    expect(wrapper.vm.nodes[0].data.canAddAfter).toBe(false);
  });

  it('offers a commercial team as a handoff destination', async () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: {
        teams: [{ id: 4, name: 'Comercial' }],
        modelValue: {
          nodes: [
            {
              id: 'handoff',
              type: 'human_handoff',
              data: { owner_id: '', team_id: '', note: '' },
            },
          ],
          edges: [],
        },
      },
    });

    wrapper.vm.selectNode(wrapper.vm.nodes[0]);
    await wrapper.vm.$nextTick();
    await wrapper
      .find('[data-testid="kanban-workflow-handoff-team"]')
      .setValue('4');

    expect(wrapper.vm.selectedNode.data.team_id).toBe(4);
  });

  it('explains the dedicated next-action completion node', async () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: {
        modelValue: {
          nodes: [{ id: 'complete', type: 'complete_next_action', data: {} }],
          edges: [],
        },
      },
    });

    wrapper.vm.selectNode(wrapper.vm.nodes[0]);
    await wrapper.vm.$nextTick();

    expect(wrapper.text()).toContain(
      'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.COMPLETE_NEXT_ACTION_HINT'
    );
  });

  it('records a completion note for the next-action node', async () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: {
        modelValue: {
          nodes: [
            {
              id: 'complete',
              type: 'complete_next_action',
              data: { action_params: { completion_note: '' } },
            },
          ],
          edges: [],
        },
      },
    });

    wrapper.vm.selectNode(wrapper.vm.nodes[0]);
    await wrapper.vm.$nextTick();
    await wrapper
      .find('[data-testid="kanban-workflow-completion-note"]')
      .setValue('Cliente confirmou a proposta');

    expect(wrapper.vm.selectedNode.data.action_params.completion_note).toBe(
      'Cliente confirmou a proposta'
    );
    expect(wrapper.vm.selectedNode.data.chips).toContain(
      'Cliente confirmou a proposta'
    );
  });

  it('reveals the next action form only when scheduling another action', async () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: {
        nextActionTypes: ['Ligar para confirmar'],
        modelValue: {
          nodes: [
            {
              id: 'complete',
              type: 'complete_next_action',
              data: { action_params: { completion_note: '' } },
            },
          ],
          edges: [],
        },
      },
    });

    wrapper.vm.selectNode(wrapper.vm.nodes[0]);
    await wrapper.vm.$nextTick();
    expect(
      wrapper.find('[data-testid="kanban-workflow-next-action-type"]').exists()
    ).toBe(false);

    await wrapper
      .find('[data-testid="kanban-workflow-schedule-next-action"]')
      .setValue(true);

    expect(
      wrapper.find('[data-testid="kanban-workflow-next-action-type"]').exists()
    ).toBe(true);
  });

  it('requires a configured reason when marking an opportunity as lost', async () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: {
        lostReasonOptions: ['Preço', 'Sem resposta'],
        modelValue: {
          nodes: [
            {
              id: 'lost',
              type: 'mark_lost',
              data: { action_params: { lost_reason: '' } },
            },
          ],
          edges: [],
        },
      },
    });

    wrapper.vm.selectNode(wrapper.vm.nodes[0]);
    await wrapper.vm.$nextTick();

    expect(
      wrapper.find('[data-testid="kanban-workflow-lost-reason"]').text()
    ).toContain('Preço');
  });

  it('offers a field increment action for commercial follow-ups', async () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: {
        modelValue: {
          nodes: [
            {
              id: 'action',
              type: 'action',
              data: { action_name: 'increment_field', action_params: {} },
            },
          ],
          edges: [],
        },
      },
    });

    wrapper.vm.selectNode(wrapper.vm.nodes[0]);
    await wrapper.vm.$nextTick();

    expect(wrapper.text()).toContain(
      'KANBAN.SETTINGS.AUTOMATIONS.ACTIONS.INCREMENT_FIELD'
    );
  });

  it('lets an administrator clear a configured opportunity field', async () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: {
        customFields: [
          { key: 'origem', label: 'Origem', fieldType: 'text', options: [] },
        ],
        modelValue: {
          nodes: [
            {
              id: 'action',
              type: 'action',
              data: {
                action_name: 'clear_field',
                action_params: { field_key: 'origem' },
              },
            },
          ],
          edges: [],
        },
      },
    });

    wrapper.vm.selectNode(wrapper.vm.nodes[0]);
    await wrapper.vm.$nextTick();

    expect(wrapper.text()).toContain(
      'KANBAN.SETTINGS.AUTOMATIONS.ACTIONS.CLEAR_FIELD'
    );
    expect(
      wrapper
        .find('[data-testid="kanban-workflow-action-field-value"]')
        .exists()
    ).toBe(false);
  });

  it('defaults existing round-robin assignment actions to any selected agent', () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: {
        modelValue: {
          nodes: [
            {
              id: 'assign',
              type: 'action',
              position: { x: 0, y: 0 },
              data: {
                action_name: 'assign_round_robin',
                action_params: { owner_ids: [1, 2] },
              },
            },
          ],
          edges: [],
        },
      },
    });

    expect(wrapper.vm.nodes[0].data.action_params.availability_policy).toBe(
      'any'
    );
  });

  it('offers a dedicated node for updating an opportunity field', async () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: { modelValue: {} },
    });

    await wrapper
      .find('[data-testid="kanban-workflow-add-node"]')
      .trigger('click');

    expect(
      wrapper.vm.paletteGroups
        .flatMap(group => group.nodes)
        .map(node => node.type)
    ).toContain('set_field');
  });

  it('opens field selection directly from the dedicated update-field node', async () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: {
        customFields: [
          { key: 'origem', label: 'Origem', fieldType: 'select', options: [] },
        ],
        modelValue: {
          nodes: [
            {
              id: 'set-field',
              type: 'set_field',
              data: { action_params: { field_key: '', value: '' } },
            },
          ],
          edges: [],
        },
      },
    });

    wrapper.vm.selectNode(wrapper.vm.nodes[0]);
    await wrapper.vm.$nextTick();

    expect(wrapper.text()).toContain(
      'KANBAN.SETTINGS.AUTOMATIONS.RULES.SELECT_FIELD'
    );
  });

  it('offers selection values when a field-update action targets a select field', async () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: {
        customFields: [
          {
            key: 'origem',
            label: 'Origem',
            fieldType: 'select',
            options: ['Orgânico', 'Mídia Paga'],
          },
        ],
        modelValue: {
          nodes: [
            {
              id: 'action',
              type: 'action',
              data: {
                action_name: 'set_field',
                action_params: { field_key: 'origem', value: '' },
              },
            },
          ],
          edges: [],
        },
      },
    });

    wrapper.vm.selectNode(wrapper.vm.nodes[0]);
    await wrapper.vm.$nextTick();

    const valueSelect = wrapper.find(
      '[data-testid="kanban-workflow-action-field-value"]'
    );
    expect(valueSelect.element.tagName).toBe('SELECT');
    expect(valueSelect.text()).toContain('Mídia Paga');
  });

  it('uses a selectable stage value and a connector for each condition', async () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: {
        stages: [{ id: 9, name: 'Qualificação' }],
        conditionFields: [
          {
            key: 'system_stage_id',
            label: 'Etapa',
            conditionOptions: [],
          },
          { key: 'origem', label: 'Origem' },
          { key: 'valor', label: 'Valor' },
        ],
        modelValue: {
          nodes: [
            {
              id: 'condition',
              type: 'condition',
              data: {
                match_mode: 'all',
                conditions: [
                  { field_key: 'origem', operator: 'equals', value: '' },
                ],
              },
            },
          ],
          edges: [],
        },
      },
    });

    wrapper.vm.selectNode(wrapper.vm.nodes[0]);
    await wrapper.vm.$nextTick();

    const fieldSelect = wrapper
      .find('[data-testid="kanban-workflow-condition-row"]')
      .find('select');
    expect(fieldSelect.find('option[value="system_stage_id"]').exists()).toBe(
      true
    );

    await fieldSelect.setValue('system_stage_id');
    await wrapper.vm.$nextTick();
    expect(
      wrapper.find('[data-testid="kanban-workflow-condition-value"]').element
        .tagName
    ).toBe('SELECT');
    expect(
      wrapper.find('[data-testid="kanban-workflow-condition-value"]').text()
    ).toContain('Qualificação');

    await wrapper
      .find('[data-testid="kanban-workflow-add-condition"]')
      .trigger('click');

    expect(
      wrapper.findAll('[data-testid="kanban-workflow-condition-row"]')
    ).toHaveLength(2);
    expect(
      wrapper
        .find('[data-testid="kanban-workflow-condition-join-operator"]')
        .exists()
    ).toBe(true);
  });

  it('opens the node selector from the canvas add button', async () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: { modelValue: {} },
    });

    await wrapper
      .find('[data-testid="kanban-workflow-add-node"]')
      .trigger('click');

    expect(
      wrapper.find('[data-testid="kanban-workflow-node-menu"]').exists()
    ).toBe(true);
  });

  it('configures a filter with a single continuation path', async () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: {
        conditionFields: [{ key: 'origem', label: 'Origem' }],
        modelValue: {
          nodes: [
            {
              id: 'filter',
              type: 'filter',
              data: {
                match_mode: 'all',
                conditions: [
                  { field_key: 'origem', operator: 'equals', value: '' },
                ],
              },
            },
          ],
          edges: [],
        },
      },
    });

    wrapper.vm.selectNode(wrapper.vm.nodes[0]);
    await wrapper.vm.$nextTick();

    expect(
      wrapper.find('[data-testid="kanban-workflow-filter-match-mode"]').exists()
    ).toBe(true);
    await wrapper
      .find('[data-testid="kanban-workflow-add-filter-condition"]')
      .trigger('click');

    expect(
      wrapper.findAll('[data-testid="kanban-workflow-filter-row"]')
    ).toHaveLength(2);
    expect(
      wrapper.find('[data-testid="kanban-workflow-add-branch"]').exists()
    ).toBe(false);
  });

  it('adds independent conditional outputs with their own condition groups', async () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: {
        conditionFields: [{ key: 'origem', label: 'Origem' }],
        modelValue: {
          nodes: [
            {
              id: 'condition',
              type: 'condition',
              data: {
                branches: [
                  {
                    id: 'google',
                    label: 'Google',
                    match_mode: 'all',
                    conditions: [
                      {
                        field_key: 'origem',
                        operator: 'equals',
                        value: 'Google',
                      },
                    ],
                  },
                ],
                fallback_id: 'otherwise',
              },
            },
          ],
          edges: [],
        },
      },
    });

    wrapper.vm.selectNode(wrapper.vm.nodes[0]);
    await wrapper.vm.$nextTick();
    await wrapper
      .find('[data-testid="kanban-workflow-add-branch"]')
      .trigger('click');

    expect(
      wrapper.findAll('[data-testid="kanban-workflow-condition-branch"]')
    ).toHaveLength(2);
    expect(
      wrapper.find('[data-testid="kanban-workflow-condition-branch"]').element
        .tagName
    ).toBe('FIELDSET');
    expect(wrapper.vm.selectedNode.data.branches).toHaveLength(2);
    expect(wrapper.vm.selectedNode.data.fallback_id).toBe('otherwise');
  });

  it('reorders conditional outputs with keyboard-accessible controls', async () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: {
        modelValue: {
          nodes: [
            {
              id: 'condition',
              type: 'condition',
              data: {
                branches: [
                  { id: 'first', label: 'Primeira', conditions: [] },
                  { id: 'second', label: 'Segunda', conditions: [] },
                ],
                fallback_id: 'otherwise',
              },
            },
          ],
          edges: [],
        },
      },
    });

    wrapper.vm.selectNode(wrapper.vm.nodes[0]);
    await wrapper.vm.$nextTick();
    await wrapper
      .find('[data-testid="kanban-workflow-move-branch-down-0"]')
      .trigger('click');

    expect(
      wrapper.vm.selectedNode.data.branches.map(branch => branch.id)
    ).toEqual(['second', 'first']);
  });

  it('reorders conditional outputs from the drag handle', () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: {
        modelValue: {
          nodes: [
            {
              id: 'condition',
              type: 'condition',
              data: {
                branches: [
                  { id: 'first', label: 'Primeira', conditions: [] },
                  { id: 'second', label: 'Segunda', conditions: [] },
                ],
                fallback_id: 'otherwise',
              },
            },
          ],
          edges: [],
        },
      },
    });

    wrapper.vm.selectNode(wrapper.vm.nodes[0]);
    wrapper.vm.startConditionBranchDrag(0);
    wrapper.vm.dropConditionBranch(1);

    expect(
      wrapper.vm.selectedNode.data.branches.map(branch => branch.id)
    ).toEqual(['second', 'first']);
  });

  it('adds round-robin options and keeps each option ready for a next step', async () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: {
        modelValue: {
          nodes: [
            {
              id: 'round-robin',
              type: 'round_robin',
              data: {
                options: [
                  { id: 'first', label: 'Primeira' },
                  { id: 'second', label: 'Segunda' },
                ],
              },
            },
          ],
          edges: [],
        },
      },
    });

    wrapper.vm.selectNode(wrapper.vm.nodes[0]);
    await wrapper.vm.$nextTick();
    await wrapper
      .find('[data-testid="kanban-workflow-add-round-robin-option"]')
      .trigger('click');

    expect(wrapper.vm.selectedNode.data.options).toHaveLength(3);
    expect(wrapper.vm.selectedNode.data.options[2].label).toBe(
      'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.ROUND_ROBIN_PATH'
    );
  });

  it('renders the categorized node palette', () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder);

    expect(wrapper.findComponent(KanbanWorkflowPalette).exists()).toBe(true);
  });

  it('places a palette node at the dropped canvas position', () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder);

    wrapper.vm.addNodeOfType('send_message', { x: 320, y: 180 });

    expect(wrapper.vm.nodes.at(-1)).toEqual(
      expect.objectContaining({
        type: 'send_message',
        position: { x: 320, y: 180 },
      })
    );
  });

  it('configures official WhatsApp templates on the message node', async () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: {
        modelValue: {
          nodes: [
            {
              id: 'message',
              type: 'send_message',
              data: {
                channel: 'whatsapp',
                content: 'Olá',
                opt_in_attribute_key: 'marketing_messages_opt_in',
                frequency_limit_hours: '',
                quiet_hours: {
                  start: '',
                  end: '',
                  timezone: 'America/Sao_Paulo',
                },
                whatsapp_template_params: {},
              },
            },
          ],
          edges: [],
        },
      },
    });

    wrapper.vm.selectNode(wrapper.vm.nodes[0]);
    await wrapper.vm.$nextTick();

    expect(wrapper.text()).toContain('Template oficial do WhatsApp');
  });

  it('uses translated message policy labels in the message node', async () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: {
        modelValue: {
          nodes: [
            {
              id: 'message',
              type: 'send_message',
              data: {
                channel: 'whatsapp',
                content: 'Ola',
                opt_in_attribute_key: 'marketing_messages_opt_in',
                quiet_hours: {
                  start: '',
                  end: '',
                  timezone: 'America/Sao_Paulo',
                },
                whatsapp_template_params: {},
              },
            },
          ],
          edges: [],
        },
      },
    });

    wrapper.vm.selectNode(wrapper.vm.nodes[0]);
    await wrapper.vm.$nextTick();

    expect(wrapper.text()).toContain('Fuso do horario silencioso');
    expect(wrapper.text()).toContain('Template oficial do WhatsApp');
    expect(wrapper.text()).not.toContain(
      'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.QUIET_TIMEZONE'
    );
  });

  it('does not persist an empty quiet-hours configuration on a message node', () => {
    const wrapper = shallowMount(KanbanWorkflowBuilder, {
      props: {
        modelValue: {
          nodes: [
            {
              id: 'message',
              type: 'send_message',
              data: {
                channel: 'whatsapp',
                content: 'Olá',
                opt_in_attribute_key: 'marketing_messages_opt_in',
                quiet_hours: {
                  start: '',
                  end: '',
                  timezone: 'America/Sao_Paulo',
                },
              },
            },
          ],
          edges: [],
        },
      },
    });

    wrapper.vm.emitFlow();

    expect(
      wrapper.emitted('update:modelValue').at(-1)[0].nodes[0].data
    ).not.toHaveProperty('quiet_hours');
  });
});
