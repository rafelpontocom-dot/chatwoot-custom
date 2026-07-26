# Roadmap: Editor Visual De Automações Comerciais

Status: fonte de execução do construtor visual de automações do Kanban.

Documentos relacionados:

- [PRD de Fluxos Visuais](./kanban-visual-workflows-prd.md)
- [Spec de Fluxos Visuais](./kanban-visual-workflows-spec.md)
- [Roadmap do Workspace Comercial](./kanban-commercial-workspace-roadmap.md)

## Objetivo

Entregar um editor visual profissional, seguro e simples para as automações comerciais do Kanban. Ele deve permitir configurar mensagens, follow-up, lembretes, distribuição de responsáveis e atualização de oportunidades sem transformar o Chatwoot em um orquestrador genérico como o N8N.

## Legenda

- `[ ]` não iniciado;
- `[-]` em andamento;
- `[x]` implementado localmente, aguardando validação e deploy;
- `[v]` validado em produção;
- `[!]` bloqueado por decisão, dependência ou incidente.

## Decisões Fixas

- Vue Flow é o motor de canvas, conexões, seleção, zoom e minimapa.
- A paleta segue o modelo Node-RED: busca e categorias recolhíveis.
- A configuração segue o modelo n8n: painel contextual flutuante, canvas preservado e histórico sob demanda.
- A direção visual aprovada é uma fusão CRM: paleta Node-RED compacta à esquerda, canvas dominante com leitura n8n e inspector contextual de até 26rem sobreposto à direita; o editor nunca usa uma coluna fixa de formulário.
- Não copiar código do n8n; usar apenas como referência de produto e arquitetura.
- N8N continua responsável por IA ampla, integrações entre sistemas, HTTP arbitrário, banco, código e processos externos.
- A primeira correspondência do Router vence; existe sempre a saída `Caso contrário`.
- Um fluxo não possui ciclos, código de usuário, segredos no JSON nem mais de 50 nós executáveis por rodada.

## Fase 0 - Fundamentos E Compatibilidade

Objetivo: consolidar contratos antes de ampliar o catálogo.

- [x] Catalogar tipos, dados mínimos, ícones, categoria e resumo de cada nó. Registro único local criado; aguarda validação visual e deploy.
- [x] Garantir que `flow_definition` preserve versão, posições, conexões e `sourceHandle`; versões e snapshots mantêm a definição imutável para execuções já iniciadas.
- [x] Validar referências de board, conta, campo, agente, etapa e conexão no backend.
- [x] Manter leitura de fluxos legados e migração visual progressiva: regras sem nós continuam usando as ações legadas; regras visuais são adicionadas sem reescrever as anteriores.
- [x] Centralizar operações de canvas: criar, mover, conectar, remover, inserir entre nós, desfazer e refazer. As operações e o histórico local estão extraídos; as edições do formulário também geram snapshot e as setas movem o nó selecionado. Rascunhos de regras existentes são recuperados localmente apenas quando `lock_version` ainda coincide.
- [x] Criar contrato de estado visual: rascunho, pronto, inválido, aguardando, concluído, ignorado e falhou; a execução pode fornecer o estado operacional ao canvas.
- [x] Criar telemetria de uso e erro por tipo de nó: a API agrega os últimos 90 dias de execuções persistidas por board, sem expor dados de oportunidade, e a central prioriza essa série histórica.

Aceite:

- uma definição inválida recebe `422` com `node_id` e motivo humano;
- um fluxo legado continua executando após a atualização;
- [x] edição concorrente não sobrescreve silenciosamente uma regra publicada: a API usa `lock_version`, responde `409` e o editor mantém as alterações abertas;
- toda alteração de fluxo gera versão auditável.

## Fase 1 - Redesign Do Editor

Objetivo: transformar a tela atual em uma área de trabalho clara e densa.

