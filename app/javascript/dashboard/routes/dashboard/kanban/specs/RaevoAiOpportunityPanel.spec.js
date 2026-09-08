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
      'Pre-scheduled'
    );
    expect(wrapper.text()).toContain('Aguardar confirmação do horário');
    expect(wrapper.find('input, textarea, select').exists()).toBe(false);
  });

  it('translates standard field labels instead of trusting the persisted board label', () => {
    const wrapper = mount(RaevoAiOpportunityPanel, {
      props: {
        fields: [
          {
            key: 'raevo_ai_next_action',
            label: 'Rótulo persistido em outro idioma',
          },
        ],
        values: { raevo_ai_next_action: '' },
      },
      global: {
        mocks: {
          $t: key => key,
        },
      },
    });

    expect(wrapper.text()).toContain('Next AI action');
    expect(wrapper.text()).not.toContain('Rótulo persistido em outro idioma');
  });

  it('translates semantic journey summaries and next actions at display time', () => {
    const wrapper = mount(RaevoAiOpportunityPanel, {
      props: {
        fields,
        values: {
          raevo_ai_summary: 'journey.pre_scheduling',
          raevo_ai_status: 'pre_agendado',
          raevo_ai_next_action: 'coletar_preferencia_de_agenda',
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
    ).toContain('The patient is preparing to schedule an appointment.');
    expect(wrapper.text()).toContain('Collect scheduling preference');
    expect(wrapper.text()).not.toContain('journey.pre_scheduling');
  });
});
