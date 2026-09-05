# Proposta — painel da IA dentro do Chatwoot

## Decisão de produto

O painel externo não deve ser copiado inteiro. O Chatwoot já é o workspace operacional; a nova área **IA** deve explicar o que a Elis está fazendo, permitir configurações seguras e levar o usuário à ação correta sem criar versões paralelas de Conversas, CRM, Agenda ou Financeiro.

## Estrutura proposta

Uma entrada **IA** na navegação e quatro abas:

1. **Visão geral** — status, pacote, módulos ativos, resultados confirmados e pendências.
2. **Configuração** — identidade, tom, critérios de handoff e horário em que a Elis atende.
3. **Conhecimento** — fatos autorizados, cobertura, pendências e histórico de publicação.
4. **Melhorias** — conversas marcadas, propostas, aprovação e impacto medido.

### Visão geral

- estado da Elis com texto + ícone;
- pacote contratado e módulos realmente ativos: CRM, Agenda e Pagamento;
- quatro métricas dos últimos 30 dias: conversas, handoffs, agendamentos e pagamentos confirmados;
- bloco “Precisa de atenção” com links para a conversa, conhecimento ou melhoria;
- resumo da configuração publicada e versão ativa;
- links contextuais para Conversas, CRM, Agenda, Financeiro e Automações.

### Configuração

- nome e papel da Elis;
- tom e limites em controles guiados, sem prompt bruto;
- motivos de handoff;
- horário de atendimento da IA;
- prévia das mudanças, publicação versionada e rollback;
- edição somente para owner/admin; demais agentes veem o resumo.

### Conhecimento

- linguagem simples e agrupamento por assunto;
- estado publicado/rascunho/pendente com ícone e texto;
- cobertura dos fatos obrigatórios;
- histórico de versões;
- nenhum acesso do navegador ao Supabase ou a credenciais.

### Melhorias

- fila curta de decisões, não um laboratório técnico;
- vínculo direto com a conversa nativa do Chatwoot;
- proposta, motivo, evidência e impacto esperado;
- aprovação explícita antes de publicar;
- comparação posterior sem inventar causalidade ou conversão.

## Reavaliação do painel atual

| Área atual | Decisão | Destino |
| --- | --- | --- |
| Hoje / dashboard amplo | Reduzir | IA mostra apenas resultados e pendências da Elis |
| Conversas / Raio-X separado | Não duplicar | Insight contextual na conversa nativa do Chatwoot |
| Minha Elis | Manter e simplificar | Aba Configuração |
| Conhecimento | Manter | Aba Conhecimento |
| Melhorias / qualidade | Manter com aprovação | Aba Melhorias |
| Follow-up | Tirar da configuração central da IA | Automação/CRM; IA mostra status e link |
| Ticket por público | Retirar | CRM/Financeiro |
| Morning briefing | Adiar | Preferências/Notificações, fase posterior |
| Tokens, chamadas e custo LLM | Ocultar do cliente | Console administrativo Raevo |
| AI Factory, logs, releases, evals e benchmarks | Ocultar do cliente | Console administrativo Raevo |
| Credenciais e integrações | Ocultar do cliente | Administração server-side |

## O que não deve aparecer para o cliente

- prompt mestre bruto;
- chaves, tokens, endpoints e IDs técnicos;
- nome do provider/modelo como decisão operacional;
- custo unitário de LLM;
- logs, traces e payloads;
- controles que possam publicar dois providers de CRM simultaneamente;
- qualquer métrica inferida como receita ou pagamento sem evento confirmado.

## Jornada principal

1. Usuário abre **IA** no Chatwoot.
2. Entende em segundos se a Elis está ativa, qual pacote opera e se há pendências.
3. Se há uma conversa aguardando humano, abre a própria conversa.
4. Se falta informação, abre Conhecimento já no item pendente.
5. Se há melhoria, revisa evidência e aprova ou rejeita.
6. Para mudar comportamento, edita Configuração, revisa a diferença e publica uma nova versão.

## Fases recomendadas

### Fase 1 — read-only

- usar o BFF já iniciado;
- status, pacote, versão, conhecimento e métricas confirmadas;
- capability desligada por padrão;
- sem substituir o painel externo ainda.

### Fase 2 — configuração segura

- endpoints específicos por seção;
- RBAC, auditoria, versionamento, diff e rollback;
- conhecimento e configuração guiada;
- nenhuma edição de prompt bruto.

### Fase 3 — contexto operacional

- insight da Elis no painel lateral da conversa;
- pendências com deep links;
- fila de melhorias e aprovação.

### Fase 4 — aposentadoria do painel externo

- confirmar paridade apenas do escopo mantido;
- redirecionar clientes para o Chatwoot;
- manter console técnico Raevo separado;
- remover autenticação e rotas externas obsoletas.

## Critérios visuais

- seguir a direção Raevo **H · Sereno**;
- cabeçalho compacto dentro do corpo;
- superfície clara, alta densidade e sem excesso de cards;
- um único acento azul para ações;
- teal, âmbar e ruby apenas para estados, sempre com ícone + texto;
- botões e campos de uma linha em pílula;
- responsividade validada em 1280 px e navegação completa por teclado.

## Mockup

O mockup navegável da aba **Visão geral** está em:

`output/raevo-ai-chatwoot-proposal/index.html`

Ele é uma proposta de arquitetura e hierarquia; não altera a tela de produção.

![Mockup da Visão geral da Elis](../output/raevo-ai-chatwoot-proposal/overview.jpg)