- [x] Aplicar a fusão CRM aprovada: paleta compacta com categorias progressivas e ícones semânticos, seletor `+` agrupado por categoria, toolbar de canvas agrupada, cards de nó com geometria estável e inspector contextual lateral com cabeçalho fixo. O contrato visual foi registrado no PRD e Spec; falta validação real em Chrome depois do deploy.
- [x] Paleta pesquisável com categorias recolhíveis, estado de abertura preservado após nova renderização e alternativa por clique ao arraste.
- [x] Cabeçalho compacto: nome, gatilho e estado permanecem visíveis em uma faixa responsiva acima do canvas; filtros específicos do gatilho foram movidos para `Opções do gatilho`, há validação local explícita, estado de publicação ao lado de salvar e teste guiado seguro para uma oportunidade em regras já salvas. A entrada usa modelos comerciais com ícones e regras compactas com estado, edição explícita, teste e histórico.
- [x] Canvas dominante com minimapa condicional, zoom, auto-organizar, desfazer e refazer. Minimapa condicional, auto-organizar, desfazer/refazer e atalhos locais preservam o snapshot anterior também ao entrar na edição dos campos do inspector.
- [x] Nós padronizados: ícone, faixa/cor de categoria, título, resumo, chips de configuração e estado visual. A validação do servidor continua apontando o nó inválido no canvas.
- [x] Arestas com rótulo de saída, foco visível, ação de excluir, inserção contextual e destaque da rota executada; o inspector de conexão identifica origem e destino reais em vez de um título genérico.
- [x] Painel flutuante com abas `Configurar`, `Testar` e `Histórico`: o cabeçalho apresenta categoria, título e estado da etapa; as três abas têm ícone, largura equilibrada e navegação por setas/Home/End, mantêm o canvas livre, mostram prévia e exibem os resultados seguros do nó para a regra aberta; o editor permite filtrar por uma execução específica e destaca nós e conexões da rota selecionada.
- [x] Remover rótulos genéricos como `Configurações da etapa` e usar o nome real do nó.
- [x] Estados vazios, carregamento, salvamento, validação e recuperação de erro no workspace e no inspector.
- [-] Responsividade: o controle do canvas abre a paleta pesquisável e categorizada em drawer no mobile, enquanto o seletor contextual continua no desktop; falta validação visual em viewport real para o canvas em tela cheia.

Aceite:

- nenhum formulário permanente reduz a largura do canvas;
- a pessoa identifica o tipo e o efeito de cada nó sem abri-lo;
- inserir, remover e reconectar funciona por mouse e teclado;
- salvar inválido aponta o nó, mantém o canvas e abre a configuração correta.

## Fase 2 - Revisão Dos Nós Existentes

### Gatilho

- [x] Mostrar evento selecionado no card do gatilho.
- [x] Mostrar somente filtros compatíveis com o evento: etapa, responsável, campo, valor e próxima ação aparecem apenas nos gatilhos correspondentes.
- [x] Separar claramente gatilho de condições posteriores: o gatilho é uma categoria própria, enquanto Router e Filtro pertencem a Decisão e são adicionados como passos posteriores.

### Tempo

- [x] Padronizar `Aguardar`, `Aguardar até data`, `Aguardar resposta`, `Aguardar inatividade` e `Horário comercial` como categoria Tempo.
- [x] Exibir resumo humano: `24 horas`, `24 h antes/depois da consulta`, `no horário da consulta` e limites de resposta/inatividade.
- [x] Validar fuso, data já vencida e campo de data incompatível. O nó escolhe e valida o fuso; a execução registra datas vencidas como ignoradas e a simulação mostra explicitamente o horário calculado ou que ele já passou antes da publicação.

### Mensagem

- [x] Completar preview de WhatsApp/e-mail, emoji, imagem, variáveis pesquisáveis e template oficial.
- [x] Mostrar no card o canal, a primeira linha do texto ou o template oficial escolhido. O nó de elegibilidade mostra canal, consentimento e bloqueios seguros de opt-in, janela de 24 h ou conversa incompatível depois de uma simulação/execução.
- [x] Testar variáveis com uma oportunidade sem enviar mensagem: a simulação resolve contato, oportunidade, valor e campos personalizados usando o mesmo renderizador do envio.
- [x] Exibir bloqueios de opt-in, janela de 24 h e conversa incompatível de forma compreensível, sem revelar dados pessoais. O template oficial escolhido aparece no nó de mensagem.

