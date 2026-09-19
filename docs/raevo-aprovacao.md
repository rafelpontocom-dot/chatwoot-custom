# Fila de aprovação de telas — Raevo

A direção **A · Consultório** está aprovada (19/09/2026). O sistema está gravado em
[`design-system/aprovado/`](../design-system/aprovado/README.md).

Este documento é a outra metade: **nenhuma tela existente muda sem passar por aqui.**

---

## O processo

Por tela, sempre nesta ordem:

| # | Passo | Sai daqui |
| --- | --- | --- |
| 1 | **Apresentar** — mockup da tela na pele Consultório, desktop 1280px e telemóvel, com estado cheio, vazio, a carregar e com erro | um artefacto para ver |
| 2 | **Aprovar** — decisão registada na tabela abaixo, com data | uma linha de `aprovada` |
| 3 | **Implementar** — só depois do passo 2, e só a tela aprovada | um PR que toca nessa tela |
| 4 | **Porta visual** — os cinco passos do `AGENTS.md` (`ui-ux-pro-max`, `frappe-ui-patterns`, `accessibility-compliance`, `agentic-browser-testing`, `visual-testing`), com screenshots antes/depois | prova de que ficou como o mockup |

Um passo 3 sem passo 2 é retrabalho à espera de acontecer. Um passo 4 sem browser a
correr não está feito — os passos 4 e 5 da porta visual não são análise de código.

### O que "aprovada" quer dizer

Que a **estrutura** está decidida: o que fica no ecrã, onde, com que hierarquia e que
ações. Não é aprovação de pixel — cor, raio e densidade vêm dos tokens e mudam
sozinhos quando o sistema muda.

### O que não precisa de aprovação

- **Tela nova.** Nasce em Consultório por omissão. É esse o ponto de ter o sistema
  gravado.
- **Correção de bug visual** que aproxima a tela do sistema (cor literal que virou
  token, degrau de tipo fora da escala, controlo sem rótulo acessível).
- **As telas nativas do Chatwoot.** Ver abaixo — e é de propósito.

---

## O que não entra na fila, e porquê

Esta é a parte que custa dinheiro se for decidida ao contrário.

O Raevo é um fork. **Cada ficheiro do upstream que editamos vira conflito em cada
`git pull` do Chatwoot — para sempre.** Por isso as telas dividem-se em duas classes
com tratamento diferente:

| Classe | Telas | Tratamento | Custo por atualização |
| --- | --- | --- | --- |
| **Nossas** | Kanban/CRM, Agenda, Financeiro, Formulários, IA, Automação, Marketing, Início | mockup → aprovação → implementação | nenhum |
| **Do Chatwoot** | Conversas, Contactos, Caixas de entrada, Definições, Central de ajuda | **só tokens** — markup intocado | nenhum |

As telas do Chatwoot **mudam de aparência na mesma**, porque a cor delas também sai
dos nossos tokens. O que não fazemos é redesenhá-las tela a tela: isso é exatamente o
que encarece o próximo upgrade, e foi a restrição posta desde o início.

Exceção prevista: acrescentar um painel **nosso** dentro de uma tela do Chatwoot
(oportunidade, cobrança ou IA na barra lateral da conversa) é componente nosso e entra
na fila normal. Não é o mesmo que redesenhar a conversa.

---

## A fila

Ordem por dependência: o que ensina mais vem primeiro, e o que depende de decisões
ainda por tomar vem no fim.

| # | Tela | Módulo | Ficheiros | Estado | Nota |
| --- | --- | --- | --- | --- | --- |
| 1 | Pipeline (quadro) | Kanban | 37 `.vue` no módulo | **por apresentar** | é onde a densidade se prova ou falha |
| 2 | Cartão da oportunidade | Kanban | — | por apresentar | depende de 1 |
| 3 | Início | Home | 1 | por apresentar | KPI, cartão com anel, gráfico de um tom |
| 4 | Financeiro | Finance | 3 | por apresentar | estado de cobrança sem depender de cor |
| 5 | Agenda | Calendar | 30 | **decidido — ver abaixo** | vista atual fica; a nova é alternativa |
| 6 | Formulários | Forms | 10 | por apresentar | `RaevoField` é o único tratamento de campo |
| 7 | Automação (Vue Flow) | Kanban | — | por apresentar | cartão de nó com dimensão estável |
| 8 | Painel de conversa (nosso) | Conversation | componente novo | por apresentar | entra dentro de tela do Chatwoot |
| 9 | Entrada (login) | — | upstream | por decidir | mexer aqui é mexer no upstream: avaliar o custo primeiro |

Quando uma linha for aprovada, escreva a data e quem aprovou. Quando for implementada,
ponha o link do PR.

---

## Decisões já tomadas

### Agenda — 19/09/2026

A vista atual **fica como está**. A vista que apareceu no mockup entra como **uma
alternativa que se alterna**, não como substituição.

Motivo: a vista atual já resolve o trabalho de marcar e ler o dia. Trocar uma vista que
funciona por outra não é ganho — ter as duas é.

Por implementar: o seletor de vista, com a vista atual em primeiro e por omissão. Vale
para as duas a mesma regra do `AGENTS.md`: todo o controlo só por ícone precisa de
rótulo acessível e tooltip, e qualquer gesto de arrastar precisa de alternativa por
teclado.

### Modo escuro — 19/09/2026

O Chatwoot já troca de tema em Definições. **Não se cria interruptor novo.** O que
faltava era o escuro da direção A, e esse está gravado em
`design-system/aprovado/consultorio.tokens.json` (bloco `dark`), tirado da referência.

A proposta **C · Órbita não é o modo escuro**. C é violeta com primário `#6E8CFF`; A é
acromática com primário quase preto que inverte para quase branco. Usar C como escuro
de A dava dois produtos diferentes conforme a hora do dia. O que se aproveita de C é a
técnica — no escuro separa-se por degrau de luz, porque um fio de 1px desaparece —, e
isso já está nos tokens escuros de A.

### Cor de ação — 19/09/2026

`--brand-color` passa a `#171717`. O azul `#2563EB` fica reservado a **etapa do funil**.
Consequência a tratar em cada tela que migrar: ligação de texto passa a distinguir-se
por sublinhado, não por ser azul.

---

## Antes de marcar uma tela como implementada

```bash
pnpm raevo:design    # nenhuma cor literal
pnpm raevo:tokens    # código de acordo com o sistema gravado
pnpm raevo:palette   # a paleta de etapas ainda valida
pnpm test            # os testes da tela
```

E a porta visual do `AGENTS.md`, com screenshot de desktop 1280px antes e depois.
