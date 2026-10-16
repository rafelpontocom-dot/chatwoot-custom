import { mount } from '@vue/test-utils';
import { nextTick, ref } from 'vue';
import RaevoConversationPanelToggles from '../RaevoConversationPanelToggles.vue';
import { useRaevoContactPanelAutoOpen } from '../useRaevoContactPanel';

const uiSettings = ref({});
const updateUISettings = vi.fn(changes => {
  uiSettings.value = { ...uiSettings.value, ...changes };
});
const larguraDaJanela = ref(1280);
const captainAtivo = ref(false);
let atalhos = {};

vi.mock('dashboard/composables/useUISettings', () => ({
  useUISettings: () => ({ uiSettings, updateUISettings }),
}));
vi.mock('@vueuse/core', async () => ({
  ...(await vi.importActual('@vueuse/core')),
  useWindowSize: () => ({ width: larguraDaJanela }),
}));
const utilizadorCarregado = ref(7);
vi.mock('dashboard/composables/store', () => ({
  useMapGetter: name => {
    if (name === 'getCurrentUserID') return utilizadorCarregado;
    if (name === 'getCurrentAccountId') return ref(1);
    return ref(() => captainAtivo.value);
  },
}));
vi.mock('dashboard/composables/useKeyboardEvents', () => ({
  useKeyboardEvents: events => {
    atalhos = events;
  },
}));
vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));

const mountToggles = () =>
  mount(RaevoConversationPanelToggles, {
    global: { directives: { tooltip: {} } },
  });

describe('RaevoConversationPanelToggles (123jpnbd3by)', () => {
  beforeEach(() => {
    uiSettings.value = {};
    updateUISettings.mockClear();
    larguraDaJanela.value = 1280;
    captainAtivo.value = false;
  });

  it('opens the contact panel and closes the copilot', async () => {
    const wrapper = mountToggles();
    const botao = wrapper.find('[data-testid="raevo-contact-panel-toggle"]');

    expect(botao.attributes('aria-expanded')).toBe('false');
    expect(botao.attributes('aria-label')).toBe(
      'RAEVO_CONVERSATION.CONTACT_PANEL.SHOW'
    );
    expect(botao.html()).toContain('i-lucide-arrow-left-to-line');

    await botao.trigger('click');

    expect(updateUISettings).toHaveBeenCalledWith({
      is_contact_sidebar_open: true,
      is_copilot_panel_open: false,
    });
    expect(botao.attributes('aria-expanded')).toBe('true');
    expect(botao.attributes('aria-label')).toBe(
      'RAEVO_CONVERSATION.CONTACT_PANEL.HIDE'
    );
    expect(botao.html()).toContain('i-lucide-arrow-right-to-line');
  });

  it('keeps the Alt+O shortcut of the floating switch it replaces', () => {
    mountToggles();
    atalhos['Alt+KeyO'].action();

    expect(updateUISettings).toHaveBeenCalledWith(
      expect.objectContaining({ is_contact_sidebar_open: true })
    );
  });

  it('shows the copilot next to it only when the account has Captain', async () => {
    const wrapper = mountToggles();
    expect(
      wrapper.find('[data-testid="raevo-copilot-panel-toggle"]').exists()
    ).toBe(false);

    captainAtivo.value = true;
    await nextTick();
    await wrapper
      .find('[data-testid="raevo-copilot-panel-toggle"]')
      .trigger('click');

    expect(updateUISettings).toHaveBeenCalledWith({
      is_contact_sidebar_open: false,
      is_copilot_panel_open: true,
    });
  });
});

describe('useRaevoContactPanelAutoOpen (decisão de 16/10)', () => {
  const comConversa = id => {
    const conversa = ref(id);
    mount({
      setup() {
        useRaevoContactPanelAutoOpen(conversa);
        return () => null;
      },
    });
    return conversa;
  };

  beforeEach(() => {
    uiSettings.value = {};
    updateUISettings.mockClear();
    larguraDaJanela.value = 1280;
    utilizadorCarregado.value = 7;
  });

  it('opens the contact panel when a conversation opens', () => {
    comConversa(55);

    expect(updateUISettings).toHaveBeenCalledWith({
      is_contact_sidebar_open: true,
      is_copilot_panel_open: false,
    });
  });

  it('opens it again on the next conversation after it was closed by hand', async () => {
    const conversa = comConversa(55);
    uiSettings.value = { is_contact_sidebar_open: false };
    updateUISettings.mockClear();

    conversa.value = 56;
    await nextTick();

    expect(updateUISettings).toHaveBeenCalledWith(
      expect.objectContaining({ is_contact_sidebar_open: true })
    );
  });

  it('does not write anything when the panel is already open', () => {
    uiSettings.value = { is_contact_sidebar_open: true };
    comConversa(55);

    expect(updateUISettings).not.toHaveBeenCalled();
  });

  it('leaves the panel closed on a phone, where it would cover the conversation', () => {
    larguraDaJanela.value = 400;
    comConversa(55);

    expect(updateUISettings).not.toHaveBeenCalled();
  });

  // A corrida que a jornada no browser apanhou: abrir antes de o perfil chegar
  // deixava o servidor gravar «fechado» por cima.
  it('waits for the user to load before opening the panel', async () => {
    utilizadorCarregado.value = null;
    comConversa(55);
    expect(updateUISettings).not.toHaveBeenCalled();

    utilizadorCarregado.value = 7;
    await nextTick();

    expect(updateUISettings).toHaveBeenCalledWith(
      expect.objectContaining({ is_contact_sidebar_open: true })
    );
  });

  it('does nothing without a conversation', () => {
    comConversa(0);

    expect(updateUISettings).not.toHaveBeenCalled();
  });
});
