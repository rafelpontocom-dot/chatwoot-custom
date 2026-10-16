import { mount } from '@vue/test-utils';
import { createStore } from 'vuex';
import ReplyBottomPanel from '../ReplyBottomPanel.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

// O painel nativo com o painel verdadeiro do Raevo dentro: se um upgrade levar a
// linha que o liga, o botão de excluir o áudio desaparece e isto falha.
const store = createStore({
  getters: {
    getCurrentAccountId: () => 1,
    'accounts/isFeatureEnabledonAccount': () => () => true,
    getUISettings: () => ({}),
    getCurrentUser: () => ({ id: 1 }),
  },
  actions: { updateUISettings: () => {} },
});

const mountPanel = props =>
  mount(ReplyBottomPanel, {
    props: {
      showAudioRecorder: true,
      isRecordingAudio: true,
      recordingAudioDurationText: '00:14',
      recordingAudioState: 'stopped',
      toggleAudioRecorder: vi.fn(),
      toggleAudioRecorderPlayPause: vi.fn(),
      inbox: { channel_type: 'Channel::Api' },
      ...props,
    },
    global: {
      plugins: [store],
      mocks: { $t: key => key },
      directives: { tooltip: {} },
      stubs: { FileUpload: true, VideoCallButton: true },
    },
  });

describe('ReplyBottomPanel — excluir o áudio gravado (123jpnbcxpg)', () => {
  it('deletes the recording only after confirming', async () => {
    const toggleAudioRecorder = vi.fn();
    const wrapper = mountPanel({ toggleAudioRecorder });

    await wrapper
      .find('[data-testid="raevo-discard-recording"]')
      .trigger('click');
    expect(toggleAudioRecorder).not.toHaveBeenCalled();

    await wrapper
      .find('[data-testid="raevo-discard-recording-confirm"]')
      .trigger('click');
    expect(toggleAudioRecorder).toHaveBeenCalledTimes(1);
  });

  it('keeps the recording when the deletion is cancelled', async () => {
    const toggleAudioRecorder = vi.fn();
    const wrapper = mountPanel({ toggleAudioRecorder });

    await wrapper
      .find('[data-testid="raevo-discard-recording"]')
      .trigger('click');
    await wrapper
      .find('[data-testid="raevo-discard-recording-cancel"]')
      .trigger('click');

    expect(toggleAudioRecorder).not.toHaveBeenCalled();
    expect(
      wrapper.find('[data-testid="raevo-discard-recording"]').exists()
    ).toBe(true);
  });

  it('has nothing to delete when nothing was recorded', () => {
    const wrapper = mountPanel({ isRecordingAudio: false });

    expect(
      wrapper.find('[data-testid="raevo-discard-recording"]').exists()
    ).toBe(false);
  });
});
