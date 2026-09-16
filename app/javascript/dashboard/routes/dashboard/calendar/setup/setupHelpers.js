// Utilitários das configurações da agenda: fuso legível, resumo da semana e
// mensagem de erro da API.

export const TIMEZONES = [
  'America/Sao_Paulo',
  'America/Recife',
  'America/Fortaleza',
  'America/Bahia',
  'America/Belem',
  'America/Manaus',
  'America/Cuiaba',
  'America/Porto_Velho',
  'America/Rio_Branco',
  'America/Noronha',
  'Europe/Lisbon',
  'Atlantic/Madeira',
  'Atlantic/Azores',
  'UTC',
];

const CITY_NAMES = {
  Sao_Paulo: 'São Paulo',
  Belem: 'Belém',
  Cuiaba: 'Cuiabá',
  Lisbon: 'Lisboa',
  Azores: 'Açores',
};

// «Recife (GMT−3)»
export const timezoneLabel = timezone => {
  const key = timezone.split('/').pop() || timezone;
  const city = CITY_NAMES[key] || key.replace(/_/g, ' ');
  try {
    const offset = new Intl.DateTimeFormat('en-US', {
      timeZone: timezone,
      timeZoneName: 'shortOffset',
    })
      .formatToParts(new Date())
      .find(part => part.type === 'timeZoneName')
      ?.value.replace('-', '−');
    return offset ? `${city} (${offset})` : city;
  } catch {
    return city;
  }
};

export const timezoneOptions = current => {
  const zones =
    current && !TIMEZONES.includes(current)
      ? [current, ...TIMEZONES]
      : TIMEZONES;
  return zones.map(zone => ({ value: zone, label: timezoneLabel(zone) }));
};

const WEEK_ORDER = [1, 2, 3, 4, 5, 6, 0];

const rangesText = ranges =>
  ranges.map(range => `${range.from}–${range.to}`).join(' e ');

// «Seg–sex, 08:00–18:00» · «Seg, qua, sex · 08:00–12:00»
export const weekSummary = (weekly, shortDayNames) => {
  if (!weekly?.length) return '';
  const groups = new Map();
  WEEK_ORDER.forEach(weekday => {
    const day = weekly.find(item => item.weekday === weekday);
    if (!day?.ranges?.length) return;
    const key = rangesText(day.ranges);
    groups.set(key, [...(groups.get(key) || []), weekday]);
  });

  const parts = [...groups.entries()].map(([ranges, weekdays]) => {
    const positions = weekdays.map(weekday => WEEK_ORDER.indexOf(weekday));
    const consecutive =
      weekdays.length > 2 &&
      positions.every(
        (position, index) =>
          index === 0 || position === positions[index - 1] + 1
      );
    const names = consecutive
      ? `${shortDayNames[weekdays[0]]}–${shortDayNames[weekdays[weekdays.length - 1]]}`
      : weekdays.map(weekday => shortDayNames[weekday]).join(', ');
    return consecutive ? `${names}, ${ranges}` : `${names} · ${ranges}`;
  });
  const text = parts.join('; ');
  return text.charAt(0).toUpperCase() + text.slice(1);
};

export const apiErrorMessage = (error, fallback) =>
  error?.response?.data?.message || fallback;

export const toSlug = value =>
  (value || '')
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');

export const formatMoney = (cents, locale = 'pt-BR', currency = 'BRL') =>
  new Intl.NumberFormat(locale, { style: 'currency', currency }).format(
    (Number(cents) || 0) / 100
  );
