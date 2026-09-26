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

  // A faixa é a MESMA anatomia noutra caixa, e é isso que a prende aqui em vez
  // de ser desenhada à mão em cada tela: rótulo, número, variação, rodapé — pela
  // mesma ordem, com os mesmos dados.
  it('keeps the four parts in strip density', () => {
    const faixa = montar({
      density: 'strip',
      delta: '+12%',
      footer: 'R$ 54,7k no mês passado',
    });

    expect(faixa.text()).toContain('Valor em funil');
    expect(faixa.text()).toContain('R$ 61,3k');
    expect(faixa.find('s').text()).toBe('+12%');
    expect(faixa.text()).toContain('R$ 54,7k no mês passado');
  });

  // O que a faixa troca é a CAIXA e o degrau de tipo. O cartão traz moldura e o
  // número a 30px porque ali o indicador é o conteúdo; a faixa não traz nenhuma
  // e desce a 16px porque ali é contexto e a superfície de trabalho vem a
  // seguir. Era por aqui que a fila empurrava o quadro para fora do ecrã.
  it('drops the box and the big type step in strip density', () => {
    const cartao = montar({}).find('div').classes();
    const faixa = montar({ density: 'strip' }).find('div').classes();

    expect(cartao).toContain('p-card');
    expect(cartao).toContain('bg-n-solid-1');
    expect(faixa).not.toContain('p-card');
    expect(faixa).not.toContain('bg-n-solid-1');

    expect(montar({}).get('span.text-3xl').exists()).toBe(true);
    expect(montar({ density: 'strip' }).get('span.text-base').exists()).toBe(
      true
    );
  });

  // Quatro filetes curtos lado a lado, um por coluna, leem-se como uma tabela
  // partida. Na faixa o que separa é o ar entre colunas — regra 3.
  it('leaves the footer rule to the card, not to the strip', () => {
    const comRodape = { footer: '4 cobranças' };

    expect(montar(comRodape).html()).toContain('border-t');
    expect(montar({ ...comRodape, density: 'strip' }).html()).not.toContain(
      'border-t'
    );
  });

  // `inline` é a única densidade que PERDE informação de propósito: fica o
  // rótulo, o valor e a variação, e o rodapé não é desenhado. É a troca que a
  // faz caber no canto de um cabeçalho que já existe, e se alguém a desfizer a
  // linha volta a ter três linhas de altura.
  it('drops the footer in inline density and keeps the change stamp', () => {
    const linha = montar({
      density: 'inline',
      delta: '-29%',
      footer: '6 fechadas',
    });

    expect(linha.text()).toContain('Valor em funil');
    expect(linha.text()).toContain('R$ 61,3k');
    expect(linha.find('s').text()).toBe('-29%');
    expect(linha.text()).not.toContain('6 fechadas');
  });

  // O número desce ao degrau de 14px e a caixa desaparece: é o que separa a
  // linha da faixa, que fica com caixa nenhuma mas número a 16px.
  it('uses the smallest type step and no box in inline density', () => {
    const linha = montar({ density: 'inline' });

    expect(linha.find('div').classes()).not.toContain('p-card');
    expect(linha.get('span.text-sm').exists()).toBe(true);
    expect(montar({ density: 'strip' }).get('span.text-base').exists()).toBe(
      true
    );
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
