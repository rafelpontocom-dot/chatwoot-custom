import { mount } from '@vue/test-utils';
import KanbanWorkflowMessageInspector from '../components/KanbanWorkflowMessageInspector.vue';

const t = key => key;

describe('KanbanWorkflowMessageInspector', () => {
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
