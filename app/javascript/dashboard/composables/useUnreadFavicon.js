import { onUnmounted, watch } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';

// RAEVO — um ponto vermelho no ícone da guia quando há conversas por ler
// atribuídas a quem está ligado (123jpnbcxh5).
//
// Começou como o número de todas as por ler (08/10). O Thiago pediu o ponto, como
// o do ClickUp: o número poluía e contava conversas que não eram dele. O título
// deixou de levar o número pela mesma razão.
//
// O Chatwoot só troca os PNG por um com um ponto, e só com a guia escondida — e o
// layout declara também o SVG da Raevo, que o browser prefere: o ponto nem
// chegava a aparecer. Aqui todos os `rel="icon"` passam ao desenho com o ponto e
// voltam ao original quando já não há nada por ler.
const SIZE = 64;
const DOT_RADIUS = 14;
// PNG e não SVG: o desenho do ponto passa por `canvas.drawImage`, e um PNG com
// tamanho declarado é previsível ali — um SVG sem largura intrínseca desenha
// torto em alguns browsers.
const BASE_ICON = '/brand-assets/raevo-favicon-512.png';

const iconLinks = () => [...document.querySelectorAll('link[rel="icon"]')];

const tokenColor = name =>
  `rgb(${getComputedStyle(document.documentElement).getPropertyValue(name).trim()})`;

export const drawUnreadFavicon = image => {
  const canvas = document.createElement('canvas');
  canvas.width = SIZE;
  canvas.height = SIZE;
  const context = canvas.getContext('2d');
  if (!context) return null;

  context.drawImage(image, 0, 0, SIZE, SIZE);
  context.fillStyle = tokenColor('--ruby-9');
  context.beginPath();
  context.arc(SIZE - DOT_RADIUS, DOT_RADIUS, DOT_RADIUS, 0, 2 * Math.PI);
  context.fill();

  return canvas.toDataURL('image/png');
};

const loadImage = src =>
  new Promise((resolve, reject) => {
    const image = new Image();
    image.onload = () => resolve(image);
    image.onerror = reject;
    image.src = src;
  });

export const useUnreadFavicon = () => {
  const mineUnread = useMapGetter(
    'conversationUnreadCounts/getMineUnreadCount'
  );
  const originals = new Map(
    iconLinks().map(link => [link, link.getAttribute('href')])
  );
  let baseImage = null;

  const restore = () =>
    originals.forEach((href, link) => link.setAttribute('href', href));

  const apply = async () => {
    if (!mineUnread.value) {
      restore();
      return;
    }

    baseImage = baseImage || (await loadImage(BASE_ICON));
    const icon = drawUnreadFavicon(baseImage);
    if (icon) iconLinks().forEach(link => link.setAttribute('href', icon));
  };

  watch(mineUnread, apply, { immediate: true });
  // O alerta sonoro do Chatwoot repõe os PNG quando a guia volta a ficar visível.
  document.addEventListener('visibilitychange', apply);

  onUnmounted(() => {
    document.removeEventListener('visibilitychange', apply);
    restore();
  });
};
