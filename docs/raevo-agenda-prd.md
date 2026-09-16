# PRD — A agenda do Raevo: configuração e página de agendamento

Aprovado em 2026-09-16 com base em dois mockups já validados pelo Pedro:

- **Configurações da agenda** — https://claude.ai/code/artifact/a5142472-d7f9-4c14-b49b-13b55c5257fa
- **Página de agendamento pública** — https://claude.ai/code/artifact/d0ca7c0c-ab23-4241-b668-bd51ca16b060

O compromisso deste documento é estreito e literal: **entregar o que está nos
mockups**, com o mesmo visual, a mesma divisão de telas e os mesmos nomes. A
SPEC ([`raevo-agenda-spec.md`](raevo-agenda-spec.md)) diz como; este diz o quê e
o porquê.

---

## 1 · O problema

A agenda do Raevo já marca consulta, já cruza profissional, sala e equipamento,
já importa Google e Feegow. O que falta é **configurar** e **mostrar**.

Hoje:

- O horário de trabalho vive preso a cada agenda. Uma clínica com oito agendas
  no mesmo horário comercial configura a mesma semana oito vezes — e corrige
  oito vezes quando o horário muda.
- Não existe exceção de data. Feriado e férias resolvem-se apagando a semana e
  repondo depois.
- Não existe equipe. Com dois dermatologistas para o mesmo procedimento não há
  como dizer «qualquer um que tenha vaga».
- Antecedência mínima, janela futura e espaçamento são **da conta inteira**, não
  do procedimento. A avaliação de 50 minutos e o retorno de 15 obedecem à mesma
  regra.
- A configuração está espalhada por três abas soltas (Procedimentos, Agendas,
  Página de agendamento) sem um lugar onde se veja um procedimento inteiro.
- A página pública é um formulário: um select de agenda, um campo de data, uma
  lista de horários. Sem calendário do mês, sem fuso, sem pagamento, sem marca
  da clínica.

O Cal.com resolveu a parte genérica disto melhor do que qualquer outro produto,
e o Pedro pediu explicitamente para seguir o padrão deles. **Nenhuma linha de
código do Cal.com entra aqui** — é AGPL-3.0, e copiá-lo contaminaria o Raevo
inteiro, incluindo o `enterprise/` proprietário do Chatwoot. Copiam-se as
ideias, que não são protegidas.

---

## 2 · Quem usa, e o que muda para cada um

| Pessoa | Hoje | Depois |
| --- | --- | --- |
| **Secretária** | repete a mesma semana em cada agenda | escolhe «Comercial» numa lista |
| **Gestor da clínica** | não consegue exigir 24h de antecedência só na avaliação | regra por procedimento |
| **Profissional** | férias = apagar e repor a semana | exceção de data, com o dia à vista |
| **Paciente** | formulário com campo de data | calendário do mês com os dias que têm vaga |
| **Clínica com 2+ profissionais** | impossível oferecer «qualquer um» | equipe com rodízio ou primeiro com vaga |

---

## 3 · O que se entrega

### 3.1 · Configurações da agenda (mockup 1)

Quatro telas, na barra lateral, exatamente como no mockup:

**Procedimentos** — o painel por abas. Entrar num procedimento abre tudo o que
lhe diz respeito, em sete grupos:

| Aba | O que contém | Equivalente no Cal |
| --- | --- | --- |
| **O que é** | nome, link público, descrição, duração, local, cor | Setup |
| **Quem atende** | profissional · sala · equipamento, e a regra quando há mais de um profissional | Assignment |
| **Quando** | horário de cada agenda · horário nomeado · horário só deste procedimento, com prévia dos horários que sobram | Availability |
| **Formulário** | as perguntas da página de agendamento, com obrigatório/opcional | Advanced › Booking questions |
| **Limites** | antecedência mínima, janela futura, espaçamento, intervalo antes/depois, máximo por dia | Limits |
| **Pagamento** | cobrar ao agendar, valor, sinal ou cheio, formas, tempo que segura a vaga | Apps › Payments |
| **Remarcar e cancelar** | quem pode, até quando, motivo obrigatório, efeito na oportunidade | espalhado no Cal |

A aba **Quem atende** é a diferença de fundo: o Cal marca uma pessoa, a clínica
ocupa **três coisas ao mesmo tempo**. A prévia na aba Quando existe por isso —
mostra o que sobra depois de cruzar as três agendas, o Google e o Feegow.

**Disponibilidade** — horários com nome («Comercial», «Manhãs da Dra. Anna»),
um deles padrão. Editor da semana com vários intervalos por dia, «copiar
para…», exceções de data e fuso próprio. Criar agenda passa a ser **escolher um
destes**.

**Agendas** — profissionais, salas e equipamentos numa lista só, cada um a
dizer que horário usa e onde espelha (Google, Feegow). Agenda sem horário
aparece marcada **«falta horário»** — hoje o aviso existe no payload e não
aparece em lado nenhum.

