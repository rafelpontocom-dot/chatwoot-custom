import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAccount } from './useAccount';

export const DEFAULT_CURRENCY = 'BRL';

/**
 * A moeda da conta.
 *
 * `'BRL'` estava escrito à mão em cada sítio que formatava dinheiro: o cartão,
 * o painel da oportunidade, a lista. Uma clínica em Portugal via euros
 * apresentados com cifrão brasileiro, e não havia por onde mudar. A conta
 * escolhe uma vez; quem formata pergunta.
 */
/**
 * O idioma da aplicação, no formato que o `Intl` entende. O separador decimal
 * segue a língua de quem lê, não a do browser: pt_BR escreve 1.250,50.
 */
export const intlLocale = locale => String(locale || 'en').replace('_', '-');

export function useAccountCurrency() {
  const { currentAccount } = useAccount();
  const { locale } = useI18n();

  const currency = computed(
    () => currentAccount.value?.settings?.currency || DEFAULT_CURRENCY
  );

  const formatAmount = (value, { currency: override } = {}) => {
    const numero = Number(value);
    if (Number.isNaN(numero)) return '';

    return new Intl.NumberFormat(intlLocale(locale.value), {
      style: 'currency',
      currency: override || currency.value,
    }).format(numero);
  };

  return { currency, formatAmount };
}
