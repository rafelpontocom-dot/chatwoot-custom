import { mount } from '@vue/test-utils';
import EditorModeToggle from '../EditorModeToggle.vue';
import { REPLY_EDITOR_MODES } from '../constants';

const mountToggle = (props = {}) =>
  mount(EditorModeToggle, {
    props: { mode: REPLY_EDITOR_MODES.REPLY, ...props },
    global: { mocks: { $t: key => key } },
  });

describe('EditorModeToggle', () => {
  // «Mensagem Privada» parecia mensagem privada para o cliente. É interna: só a
  // equipa a vê, e o nome tem de dizer isso.
  it('names the internal mode as internal, not private', () => {
    const wrapper = mountToggle();

    expect(wrapper.text()).toContain('CONVERSATION.REPLYBOX.INTERNAL_NOTE');
    expect(wrapper.text()).not.toContain('PRIVATE_NOTE');
  });

  it('marks the internal mode with a lock, and not only with colour', () => {
    const wrapper = mountToggle({ mode: REPLY_EDITOR_MODES.NOTE });
    const interno = wrapper.find('[data-testid="editor-mode-internal"]');

    expect(interno.find('.i-lucide-lock').exists()).toBe(true);
    expect(wrapper.attributes('aria-label')).toBe(
      'CONVERSATION.REPLYBOX.MODE_INTERNAL_ACTIVE'
    );
  });

  it('says which mode is on for whoever reads the screen', () => {
    const wrapper = mountToggle();

    expect(wrapper.attributes('aria-label')).toBe(
      'CONVERSATION.REPLYBOX.MODE_REPLY_ACTIVE'
    );
  });
});
