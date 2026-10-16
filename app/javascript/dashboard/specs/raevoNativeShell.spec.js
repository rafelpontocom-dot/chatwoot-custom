import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import types from 'dashboard/store/mutation-types';
import { initializeAudioAlerts } from 'dashboard/helper/scriptHelpers';
import DashboardAudioNotificationHelper from 'dashboard/helper/AudioAlerts/DashboardAudioNotificationHelper';
import { DEFAULT_AUDIO_ALERT_EVENTS } from 'dashboard/routes/dashboard/settings/profile/constants';
import V3App from 'v3/App.vue';
import Login from 'v3/views/login/Index.vue';

// Ficheiros nativos do Chatwoot que o Raevo alterou em poucas linhas. Um
// upgrade reescreve-os sem conflito; estes testes falham se a linha do Raevo
// se perder pelo caminho.

const source = path => readFileSync(resolve(process.cwd(), path), 'utf8');

describe('Raevo inside the native dashboard shell', () => {
  it('declares the Raevo AI feature flag', () => {
    expect(FEATURE_FLAGS.RAEVO_AI).toBe('raevo_ai');
  });

  it('registers the kanban boards store module and its mutations', async () => {
    const { default: store } = await import('dashboard/store');

    expect(store.hasModule('kanbanBoards')).toBe(true);
    expect(types.SET_KANBAN_BOARDS).toBe('SET_KANBAN_BOARDS');
    expect(types.SET_KANBAN_BOARDS_UI_FLAG).toBe('SET_KANBAN_BOARDS_UI_FLAG');
  });

  // No Chatwoot quem nunca escolheu não ouve nada; no Raevo ouve as suas
  // conversas e as que ainda não são de ninguém.
  it('plays audio alerts by default for a user who never chose', () => {
    const set = vi
      .spyOn(DashboardAudioNotificationHelper, 'set')
      .mockImplementation(() => {});

    initializeAudioAlerts({ ui_settings: {} });

    expect(set).toHaveBeenCalledWith(
      expect.objectContaining({ audioAlertType: DEFAULT_AUDIO_ALERT_EVENTS })
    );
    set.mockRestore();
  });

  it('lets the installation hide the update banner', async () => {
    window.globalConfig = { DISPLAY_UPDATE_BANNER: 'true' };
    vi.resetModules();
    const {
      default: { state: shown },
    } = await import('shared/store/globalConfig');
    window.globalConfig = {};
    vi.resetModules();
    const {
      default: { state: unset },
    } = await import('shared/store/globalConfig');
    delete window.globalConfig;

    expect(shown.displayUpdateBanner).toBe(true);
    expect(unset.displayUpdateBanner).toBe(false);
  });

  // Os tokens do Raevo têm de entrar DEPOIS de next-colors para vencerem na
  // cascata. Sem estes imports o produto inteiro volta à paleta do Chatwoot.
  it('loads the Raevo identity after the native colours', () => {
    const woot = source('app/javascript/dashboard/assets/scss/_woot.scss');
    const nextColors = woot.indexOf('next-colors');
    const tokens = woot.indexOf("@import 'raevo-tokens'");

    expect(nextColors).toBeGreaterThan(-1);
    expect(tokens).toBeGreaterThan(nextColors);
    expect(woot).toContain("@import 'raevo-fonts'");
    expect(woot).toContain("@import 'raevo-components'");
  });
});

describe('Raevo on the login screen (v3 app)', () => {
  it('starts the i18n of the login app in Brazilian Portuguese', () => {
    expect(source('app/javascript/entrypoints/v3app.js')).toContain(
      "locale: 'pt_BR'"
    );
  });

  it('sets the login app locale to Brazilian Portuguese on mount', () => {
    const ctx = {
      setColorTheme: vi.fn(),
      listenToThemeChanges: vi.fn(),
      setLocale: vi.fn(),
    };

    V3App.mounted.call(ctx);

    expect(ctx.setLocale).toHaveBeenCalledWith('pt_BR');
  });

  it('renders the login app with the Raevo tokens and font', () => {
    const app = source('app/javascript/v3/App.vue');

    expect(app).toContain("@import '../dashboard/assets/scss/raevo-tokens'");
    expect(app).toContain('font-family: var(--raevo-font-sans)');
  });

  it('shows the Raevo logo on the login screen', () => {
    expect(Login.data.call({}).raevoLoginLogo).toBe(
      '/brand-assets/raevo-logo-areia.svg'
    );
  });
});
