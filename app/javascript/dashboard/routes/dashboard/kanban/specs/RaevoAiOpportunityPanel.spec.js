import { mount } from '@vue/test-utils';
import RaevoAiOpportunityPanel from '../RaevoAiOpportunityPanel.vue';

const fields = [
  { key: 'raevo_ai_summary', label: 'Resumo do atendimento' },
  { key: 'raevo_ai_status', label: 'Status do atendimento' },
  { key: 'raevo_ai_next_action', label: 'Próxima ação da IA' },
  { key: 'raevo_ai_last_action_at', label: 'Última ação da IA' },
];

describe('RaevoAiOpportunityPanel', () => {
  it('renders a read-only operational summary and status from the standard AI fields', () => {
    const wrapper = mount(RaevoAiOpportunityPanel, {
      props: {
        fields,
        values: {
          raevo_ai_summary:
            'Paciente busca psicoterapia e prefere o período da tarde.',
          raevo_ai_status: 'pre_agendado',
          raevo_ai_next_action: 'Aguardar confirmação do horário',
          raevo_ai_last_action_at: '2026-09-05T13:30:00Z',
        },
      },
      global: {
        stubs: {
          RaevoStamp: {
            props: ['label'],
            template: '<span data-testid="ai-status">{{ label }}</span>',
          },
        },
      },
    });

    expect(
      wrapper.get('[data-testid="raevo-ai-opportunity-summary"]').text()
    ).toContain('Paciente busca psicoterapia');
    expect(wrapper.get('[data-testid="ai-status"]').text()).toBe(
      'Pre agendado'
    );
    expect(wrapper.text()).toContain('Aguardar confirmação do horário');
    expect(wrapper.find('input, textarea, select').exists()).toBe(false);
  });
});
