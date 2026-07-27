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
});
