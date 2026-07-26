import { shallowMount } from '@vue/test-utils';

import KanbanWorkflowInspector from '../components/KanbanWorkflowInspector.vue';
import KanbanWorkflowInspectorHeader from '../components/KanbanWorkflowInspectorHeader.vue';

describe('KanbanWorkflowInspector', () => {
  it('uses a compact floating sheet on desktop instead of a full-height drawer', () => {
    const wrapper = shallowMount(KanbanWorkflowInspector, {
      props: {
        nodeSelected: true,
        ariaLabelledby: 'workflow-node-title',
      },
    });

    const inspector = wrapper.find(
      '[data-testid="kanban-workflow-node-drawer"]'
    );

    expect(inspector.classes()).toContain('sm:top-[4.5rem]');
    expect(inspector.classes()).toContain('sm:bottom-auto');
    expect(inspector.classes()).toContain('sm:w-[min(16rem,calc(100vw-2rem))]');
  });

  it('keeps the selected node category visible in the contextual header', () => {
    const wrapper = shallowMount(KanbanWorkflowInspectorHeader, {
      props: {
        node: {
          type: 'condition',
          data: {
            icon: 'i-lucide-git-branch',
            categoryLabel: 'Decisao',
            label: 'Condicao',
            stateLabel: 'Pronto',
          },
        },
        summary: 'Verifica o perfil da oportunidade.',
        stateTone: 'bg-n-green-3 text-n-green-11',
        surfaceClass: 'bg-n-violet-3 text-n-violet-11',
        emptySummary: 'Sem resumo',
        connectLabel: 'Conectar',
        closeLabel: 'Fechar',
        deleteLabel: 'Excluir',
      },
    });

    expect(
      wrapper
        .find('[data-testid="kanban-workflow-inspector-icon-surface"]')
        .classes()
    ).toContain('text-n-violet-11');
  });
});
