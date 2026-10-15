import { nextTick, ref } from 'vue';
import { mount, flushPromises } from '@vue/test-utils';
import { useUnreadFavicon } from '../useUnreadFavicon';

const mineUnread = ref(0);
const getters = [];
vi.mock('dashboard/composables/store', () => ({
  useMapGetter: key => {
    getters.push(key);
    return mineUnread;
  },
}));

// jsdom não desenha: o canvas devolve um contexto falso e o PNG é um marcador.
const drawn = { dots: 0, labels: [] };
HTMLCanvasElement.prototype.getContext = () => ({
  drawImage: () => {},
  beginPath: () => {},
  arc: () => {
    drawn.dots += 1;
  },
  fill: () => {},
  fillText: label => drawn.labels.push(label),
});
HTMLCanvasElement.prototype.toDataURL = () => 'data:image/png;base64,PONTO';
global.Image = class {
  set src(_) {
    setTimeout(() => this.onload());
  }
};

const icons = () =>
  [...document.querySelectorAll('link[rel="icon"]')].map(link =>
    link.getAttribute('href')
  );

const settle = async () => {
  await nextTick();
  await vi.runAllTimersAsync();
  await flushPromises();
};

describe('useUnreadFavicon', () => {
  beforeEach(() => {
    vi.useFakeTimers();
    document.head.innerHTML = `
      <link class="favicon" rel="icon" sizes="32x32" href="/favicon-32x32.png">
      <link rel="icon" type="image/svg+xml" href="/brand-assets/raevo-favicon.svg">`;
    mineUnread.value = 0;
    drawn.dots = 0;
    drawn.labels.length = 0;
    getters.length = 0;
  });

  let wrapper;
  afterEach(() => {
    wrapper?.unmount();
    vi.useRealTimers();
  });

  const mountFavicon = () => {
    wrapper = mount({ setup: () => useUnreadFavicon(), template: '<i />' });
  };

  // 123jpnbcxh5: o ponto acende pelo que é de quem está ligado, não por tudo.
  it('reads only the unread conversations assigned to the current agent', () => {
    mountFavicon();

    expect(getters).toEqual(['conversationUnreadCounts/getMineUnreadCount']);
  });

  it('draws a dot, and no number, on every tab icon, the Raevo SVG included', async () => {
    mountFavicon();
    mineUnread.value = 140;
    await settle();

    expect(icons()).toEqual([
      'data:image/png;base64,PONTO',
      'data:image/png;base64,PONTO',
    ]);
    expect(drawn.dots).toBe(1);
    expect(drawn.labels).toEqual([]);
  });

  it('puts the original icons back when nothing is left to read', async () => {
    mountFavicon();
    mineUnread.value = 2;
    await settle();
    mineUnread.value = 0;
    await settle();

    expect(icons()).toEqual([
      '/favicon-32x32.png',
      '/brand-assets/raevo-favicon.svg',
    ]);
  });
});
