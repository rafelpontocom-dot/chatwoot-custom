import { onUnmounted, watch } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';

// RAEVO (08/10, 123jpnbc242) — o número de conversas por ler no ícone da guia.
//
// O título já leva o número (useUnreadTabTitle); o ícone é o que se vê com a guia
// estreita, entre muitas. O Chatwoot só troca os PNG por um com um ponto, e só com
// a guia escondida — e o layout declara também o SVG da Raevo, que o browser
// prefere: o ponto nem chegava a aparecer. Aqui todos os `rel="icon"` passam ao
// desenho com o número e voltam ao original quando o número volta a zero.
const SIZE = 64;
const MAX_VISIBLE_COUNT = 99;
const BASE_ICON = '/brand-assets/raevo-favicon.svg';

const iconLinks = () => [...document.querySelectorAll('link[rel="icon"]')];

const tokenColor = name =>
  `rgb(${getComputedStyle(document.documentElement).getPropertyValue(name).trim()})`;

export const drawUnreadFavicon = (image, count) => {
  const canvas = document.createElement('canvas');
  canvas.width = SIZE;
  canvas.height = SIZE;
  const context = canvas.getContext('2d');
  if (!context) return null;

  const label =
    count > MAX_VISIBLE_COUNT ? `${MAX_VISIBLE_COUNT}+` : `${count}`;
  context.drawImage(image, 0, 0, SIZE, SIZE);
  context.font = 'bold 30px sans-serif';
  const width = Math.max(36, context.measureText(label).width + 14);
  context.fillStyle = tokenColor('--ruby-9');
  context.beginPath();
  context.roundRect(SIZE - width, 0, width, 36, 18);
  context.fill();
  context.fillStyle = '#fff';
  context.textAlign = 'center';
  context.textBaseline = 'middle';
  context.fillText(label, SIZE - width / 2, 19);

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
  const unreadCount = useMapGetter(
    'conversationUnreadCounts/getAllUnreadCount'
  );
  const originals = new Map(
    iconLinks().map(link => [link, link.getAttribute('href')])
  );
  let baseImage = null;

  const restore = () =>
    originals.forEach((href, link) => link.setAttribute('href', href));

  const apply = async () => {
    const count = unreadCount.value;
    if (!count) {
      restore();
      return;
    }

    baseImage = baseImage || (await loadImage(BASE_ICON));
    const icon = drawUnreadFavicon(baseImage, count);
    if (icon) iconLinks().forEach(link => link.setAttribute('href', icon));
  };

  watch(unreadCount, apply, { immediate: true });
  // O alerta sonoro do Chatwoot repõe os PNG quando a guia volta a ficar visível.
  document.addEventListener('visibilitychange', apply);

  onUnmounted(() => {
    document.removeEventListener('visibilitychange', apply);
    restore();
  });
};
