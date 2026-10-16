import { mount } from '@vue/test-utils';
import { nextTick } from 'vue';
import Modal from '../Modal.vue';

// O Modal é nativo do Chatwoot; o Raevo deu-lhe comportamento de diálogo:
// o foco entra, não foge com o Tab e volta a quem o abriu.

const mountModal = () =>
  mount(Modal, {
    attachTo: document.body,
    props: { show: false },
    slots: { default: '<input data-testid="campo" />' },
    global: { stubs: { Button: true } },
  });

const tab = () => {
  const event = new KeyboardEvent('keydown', {
    key: 'Tab',
    bubbles: true,
    cancelable: true,
  });
  document.activeElement.dispatchEvent(event);
  return event;
};

describe('Modal as a dialog', () => {
  let opener;
  let wrapper;

  beforeEach(() => {
    opener = document.createElement('button');
    document.body.appendChild(opener);
    opener.focus();
  });

  afterEach(() => {
    wrapper?.unmount();
    opener.remove();
  });

  it('moves the focus into the first field when it opens', async () => {
    wrapper = mountModal();
    await wrapper.setProps({ show: true });
    await nextTick();

    expect(document.activeElement).toBe(
      wrapper.find('[data-testid="campo"]').element
    );
  });

  it('keeps Tab inside the dialog', async () => {
    wrapper = mountModal();
    await wrapper.setProps({ show: true });
    await nextTick();

    expect(tab().defaultPrevented).toBe(true);
    expect(wrapper.element.contains(document.activeElement)).toBe(true);
  });

  it('gives the focus back to whoever opened it on Escape', async () => {
    wrapper = mountModal();
    await wrapper.setProps({ show: true });
    await nextTick();

    wrapper.find('[data-testid="campo"]').element.focus();
    document.dispatchEvent(new KeyboardEvent('keydown', { code: 'Escape' }));
    await nextTick();
    await nextTick();

    expect(document.activeElement).toBe(opener);
  });
});