### Ação E Atualização De Campo

- [x] Trocar a leitura genérica de `Ação` por título específico conforme a escolha: mover etapa, atribuir, próxima ação, tag, nota ou arquivar.
- [x] Atualização de campo suporta definir, incrementar e limpar valores configurados; o nó de ação assume o título específico da operação e mostra campo/valor em chips.
- [x] Mostrar campo, operação e valor em chips legíveis: cards de ação exibem etapa, responsável, distribuição, próxima ação, campo, etiqueta ou primeira linha da nota configurada.

### Roteador E Distribuição

- [x] Roteador com múltiplas saídas ordenadas, grupos E/OU e `Caso contrário`.
- [x] Reordenar saídas e condições por teclado e arraste: controles acessíveis de subir/descer e alça de arraste preservam a prioridade das saídas.
- [x] Mostrar contagem e resumo de regras por saída no canvas: cada ramificação do Router exibe nome, número de condições e modo E/OU.
- [x] Renomear Round Robin atual para `Distribuir caminhos`, explicando que ele alterna saídas sequenciais.
- [x] Separar `Distribuir responsável` como ação comercial, com agentes e política de indisponibilidade: qualquer agente, somente online ou online/ocupado; sem candidato elegível, a atribuição é registrada como ignorada.

### Webhook E Fim

- [x] Mostrar nome e estado da conexão, nunca URL ou segredo, no nó de webhook.
- [x] Adicionar teste seguro e histórico de resposta sanitizado: a prévia mostra apenas o nome da conexão aprovada e a execução expõe somente metadados permitidos.
- [x] Permitir finais semânticos: concluído, encaminhado, interrompido e falhou; o resultado é adicionado ao histórico da execução e o fim `falhou` encerra a execução sem lançar exceção.

Aceite:

- todos os nós existentes possuem título, ícone, resumo, validação e ajuda contextual;
- nenhum nó mostra jargão técnico sem explicação comercial;
- Router e distribuição de responsável não podem ser confundidos.

## Fase 3 - Novos Nós Comerciais P0

- [x] `Filtro`: atalho de uma regra de passagem, usando o mesmo motor do Router. Contrato, executor, previsualização e configuração visual foram validados com banco local.
- [x] `Elegibilidade de mensagem`: verifica consentimento, conversa compatível e janela do WhatsApp, com saídas `Pode enviar` e `Caso contrário`. Frequência, etapa e horário silencioso continuam sendo aplicados pelo nó de envio; contrato e execução foram validados com banco local.
- [x] `Aguardar inatividade`: segue após o prazo sem resposta do cliente. O fluxo é ignorado quando o cliente responde antes do prazo; contrato e execução foram validados com banco local.
- [x] `Transferir para humano`: encaminha a conversa vinculada para uma equipe comercial, um responsável ou ambos, registra a nota de contexto opcional e encerra o fluxo para bloquear mensagens futuras. Referências são validadas no escopo da conta e contrato/executor foram validados com banco local.
- [x] `Atualizar contato`: altera somente atributos personalizados seguros, incluindo `marketing_messages_opt_in` e `date_of_birth`. O inspector oferece atributos conhecidos e uma alternativa explícita para outra chave personalizada; consentimentos usam checkbox, nascimento usa data e o backend normaliza os tipos antes de salvar.
- [x] `Ganhar oportunidade` e `Perder oportunidade`: atualizam os campos comerciais nativos e a perda exige um motivo configurado no quadro. A validação central do card impede o fechamento com campos obrigatórios pendentes; contrato e execução foram validados com banco local.
- [x] `Concluir próxima ação`: marca a atividade atual como concluída, preserva o histórico do card com nota de conclusão e pode agendar opcionalmente a próxima atividade. Tipo e data da nova ação são validados juntos antes da publicação.
- [x] `Registrar execução`: cria o evento imutável `automation_logged` na linha do tempo, com conteúdo, regra, execução e nó de origem; contrato e execução foram validados com banco local.
- [x] `Tratar falha`: webhook permite interromper com retry seguro ou seguir pelas saídas `Sucesso` e `Falhou`; mensagem pode manter o retry seguro ou seguir por `Enviada` e `Não enviada` para bloqueios de entrega; espera por data pode interromper ou seguir por `Data disponível` e `Data indisponível`; espera por resposta pode seguir por `Resposta recebida` ou `Prazo da resposta vencido`; espera por inatividade pode seguir por `Nenhuma resposta recebida` ou `Cliente respondeu`; e horário comercial pode seguir por `Janela de atendimento disponível` ou `indisponível` se não for possível calculá-la. As transições escolhem a rota correta sob lock. Falhas inesperadas preservam o estado reprocessável até o Active Job esgotar tentativas e só então são fechadas sob lock.

