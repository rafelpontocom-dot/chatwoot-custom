import { mount } from '@vue/test-utils';
import RaevoKpiCard from '../RaevoKpiCard.vue';

vi.mock('vue-router', () => ({
  RouterLink: { name: 'RouterLink', template: '<a><slot /></a>' },
}));

const montar = props =>
  mount(RaevoKpiCard, {
    props: { label: 'Valor em funil', value: 'R$ 61,3k', ...props },
    global: {
      stubs: {
        RaevoStamp: { props: ['label'], template: '<s>{{ label }}</s>' },
      },
    },
  });

describe('RaevoKpiCard', () => {
  it('shows a dash when the metric has no measured value', () => {
    // Um zero mentiria — «zero» e «ainda não medido» não são a mesma coisa — e um
    // cartão vazio desalinhava a fila de quatro.
    expect(montar({ value: null }).text()).toContain('—');
    expect(montar({ value: '' }).text()).toContain('—');
  });

  it('leaves out the change stamp when there is nothing to compare', () => {
    // Uma variação vazia não renderiza selo. É a regra que segura a decisão de não
    // inventar deltas: quem não tem mês anterior não mostra seta.
    expect(montar({ delta: '' }).find('s').exists()).toBe(false);
    expect(montar({ delta: '+12%' }).find('s').text()).toBe('+12%');
  });

  it('does not open the second grid column without a destination', () => {
    // O `CardAction` da referência só abre a 2ª coluna quando há acção. Sem `to`,
    // o cartão não deixa um espaço reservado a um link que não existe.
    expect(montar({}).find('a').exists()).toBe(false);
    expect(montar({ to: '/app/x', toLabel: 'Abrir' }).find('a').exists()).toBe(
      true
    );
  });
});
