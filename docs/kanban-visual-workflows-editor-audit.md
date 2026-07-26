# Auditoria Do Editor Visual E Portfólio De Nós

Data: 2026-07-26

## Decisão

O editor não está 100% aderente à direção aprovada. A fundação de execução,
segurança e canvas está madura, mas a composição visual ainda precisa de uma
última fase de produto. Não publicar a descrição "fusão CRM concluída" até os
itens P0 deste documento serem concluídos e validados em navegador real.

## Auditoria Da Direção Visual

| Camada aprovada | Estado | Evidência e decisão |
| --- | --- | --- |
| Chatwoot | Conforme | Tokens semânticos, Vue, tradução e permissões do dashboard são usados. |
| Frappe CRM | Parcial | O cabeçalho agora é operacional: nome, resumo do gatilho e opções avançadas recolhidas. Ainda faltam formulários especializados fora do builder. |
| Kommo | Parcial | A linguagem comercial e a configuração progressiva existem, porém os gatilhos não explicam todos os seus critérios no mesmo padrão. |
| Node-RED | Conforme | Paleta pesquisável, categorias recolhíveis, inserção por clique/arraste e rotas rotuladas estão presentes. |
| n8n como referência de UX | Parcial | Inspector flutuante, prévia e histórico existem. Todas as famílias do editor, inclusive Mensagem e Ações comerciais, agora têm inspectores próprios; falta apenas validar a composição em navegador real e cenários de acessibilidade. |

### Conformes

- Paleta fixa de `14rem`, com busca, categorias, contagem e alternativa por clique.
- Canvas dominante com zoom, minimapa condicional, desfazer, refazer,
  organizar e inserção contextual.
- Inspector sobreposto de até `16rem`, com `Configurar`, `Testar` e
  `Histórico`; ele não reduz a largura do canvas.
- Cartões de nó com ícone, categoria, resumo, estado, handles e saídas
  rotuladas; formulários não aparecem no canvas.
- Router com saídas ordenadas, grupos E/OU por saída e rota `Caso contrário`.
- Mensagem com preview, emoji, imagem, variável pesquisável e políticas de
  entrega.
- PT-BR e inglês possuem hoje as mesmas chaves do módulo Kanban.

### Pendências P0

1. Validar em navegador real a composição completa extraída. Canvas, superfície,
   cabeçalho, abas, Tempo, Mensagem, Decisão, Distribuir caminhos, Contato,
   Resultado comercial, Ações comerciais e Utilitários são componentes próprios.
2. Padronizar os detalhes finos de todos os inspectores em três blocos: efeito comercial,
   configuração essencial e opções avançadas recolhidas. Nenhum inspector deve
   despejar todos os campos de um nó de uma vez.
4. Executar Playwright real em desktop, tablet e 320 px com bundle atual,
   incluindo foco, Escape, teclado, leitor de tela e todas as ações sem
   arrastar.
5. Executar concorrência de dois administradores, carga de alto volume e smoke
   após migration em homologação.

## Auditoria Dos Gatilhos

| Gatilho | Estado atual | Ajuste necessário |
| --- | --- | --- |
| Oportunidade criada / etapa alterada | Pode escutar criação, entrada na etapa ou ambos; aceita etapa específica ou qualquer etapa. | Conforme. Mostrar o resumo final de modo inequívoco no card do gatilho. |
| Cliente respondeu | Aceita modo explícito `qualquer resposta` ou `frase específica`; a mensagem é repassada ao executor. | P1: adicionar comparação exata e expressão simples somente se houver caso comercial real. |
| Responsável alterado | Aceita qualquer responsável ou um responsável específico. | P1: permitir também filtrar responsável anterior quando houver caso de redistribuição. |
| Valor alterado | Expõe `qualquer alteração de valor` ou comparação com o novo valor. | P1: permitir comparar valor anterior e variação. |
| Campo alterado | Aceita qualquer campo nativo ou personalizado, ou um campo específico; título, observação, valor, etapa, responsável, datas, próxima ação e campos personalizados geram eventos compatíveis. | P1: permitir condição sobre valor anterior/novo. |
| Próxima ação | Aceita agendada, concluída ou vencida; pode filtrar por tipo. | P1: filtrar prazo e responsável da atividade. |
| Oportunidade ganha | Dispara para qualquer ganho. | P1: permitir etapa de origem e responsável no momento do ganho. |
| Oportunidade perdida | Aceita qualquer perda ou motivo específico. | Conforme para P0. |
| Webhook recebido | Pode disparar para qualquer conexão aprovada ou uma conexão específica do board. | Conforme para P0. |
| Reaberta, arquivada, restaurada, iniciada manualmente | Disparam pelo evento. | P1: expor somente os critérios que existirem no evento; não inventar campos. |