Aceite:

- lembrete de consulta e follow-up podem ser criados apenas com nós P0;
- uma transferência humana impede mensagens automáticas posteriores da mesma execução;
- qualquer mudança comercial aparece na timeline da oportunidade;
- falha não gera reenvio silencioso nem deixa execução presa.

## Fase 4 - Gatilhos E Agenda P1

- [x] Agenda recorrente: `TriggerScheduledItemsJob` processa cadências, lembretes e aniversários em fila própria; cada serviço usa o fuso e o contrato do item configurado.
- [x] Gatilho de inatividade e prazo de próxima ação: inatividade está disponível no editor e a próxima ação vencida é verificada pelo agendador, uma vez por oportunidade e dia.
- [x] Aniversário: automação dedicada usa `date_of_birth`, opt-in, conversa compatível, template oficial e entrega idempotente por ano/canal.
- [x] Lembrete de consulta: regras por etapa e campo de data/hora aceitam múltiplos intervalos, mensagens por intervalo e entrega idempotente.
- [x] Modelo de follow-up: cadências existentes suportam espera, pausa por resposta, verificação de etapa, limite de passos, incremento de campo e etapa final; fluxos novos usam o editor visual. A entrada por etapa inscreve todas as cadências ativas configuradas e é idempotente por oportunidade/cadência, inclusive quando workers concorrem.
- [x] Modelos em rascunho: venda WhatsApp, clínica/consulta, B2B e funil em branco, sempre desativados até a revisão e publicação do gestor.

Aceite:

- cada intervalo de lembrete pode ter uma mensagem própria;
- alteração da data de consulta recalcula esperas futuras com snapshot e política explícita;
- follow-up encerra ao receber resposta, mudar de etapa ou exceder a política configurada.

## Fase 5 - Teste, Execução E Governança P1

- [x] Simulação passo a passo com oportunidade escolhida e sem efeitos externos: o preview resolve condições, rota, variáveis de mensagem e conexão de webhook sem executar ações.
- [x] Histórico por execução e por nó: a central de execuções mostra passos, saída escolhida, estado, horário e motivos seguros; o ícone de fluxo abre sua regra já filtrada por aquela tentativa e destaca nós e conexões percorridas no canvas.
- [x] Retry e cancelamento de espera com autorização.
- [x] Modo de publicação: rascunho, validar, publicar e restaurar versão.
- [x] Aviso de impacto ao alterar regra com execuções aguardando: o administrador escolhe explicitamente cancelar as esperas; quando não seleciona a opção, elas mantêm o snapshot da versão anterior.
- [x] Permissões comerciais por papel: `kanban_automate` permanece compatível e as permissões `kanban_automation_publish`, `kanban_automation_test` e `kanban_automation_execution` separam publicação, simulação e operação de execuções.
- [x] Auditoria de conexões e mascaramento de segredos: a API de execução expõe apenas metadados permitidos por passo; a área de Integrações mantém o histórico administrativo de criação, alteração, remoção e regeneração de segredo, sem registrar URL ou segredo.

Aceite:

- gestor consegue explicar por que uma mensagem foi enviada, ignorada ou falhou;
- operador não consegue publicar uma regra sem permissão;
- edição de fluxo não altera execução já agendada sem decisão explícita.

## Fase 6 - Qualidade, Acessibilidade E Produção P2

