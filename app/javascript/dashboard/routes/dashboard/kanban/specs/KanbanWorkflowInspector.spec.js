import { shallowMount } from '@vue/test-utils';

import KanbanWorkflowInspector from '../components/KanbanWorkflowInspector.vue';
import KanbanWorkflowInspectorHeader from '../components/KanbanWorkflowInspectorHeader.vue';

describe('KanbanWorkflowInspector', () => {
  it('docks the panel to the canvas edge instead of covering it', () => {
    const wrapper = shallowMount(KanbanWorkflowInspector, {
      props: {
        nodeSelected: true,
        ariaLabelledby: 'workflow-node-title',
      },
    });

    const inspector = wrapper.find(
      '[data-testid="kanban-workflow-node-drawer"]'
    );

    // Encostado à direita, 320px, sem centrar nem cobrir a tela.
    expect(inspector.classes()).toContain('sm:right-4');
    expect(inspector.classes()).toContain('sm:left-auto');
    expect(inspector.classes()).toContain('sm:w-80');
    expect(inspector.classes()).not.toContain('sm:-translate-x-1/2');

    // Sem véu no desktop: a tela continua visível e clicável por trás.
    expect(
      wrapper
        .find('[data-testid="kanban-workflow-inspector-backdrop"]')
        .exists()
    ).toBe(false);
    expect(inspector.attributes('aria-modal')).toBe('false');
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
        stateTone: 'bg-n-teal-3 text-n-teal-11',
        surfaceClass: 'bg-n-alpha-1 text-n-slate-11',
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
    ).toContain('text-n-slate-11');
  });
});
