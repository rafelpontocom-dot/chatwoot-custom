// Pedidos da página pública. Toda a resposta de erro traz `message` e, quando a
// página precisa de reagir (vaga tomada, reserva expirada), `code`.
export class BookingRequestError extends Error {
  constructor(message, { code, status } = {}) {
    super(message);
    this.code = code;
    this.status = status;
  }
}

const csrfToken = () =>
  document.querySelector('meta[name="csrf-token"]')?.getAttribute('content');

export const request = async (url, { method = 'GET', body } = {}) => {
  const headers = { Accept: 'application/json' };
  if (body) headers['Content-Type'] = 'application/json';
  const token = csrfToken();
  if (token && method !== 'GET') headers['X-CSRF-Token'] = token;

  const response = await fetch(url, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new BookingRequestError(payload.message || '', {
      code: payload.code,
      status: response.status,
    });
  }
  return payload;
};

const pad = number => String(number).padStart(2, '0');

export const isoDate = date =>
  `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;

export const monthKey = date =>
  `${date.getFullYear()}-${pad(date.getMonth() + 1)}`;

// «Recife (GMT−3)»
export const timezoneLabel = (timezone, locale) => {
  const city = (timezone.split('/').pop() || timezone).replace(/_/g, ' ');
  const names = {
    'Sao Paulo': 'São Paulo',
    Belem: 'Belém',
    Lisbon: 'Lisboa',
    Azores: 'Açores',
  };
  try {
    const offset = new Intl.DateTimeFormat(locale, {
      timeZone: timezone,
      timeZoneName: 'shortOffset',
    })
      .formatToParts(new Date())
      .find(part => part.type === 'timeZoneName')
      ?.value.replace('-', '−');
    return `${names[city] || city} (${offset})`;
  } catch {
    return names[city] || city;
  }
};

export const formatMoney = (cents, locale, currency = 'BRL') =>
  new Intl.NumberFormat(locale, { style: 'currency', currency }).format(
    (Number(cents) || 0) / 100
  );

export const formatTime = (iso, timezone, locale) =>
  new Intl.DateTimeFormat(locale, {
    hour: '2-digit',
    minute: '2-digit',
    timeZone: timezone,
  }).format(new Date(iso));

const capitalize = text => text.charAt(0).toUpperCase() + text.slice(1);

// «Quarta, 23 de setembro»
export const formatLongDay = (isoDay, locale) =>
  capitalize(
    new Intl.DateTimeFormat(locale, {
      weekday: 'long',
      day: 'numeric',
      month: 'long',
      timeZone: 'UTC',
    })
      .format(new Date(`${isoDay}T12:00:00Z`))
      .replace('-feira', '')
  );

// «Qua, 23 set · 09:00»
export const formatShortMoment = (iso, timezone, locale) => {
  const date = new Date(iso);
  const weekday = new Intl.DateTimeFormat(locale, {
    weekday: 'short',
    timeZone: timezone,
  })
    .format(date)
    .replace('.', '');
  const day = new Intl.DateTimeFormat(locale, {
    day: 'numeric',
    month: 'short',
    timeZone: timezone,
  })
    .format(date)
    .replace('.', '')
    .replace(' de ', ' ');
  return `${capitalize(weekday)}, ${day} · ${formatTime(iso, timezone, locale)}`;
};

export const gmtOffset = (timezone, locale) => {
  try {
    return new Intl.DateTimeFormat(locale, {
      timeZone: timezone,
      timeZoneName: 'shortOffset',
    })
      .formatToParts(new Date())
      .find(part => part.type === 'timeZoneName')
      ?.value.replace('-', '−');
  } catch {
    return '';
  }
};
