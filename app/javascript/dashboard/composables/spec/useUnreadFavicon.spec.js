import { nextTick, ref } from 'vue';
import { mount, flushPromises } from '@vue/test-utils';
import { useUnreadFavicon } from '../useUnreadFavicon';

const unread = ref(0);
vi.mock('dashboard/composables/store', () => ({
  useMapGetter: () => unread,
}));

// jsdom não desenha: o canvas devolve um contexto falso e o PNG é um marcador.
const drawn = [];
HTMLCanvasElement.prototype.getContext = () => ({
  drawImage: () => {},
  measureText: () => ({ width: 10 }),
  beginPath: () => {},
  roundRect: () => {},
  fill: () => {},
  fillText: label => drawn.push(label),
});
HTMLCanvasElement.prototype.toDataURL = () =>
  'data:image/png;base64,COM-NUMERO';
global.Image = class {
  set src(_) {
    setTimeout(() => this.onload());
  }
};

const icons = () =>
  [...document.querySelectorAll('link[rel="icon"]')].map(link =>
    link.getAttribute('href')
  );

describe('useUnreadFavicon', () => {
  beforeEach(() => {
    vi.useFakeTimers();
    document.head.innerHTML = `
      <link class="favicon" rel="icon" sizes="32x32" href="/favicon-32x32.png">
      <link rel="icon" type="image/svg+xml" href="/brand-assets/raevo-favicon.svg">`;
    unread.value = 0;
    drawn.length = 0;
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  const mountFavicon = () =>
    mount({ setup: () => useUnreadFavicon(), template: '<i />' });

  it('draws the count on every tab icon, the Raevo SVG included', async () => {
    mountFavicon();
    unread.value = 3;
    await nextTick();
    await flushPromises();
    await vi.runAllTimersAsync();
    await flushPromises();

    expect(icons()).toEqual([
      'data:image/png;base64,COM-NUMERO',
      'data:image/png;base64,COM-NUMERO',
    ]);
    expect(drawn.at(-1)).toBe('3');
  });

  it('caps the label at 99+', async () => {
    mountFavicon();
    unread.value = 140;
    await nextTick();
    await vi.runAllTimersAsync();
    await flushPromises();

    expect(drawn.at(-1)).toBe('99+');
  });

  it('puts the original icons back when nothing is left to read', async () => {
    mountFavicon();
    unread.value = 2;
    await nextTick();
    await vi.runAllTimersAsync();
    await flushPromises();
    unread.value = 0;
    await nextTick();
    await flushPromises();

    expect(icons()).toEqual([
      '/favicon-32x32.png',
      '/brand-assets/raevo-favicon.svg',
    ]);
  });
});
