import { mount } from '@vue/test-utils';
import enKanbanMessages from 'dashboard/i18n/locale/en/kanban.json';
import ptBRKanbanMessages from 'dashboard/i18n/locale/pt_BR/kanban.json';
import KanbanWorkflowMessageInspector from '../components/KanbanWorkflowMessageInspector.vue';

const t = key => key;

describe('KanbanWorkflowMessageInspector', () => {
  it('has a translated advanced-options label for workflow message settings', () => {
    expect(enKanbanMessages.KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.ADVANCED).toBe(
      'Advanced options'
    );
    expect(
      ptBRKanbanMessages.KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.ADVANCED
    ).toBe('Opções avançadas');
  });

  it('keeps the message preview next to the essential composer controls', () => {
    const wrapper = mount(KanbanWorkflowMessageInspector, {
      props: {
        node: {
          data: {
            channel: 'whatsapp',
            content: 'Olá',
            opt_in_attribute_key: '',
            failure_mode: 'stop',
            message_attachment: {},
            whatsapp_template_params: {},
            quiet_hours: {},
          },
        },
        t,
        messagePreview: 'Olá',
        variables: [],
        timezones: [],
      },
    });

    expect(
      wrapper.find('[data-testid="kanban-message-preview"]').exists()
    ).toBe(true);
    expect(
      wrapper.find('[data-testid="kanban-message-emoji-button"]').exists()
    ).toBe(true);
  });
});