- [-] E2E desktop, tablet e mobile: a suíte Playwright cobre entrada no Kanban, abertura do workspace, rascunho, paleta, inspector, Escape, retorno de foco, ciclo de Tab, navegação das abas do inspector por seta e o drawer categorizado em viewport de 320 px. `KANBAN_E2E_BOARD_ID` torna a escolha do quadro determinística e o helper de login aguarda apenas `domcontentloaded`, compatível com Vite. A tentativa local de 2026-07-26 autenticou e consultou o board, mas serviu a tela legada `Funnels`; falta executar contra ambiente provisionado com o bundle atual, `KANBAN_E2E=1`, e registrar as capturas reais.
- [-] Navegação por teclado: paleta, criação, seleção de nó por Enter/Espaço, conexão pelo inspector, edição e publicação possuem alternativa sem arraste. O canvas é uma região nomeada e o inspector anuncia seu título. Falta validar a sequência completa em navegador real, incluindo leitor de tela.
- [-] Foco preso e retorno de foco em painéis; Escape fecha o inspector e o foco retorna ao editor. O inspector possui nome programático vinculado ao título do nó ou conexão. Falta validação manual com leitor de tela em ambiente real.
- [x] Alternativa sem arraste para criar, mover, conectar e remover nós: paleta por clique, setas para mover, inspector para conectar nós existentes e ações acessíveis para remover nós ou arestas. O inspector bloqueia ciclos antes de salvar, mantendo a mesma regra do validador do backend.
- [-] Concorrência: regras usam `lock_version`; execuções usam chave única por evento e lock por execução; um spec com duas conexões reais confirma uma única execução para o mesmo evento; falhas transitórias preservam os estados reprocessáveis até esgotar retries. Faltam duas sessões reais de administrador e workers concorrentes no ambiente de homologação.
- [-] Teste de alto volume: cadências, lembretes e oportunidades com próxima ação vencida percorrem lotes explícitos de 100; a execução é idempotente por regra/evento e há índice parcial concorrente para oportunidades abertas com próxima ação vencida. Falta executar o cenário de carga com volume representativo no ambiente de homologação.
- [-] Smoke test pós-migration: `kanban_automations:smoke` verifica índice, auditoria e classes de execução sem alterar dados no `chatwoot_api` e no Sidekiq da mesma imagem. Falta executá-lo e registrar a evidência no ambiente de homologação/produção.
- [x] CI do fork: a checagem customizada executa RuboCop sobre controllers, serviços, jobs, modelos, migrations, auditoria e tarefa de smoke do Kanban; após preparar banco e migrations, executa `kanban_automations:smoke` antes da suíte focada de specs e testes frontend.
- [x] Observabilidade: a central de execuções resume telemetria histórica de uso e falhas por nó, taxa de falhas, esperas vencidas, mensagens bloqueadas por salvaguardas de envio e execuções possivelmente interrompidas.

Aceite:

- o fluxo pode ser construído e publicado sem mouse;
- não há sobreposição ou perda de ação em 320px, tablet e desktop;
- reprocessamento não duplica mensagens ou ações;
- métricas e logs permitem diagnosticar incidente sem expor segredos.

## Backlog Mantido No N8N

- [ ] Integrações arbitrárias entre sistemas.
- [ ] IA ampla, agentes e classificação sem contrato restrito.
- [ ] HTTP, banco, arquivos, código e shell genéricos.
- [ ] Loop, merge/join, paralelismo e subworkflow genérico.

Esses itens não bloqueiam o CRM: quando forem necessários, o fluxo comercial chama uma conexão aprovada por webhook e recebe apenas o resultado necessário para a oportunidade.

## Checklist De Cada Pull Request

- [ ] Atualizar PRD, spec e este roadmap quando o contrato mudar.
- [ ] Criar ou atualizar spec de serviço/validador antes da implementação backend.
- [ ] Criar teste de componente para comportamento visual novo.
- [ ] Verificar autorização, escopo de conta e referências do board.
- [ ] Validar i18n em `en` e `pt_BR`, sem placeholders incompatíveis.
- [ ] Verificar teclado, foco, contraste, alternativa ao arraste e mobile.
- [ ] Executar lint, specs direcionadas e `git diff --check`.
- [ ] Testar em ambiente com migrations aplicadas antes de publicar imagem.
