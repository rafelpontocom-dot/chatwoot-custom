import { shallowMount } from '@vue/test-utils';

import KanbanWorkflowTriggerInspector from '../components/KanbanWorkflowTriggerInspector.vue';

const t = key => key;

describe('KanbanWorkflowTriggerInspector', () => {
  it('shows compatible stage choices when the trigger is stage based', async () => {
    const wrapper = shallowMount(KanbanWorkflowTriggerInspector, {
      props: {
        triggerValue: 'kanban.card.stage_changed',
        triggerOptions: [
          {
            value: 'kanban.card.stage_changed',
            label: 'Etapa alterada',
          },
        ],
        triggerContext: 'stage',
        config: {
          stageId: '',
          triggerEventNames: ['kanban.card.stage_changed'],
        },
        stages: [{ id: 9, name: 'Agendado' }],
        t,
      },
    });

    expect(
      wrapper.find('[data-testid="kanban-workflow-trigger-stage"]').text()
    ).toContain('Agendado');

    await wrapper
      .find('[data-testid="kanban-workflow-trigger-stage"]')
      .setValue('9');

    expect(wrapper.emitted('update:config')).toEqual([[{ stageId: '9' }]]);
  });

  it('offers configured options after selecting a choice field trigger', async () => {
    const wrapper = shallowMount(KanbanWorkflowTriggerInspector, {
      props: {
        triggerValue: 'kanban.card.fields_changed',
        triggerOptions: [
          { value: 'kanban.card.fields_changed', label: 'Campo alterado' },
        ],
        triggerContext: 'changed_field',
        config: { changedFieldKey: 'origem', changedFieldValue: '' },
        fields: [
          {
            key: 'origem',
            label: 'Origem',
            conditionOptions: [
              { value: 'organico', label: 'Orgânico' },
              { value: 'meta', label: 'Mídia Paga: Meta' },
            ],
          },
        ],
        t,
      },
    });

    const valueSelect = wrapper.find(
      '[data-testid="kanban-workflow-trigger-field-value"]'
    );

    expect(valueSelect.exists()).toBe(true);
    expect(valueSelect.text()).toContain('Mídia Paga: Meta');

    await valueSelect.setValue('meta');

    expect(wrapper.emitted('update:config')).toContainEqual([
      { changedFieldValue: 'meta' },
    ]);
  });

  it('only offers approved active connections for an inbound webhook trigger', () => {
    const wrapper = shallowMount(KanbanWorkflowTriggerInspector, {
      props: {
        triggerValue: 'kanban.webhook.received',
        triggerOptions: [
          { value: 'kanban.webhook.received', label: 'Webhook recebido' },
        ],
        triggerContext: 'webhook',
        connections: [
          { id: 7, name: 'n8n aprovado', active: true },
          { id: 8, name: 'Integração desativada', active: false },
        ],
        t,
      },
    });

    expect(wrapper.text()).toContain('n8n aprovado');
    expect(wrapper.text()).not.toContain('Integração desativada');
  });
});
