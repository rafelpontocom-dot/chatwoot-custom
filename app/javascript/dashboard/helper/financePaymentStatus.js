/**
 * Raevo — o estado de uma cobrança, num sítio só.
 *
 * Vivia dentro do `FinanceView.vue`, por isso o diálogo de detalhe não lhe
 * chegava e mostrava o estado como texto cinzento — sem cor e sem ícone. É o
 * pior sítio para o fazer: o detalhe é onde se confirma «isto foi pago?» antes
 * de o dizer a alguém.
 *
 * Três tons dizem o que fazer — agir, feito, a decorrer — e o ícone diz o mesmo
 * sem depender de cor. São nove estados e quatro tons, portanto há pares que
 * partilham cor: sem ícone ficavam indistinguíveis, e a regra 5 proíbe-o.
 *
 * O `labelKey` fica por traduzir de propósito: quem chama tem o `t()`.
 */
const ESTADOS = Object.freeze({
  draft: { tone: 'slate', icon: 'i-lucide-file-text' },
  pending: { tone: 'slate', icon: 'i-lucide-clock' },
  canceled: { tone: 'slate', icon: 'i-lucide-ban' },
  confirmed: { tone: 'teal', icon: 'i-lucide-check' },
  received: { tone: 'teal', icon: 'i-lucide-check-circle-2' },
  refunded: { tone: 'amber', icon: 'i-lucide-undo-2' },
  overdue: { tone: 'ruby', icon: 'i-lucide-alert-triangle' },
  failed: { tone: 'ruby', icon: 'i-lucide-x-circle' },
  chargeback: { tone: 'ruby', icon: 'i-lucide-alert-octagon' },
});

const TONS = Object.freeze({
  ruby: 'bg-n-ruby-2 text-n-ruby-11',
  teal: 'bg-n-teal-3 text-n-teal-11',
  amber: 'bg-n-amber-2 text-n-amber-11',
  slate: 'bg-n-alpha-2 text-n-slate-11',
});

export const getFinancePaymentStatus = status => {
  const estado = ESTADOS[status] || ESTADOS.pending;

  return {
    ...estado,
    class: TONS[estado.tone],
    labelKey: `FINANCE.PAYMENTS.STATUS.${(status || 'pending').toUpperCase()}`,
  };
};