**Equipes** — grupo de profissionais para o mesmo procedimento, com a regra de
distribuição: **primeiro com vaga**, **rodízio** ou **todos juntos**.

### 3.2 · Página de agendamento (mockup 2)

Três passos, com o desenho consagrado pelo Cal:

1. **Escolher horário** — quem a clínica é à esquerda, procedimentos e
   calendário do mês no meio, horários do dia à direita, fuso à vista. Dias sem
   vaga ficam apagados, não desaparecem.
2. **Seus dados** — nome, WhatsApp, CPF (quando a clínica usa Feegow), e-mail,
   observação. Com cobrança ativa, o bloco de pagamento com as formas e o total.
   **O horário fica reservado 10 minutos** enquanto se preenche.
3. **Confirmado** — o resumo, «adicionar ao meu calendário» e «remarcar».

Com cobrança desligada, o bloco de pagamento e o preço somem e o botão passa a
«Confirmar agendamento» — o mockup mostra os dois estados no mesmo interruptor.

---

## 4 · O que fica de fora

- **Página de evento por procedimento** (um link por procedimento com página
  própria) — o Pedro marcou como futuro. O link já existe; a página dedicada não.
- **Workflows, webhooks e embed** do Cal — o Raevo tem Automação em Vue Flow,
  que é onde isso vive.
- **Recorrência** na página pública — o modelo já suporta (`recurrence_allowed`,
  `allowed_intervals`), a página não expõe.
- **Raevo → Feegow** (escrever no prontuário) — fase 2 do Feegow, ver
  [`raevo-feegow-calendar-integration.md`](raevo-feegow-calendar-integration.md).
- **Emissão fiscal** e recorrência de cobrança — P1 do Financeiro.

---

## 5 · Decisões ainda em aberto

Nenhuma bloqueia o começo; todas têm um padrão escolhido, que fica valendo se
ninguém mudar.

| # | Decisão | Padrão adotado se ninguém mudar |
| --- | --- | --- |
| 1 | Horários nomeados substituem o horário por agenda, ou convivem? | **Substituem.** A migração cria um horário por agenda e a clínica junta depois |
| 2 | Na página pública, o paciente escolhe o profissional ou «primeiro com vaga»? | **Escolhe**, com «primeiro com vaga» como opção por procedimento |
| 3 | Cobrança: sinal, valor cheio ou pagar na clínica? | **Os três**, escolhidos por procedimento; a vaga fica presa 10 min |
| 4 | CPF obrigatório sempre ou só com Feegow? | **Só com Feegow**, como combinado na fase 1 |
| 5 | Marca da clínica na página ou visual único do Raevo? | **Nome, endereço e iniciais** da clínica; cor e logo ficam para depois |
| 6 | Equipes entram nesta entrega ou depois da página pública? | **Nesta**, sem elas «primeiro com vaga» não existe |
| 7 | Onde o mockup difere do sistema de design do Raevo, quem vence? | **O mockup** («quero justamente o visual apresentado»): campo com canto de 10 px e corpo a 13 px, via variante e token novos, só nestas telas |

A versão de referência deste PRD e da SPEC é o documento
[Nova agenda do Raevo — PRD e SPEC](https://claude.ai/code/artifact/ccfe19fc-db68-4f26-b6a0-440ca1fda124).
Cartões no ClickUp (lista «Desenvolvimento & Melhorias Produtos/Serviços»):
F1 `86cbhtj57` · F2 `86cbhtj5k` · F3 `86cbhtj5v` · F4 `86cbhtj5y` · F5 `86cbhtj67` · F6 `86cbhtj6b`.

---

## 6 · Como se sabe que ficou pronto

Cada uma destas frases tem de ser verdadeira, verificada numa jornada real de
browser a 1280px, com screenshot — a Porta de Qualidade Visual do
[`CLAUDE.md`](../CLAUDE.md) aplica-se inteira:

1. Criar o horário «Comercial», aplicá-lo a quatro agendas e mudá-lo uma vez
   muda as quatro.
2. Marcar 7 de outubro como exceção fechada faz o dia desaparecer da página
   pública, sem tocar na semana.
3. Um procedimento com antecedência de 24h não oferece amanhã de manhã; outro,
   sem essa regra, oferece.
4. A aba **Quando** mostra a mesma lista de horários que a página pública mostra
   ao paciente, para a mesma combinação.
5. Com dois dermatologistas e regra «primeiro com vaga», o horário livre de
   qualquer um aparece; com «todos juntos», só o que os dois têm livre.
6. A página pública abre no calendário do mês com os dias que têm vaga, o fuso
   do visitante e, com cobrança ligada, leva ao pagamento e só confirma quando o
   webhook confirmar.
7. Agenda sem horário aparece com o aviso **«falta horário»** em Agendas.
8. Nada do que já existe quebra: Google, Feegow, remarcação, oportunidade,
   `source_read_only`.