## Revisão Do Catálogo n8n

O n8n combina nós de lógica de fluxo, transformação de dados, IA e centenas de
integrações específicas. Esse catálogo não deve ser copiado para o CRM. O
produto local precisa resolver decisões comerciais simples e auditáveis; todo
trabalho livre, técnico ou que conecte sistemas continua no n8n por webhook
aprovado.

### Manter Nativo No Kanban

| Família n8n | Equivalente local | Estado |
| --- | --- | --- |
| Trigger | Eventos de oportunidade, conversa, agenda, webhook e início manual | Presente |
| If / Switch | Condição e Router de primeira correspondência | Presente |
| Filter | Filtro comercial | Presente |
| Wait | Delay, data, resposta, inatividade e horário comercial | Presente |
| Edit Fields (Set) | Definir, incrementar e limpar campo | Presente |
| Mensageria | Elegibilidade, enviar mensagem, template oficial e frequência | Presente |
| Ações CRM | mover etapa, atribuir, rodízio, próxima ação, ganhar, perder, arquivar, etiquetas e nota | Presente |
| Auditoria | Registrar execução, preview, histórico, retry e cancelamento | Presente |
| Saída controlada | Webhook por conexão aprovada e segredo fora do fluxo | Presente |
| Finalização | Concluído, encaminhado, interrompido ou falhou | Presente |

### Próximos Nós Nativos Recomendados

| Prioridade | Nó | Motivo e limite |
| --- | --- | --- |
| P0 | Notificar equipe | Aviso interno para agente/equipe quando uma oportunidade exige ação. Não envia e-mail ou WhatsApp externo por conta própria. |
| P0 | Criar oportunidade | Cria uma oportunidade de forma explícita a partir de conversa/contato; deve oferecer prevenção de duplicidade. |
| P0 | Atualizar etiqueta do contato | Separar etiqueta do contato de etiqueta da oportunidade, com escopo auditável. |
| P0 | Parar execução | Encerra a execução atual com motivo comercial, sem apagar histórico. |
| P1 | Checar duplicidade | Compara telefone, e-mail e oportunidade aberta antes de criar ou avançar um lead. |
| P1 | Definir atividade interna | Cria uma próxima ação para agente/equipe, incluindo data, tipo e responsável; não substitui agenda externa. |
| P1 | Limite de frequência comercial | Reutilizável por canal e por oportunidade para evitar excesso de follow-up. |
| P1 | Janela de conversão | Mede e registra etapa/tempo de conversão; não é um nó de relatório genérico. |
| P2 | Experimento de mensagem | Divisão percentual com critérios explícitos, somente depois de métricas e consentimento estarem validados. |

### Manter No n8n Por Webhook

- HTTP Request, GraphQL, autenticação de terceiros e credenciais por cliente.
- Banco de dados, planilhas, arquivos, ETL, agregação, merge/join e loops.
- E-mail transacional externo, calendário externo, ERP, pagamento e outros
  sistemas operacionais.
- Code/JavaScript/Python, shell, criptografia livre e transformações genéricas.
- IA ampla: agentes, classificação aberta, RAG, vetores, documentos e
  orquestração entre modelos.
- Qualquer um dos conectores específicos do n8n; o CRM envia um evento mínimo
  e assinado para uma conexão previamente aprovada.

### Não Adotar No Editor Comercial

- Nó de código arbitrário.
- SQL ou acesso a banco arbitrário.
- Credenciais, URLs ou segredos dentro do JSON do fluxo.
- Merge/join, loop, subworkflow e paralelismo genéricos.
- Nós de IA genéricos sem contrato de dados, custo, revisão humana e trilha de
  auditoria.

## Licença E Referência

Vue Flow continua sendo a infraestrutura MIT do canvas. A arquitetura de
paleta, categorias e rotas pode se inspirar no Node-RED (Apache-2.0), mas os
componentes devem ser Vue nativos do Chatwoot. O n8n é referência de produto e
comportamento, não fonte de componentes ou código: sua licença Sustainable Use
restringe a distribuição comercial de derivados. Verificar a licença antes de
qualquer reutilização literal de código.

Referências:

- https://docs.n8n.io/flow-logic/
- https://docs.n8n.io/integrations/builtin/
- https://docs.n8n.io/sustainable-use-license/
- https://github.com/bcakmakoglu/vue-flow
- https://github.com/node-red/node-red
