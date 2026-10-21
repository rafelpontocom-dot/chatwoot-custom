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

  // Um default invisível é pior do que nenhum: o campo fica em branco, há um
  // valor a actuar por trás, e quem abre o nó não tem como saber.
  describe('what the node inherits from the automation', () => {
    const montar = ({ nodeData = {}, messageDefaults = {} } = {}) =>
      mount(KanbanWorkflowMessageInspector, {
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
              ...nodeData,
            },
          },
          t: (key, params) =>
            params ? `${key}:${JSON.stringify(params)}` : key,
          messageDefaults,
          variables: [],
          timezones: [],
        },
      });

    const aviso = wrapper =>
      wrapper.find('[data-testid="kanban-workflow-message-inherited"]');

    it('says nothing when the automation answered nothing', () => {
      expect(aviso(montar()).exists()).toBe(false);
    });

    it('names each rule it is inheriting', () => {
      const wrapper = montar({
        messageDefaults: {
          quiet_hours: { start: '21:00', end: '08:00' },
          frequency_limit_hours: 24,
          opt_in_attribute_key: 'aceita_whatsapp',
        },
      });

      const texto = aviso(wrapper).text();

      expect(texto).toContain('21:00');
      expect(texto).toContain('08:00');
      expect(texto).toContain('24');
      expect(texto).toContain('aceita_whatsapp');
    });

    // O que o nó preenche não é herdado, e não pode aparecer como se fosse.
    it('leaves out what the node answers for itself', () => {
      const wrapper = montar({
        nodeData: { frequency_limit_hours: 2 },
        messageDefaults: {
          frequency_limit_hours: 24,
          opt_in_attribute_key: 'aceita_whatsapp',
        },
      });

      const texto = aviso(wrapper).text();

      expect(texto).toContain('aceita_whatsapp');
      expect(texto).not.toContain('24');
    });

    it('stops showing the quiet hours once the node sets its own', () => {
      const wrapper = montar({
        nodeData: { quiet_hours: { start: '22:00' } },
        messageDefaults: { quiet_hours: { start: '21:00', end: '08:00' } },
      });

      expect(aviso(wrapper).exists()).toBe(false);
    });
  });

  // Num painel de largura fixa, um breakpoint de ECRÃ é sempre a medida errada:
  // `sm:grid-cols-2` punha dois selects lado a lado dentro de 320px, ~140px
  // cada, em qualquer monitor. Quem manda passa a ser o painel.
  describe('two columns follow the panel, not the window', () => {
    const montar = wide =>
      mount(KanbanWorkflowMessageInspector, {
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
          wide,
          variables: [],
          timezones: [],
        },
      });

    it('stays one column while the panel is narrow', () => {
      const classes = montar(false).find('section').classes();

      expect(classes).not.toContain('grid-cols-2');
    });

    it('never uses a screen breakpoint for the panel layout', () => {
      const html = montar(false).html();

      expect(html).not.toContain('sm:grid-cols-2');
    });

    it('goes to two columns when the panel is widened', () => {
      const classes = montar(true).find('section').classes();

      expect(classes).toContain('grid-cols-2');
    });
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

  it('lists the board inboxes and persists the selected inbox id', async () => {
    const wrapper = mount(KanbanWorkflowMessageInspector, {
      props: {
        node: {
          data: {
            channel: 'whatsapp',
            inbox_id: 3,
            content: 'Olá',
            opt_in_attribute_key: 'marketing_messages_opt_in',
            failure_mode: 'stop',
            message_attachment: {},
            whatsapp_template_params: {},
            quiet_hours: {},
          },
        },
        t,
        variables: [],
        timezones: [],
        inboxes: [{ id: 3, name: 'WhatsApp Business' }],
      },
    });

    expect(
      wrapper.get('[data-testid="kanban-workflow-message-inbox"]').element.value
    ).toBe('3');
    expect(wrapper.text()).toContain('WhatsApp Business');

    await wrapper
      .get('[data-testid="kanban-workflow-message-inbox"]')
      .setValue('');

    expect(wrapper.emitted('update')).toHaveLength(1);
  });

  it('does not show the legacy channel selector when an inbox routes the message', () => {
    const wrapper = mount(KanbanWorkflowMessageInspector, {
      props: {
        node: {
          data: {
            channel: 'whatsapp',
            inbox_id: 3,
            content: 'Olá',
            opt_in_attribute_key: '',
            failure_mode: 'stop',
            message_attachment: {},
            whatsapp_template_params: {},
            quiet_hours: {},
          },
        },
        t,
        variables: [],
        timezones: [],
        inboxes: [{ id: 3, name: 'WhatsApp Business' }],
      },
    });

    expect(
      wrapper
        .findAll('select')
        .some(select =>
          select
            .text()
            .includes('KANBAN.SETTINGS.AUTOMATIONS.BIRTHDAY.WHATSAPP')
        )
    ).toBe(false);
  });
});
