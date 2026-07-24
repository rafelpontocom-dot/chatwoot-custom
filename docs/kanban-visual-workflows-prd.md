# PRD: Fluxos Visuais Do Kanban

## Contexto

O Kanban comercial do Chatwoot precisa automatizar etapas repetitivas de venda sem transferir a equipe para N8N, Kommo ou planilhas. O administrador deve conseguir entender uma regra olhando para um fluxo, enquanto a equipe comercial recebe ações claras e auditáveis na oportunidade.

O produto não é um clone genérico de ferramentas de automação. Ele é um construtor de processos comerciais limitado aos dados, permissões e canais que o board já conhece.

## Objetivo

Permitir que administradores criem automações seguras para oportunidades: iniciar por um evento comercial, esperar, avaliar condições, enviar uma mensagem compatível ou executar uma ação no card.

## Não Objetivos

- executar JavaScript, código Liquid arbitrário ou scripts de usuário;
- armazenar chaves de serviços externos no fluxo;
- substituir o N8N em integrações complexas nesta fase;
- criar ramificações, loops ou jornadas multicanal sem simulação e auditoria;
- enviar WhatsApp fora da janela de atendimento sem template aprovado.

## Perfis

**Administrador comercial:** configura regras, testa com uma oportunidade e acompanha execuções.

**Secretária ou vendedor:** trabalha no card e vê o resultado da automação, sem precisar editar o fluxo.

**Gestor:** audita o que foi enviado, executado, ignorado ou falhou.

## Fluxo Da Experiência

1. O administrador abre Kanban > Automações do funil pelo ícone de raio no cabeçalho.
2. A central mostra Fluxos, Lembretes, Conexões e Execuções, com os itens existentes em listas curtas e escaneáveis.
3. Seleciona uma automação, usa Nova automação ou parte de um modelo pronto para abrir o construtor em uma área dedicada.
4. Define nome, evento, etapa de origem e estado ativo no cabeçalho compacto do fluxo.
5. Usa o botão `+` para escolher uma etapa a acrescentar ao canvas, sem uma paleta permanente ocupando espaço.
6. Seleciona um nó para configurar seu conteúdo no painel lateral.
7. Salva. O backend valida todos os nós antes de ativar a regra.
8. Quando o evento ocorre, a execução fica registrada no histórico do funil, com estado, oportunidade e motivo de falha.
9. Se houver uma espera, o card segue operando normalmente; a execução retoma no horário salvo.

## Princípios Da Central De Automações

- O canvas é uma área de trabalho, não um bloco dentro de um formulário longo.
- O botão `+` apresenta opções somente quando a pessoa quer acrescentar uma etapa.
- O painel lateral aparece apenas para o nó selecionado e concentra suas propriedades.
- Lembretes de consulta são configurados em uma aba própria; follow-up comercial é um fluxo visual, nunca uma segunda configuração paralela.
- Conexões externas têm configuração própria: o fluxo apenas escolhe uma conexão já aprovada.
- Execuções permitem retry de falhas, cancelamento de esperas e leitura rápida do impacto na oportunidade.
- O inseridor contextual `+` acrescenta e conecta o próximo passo no caminho selecionado; uma paleta fixa não deve roubar espaço do canvas.
- O fluxo nasce como rascunho e só é ativado depois de validado e revisado por um administrador. Cada salvamento cria uma versão visível para auditoria; execuções mantêm o snapshot da versão que as iniciou.
- Cadências legadas permanecem somente para preservar histórico e regras existentes; novas cadências não são criadas pela central.
- `Follow-up comercial` e `NPS e avaliação Google` são sempre abertos como rascunho. `Mensagem de aniversário` abre sua configuração específica, desativada por padrão, pois depende da data de nascimento do contato.

## Nós Da Primeira Entrega

| Nó                | Finalidade                                                         | Configuração obrigatória   |
| ----------------- | ------------------------------------------------------------------ | -------------------------- |
| Gatilho           | Início visual do fluxo; o evento continua configurado na regra.    | Um por fluxo.              |
| Aguardar          | Pausa a execução por horas.                                        | Número positivo de horas.  |
| Aguardar até data | Agenda em relação a um campo de data/hora da oportunidade.         | Campo e deslocamento.      |
| Aguardar resposta | Pausa até uma resposta recebida do cliente, ou até vencer o prazo. | Limite positivo em horas.  |
| Aguardar horário comercial | Mantém a execução até a próxima janela de trabalho configurada. | Dias, horário inicial/final e fuso. |
| Enviar mensagem   | Envia WhatsApp ou e-mail na conversa compatível do contato.        | Canal, opt-in e texto.     |
| Ação comercial    | Atualiza a oportunidade ou registra o próximo trabalho do time.    | Tipo e parâmetros da ação. |
| Enviar webhook    | Envia dados da oportunidade para uma conexão HTTPS já configurada. | Conexão ativa.             |
| Condição          | Separa o fluxo em caminhos Sim e Não.                              | Campo, operador e valor.   |
| Fim               | Encerra o caminho.                                                 | Nenhuma.                   |

As ações comerciais disponíveis são: mover etapa, definir responsável, distribuir novos cards em rodízio, criar próxima ação, preencher ou incrementar campo personalizado numérico, arquivar oportunidade, adicionar/remover etiqueta e registrar nota interna na conversa vinculada.

O modelo de follow-up usa `Aguardar`, `Aguardar resposta` e `Definir próxima ação`, mantendo todo o processo em um único fluxo auditável. Mensagens externas exigem sempre um nó `Enviar mensagem`, com opt-in e as regras do canal.

## Regras De Mensagem Externa

- Mensagem exige opt-in explícito no atributo do contato configurado pelo administrador.
- WhatsApp usa uma conversa compatível e somente envia quando ela pode receber resposta livre.
- Fora da janela de 24 horas, a execução é marcada como ignorada. Templates oficiais entram em etapa posterior.
- E-mail exige uma conversa de e-mail compatível.
- Ausência de conversa, opt-in ou janela não causa repetição infinita: fica registrada como `skipped` no histórico e o fluxo continua.
- A mensagem permite a variável inicial `{{contact_name}}`.
- Horário silencioso e intervalo mínimo entre mensagens podem ser configurados no nó. Quando aplicáveis, a execução fica aguardando e retoma automaticamente no próximo horário permitido.

## Regras De Confiabilidade

- Uma execução é idempotente por regra e evento comercial.
- Esperas são persistidas; nenhum processo fica aberto aguardando tempo.
- Desativar a regra antes da retomada impede a continuidade e registra a execução como ignorada.
- Arquivar a oportunidade antes da retomada também interrompe o fluxo.
- A configuração deve rejeitar referências a etapas, agentes e campos fora do board ou conta.
- Webhooks só aceitam HTTPS sem credenciais na URL, têm timeout curto, não seguem redirecionamentos e usam assinatura HMAC.
- Um fluxo possui no máximo 50 nós executáveis por rodada, não aceita ciclos e não executa código do usuário.
- Cada execução recebe um snapshot imutável do gatilho, condições, ações e canvas no momento em que é criada. Edições posteriores não mudam uma mensagem já agendada.
- Ao alterar uma regra com execuções aguardando, o administrador pode cancelá-las explicitamente. Sem essa opção, elas terminam com o snapshot da versão que as iniciou.
- Uma oportunidade não pode reentrar na mesma automação enquanto já houver execução ativa. Depois de concluída, a reentrada só acontece se o administrador habilitar a opção correspondente na regra.

## Estados Visíveis

| Estado     | Significado                                                        |
| ---------- | ------------------------------------------------------------------ |
| Em fila    | Evento recebido, ainda não iniciado.                               |
| Executando | Um job está processando os nós.                                    |
| Aguardando | Parado em um nó de espera, com data agendada.                      |
| Concluído  | Chegou ao nó Fim.                                                  |
| Ignorado   | Regra desativada, oportunidade inativa ou envio sem pré-requisito. |
| Falhou     | Erro técnico registrado para diagnóstico.                          |

## Critérios De Aceite P0

- Criar, editar e salvar um fluxo linear válido.
- Criar uma conexão HTTPS e receber a chave de assinatura uma única vez.
- Inserir um nó pelo `+` e manter as conexões válidas depois da inserção.
- Rejeitar fluxo com nó desconhecido, ids duplicados ou conexão inválida.
- Aguardar e retomar na data persistida.
- Executar cada ação comercial com referências válidas.
- Não enviar mensagem sem opt-in, conversa compatível ou janela de WhatsApp.
- Interromper execução pendente quando a regra for desativada ou o card arquivado.
- Mostrar textos da interface em Português Brasil e manter traduções em inglês para a base do produto.
- Funcionar com mouse, teclado e foco visível nos controles do construtor.
- Ao tentar salvar um fluxo inválido, destacar o nó responsável, abrir sua configuração e preservar o restante do canvas para correção.

## Evolução Planejada

### P1

- Prévia do que será alterado ou enviado antes de salvar. Implementado pela ação Testar, sem efeitos colaterais.
- Teste da regra com uma oportunidade selecionada e relatório por nó. Implementado.
- Cancelamento manual de uma execução em espera. Implementado.
- Horários silenciosos e limite de frequência. Implementado para mensagens do fluxo.
- Template oficial de WhatsApp e seleção de idioma. Implementado no nó de mensagem.
- Compositor de mensagem com emoji, busca de variáveis, preview de balão e imagem. Implementado para nós de fluxo e mensagens de aniversário; imagens usam upload assinado, nunca URL externa.
- Histórico visual por oportunidade, com ator e horário. Implementado na linha do tempo da oportunidade.
- Recepção de webhook de entrada, somente com assinatura e mapeamento explícito para oportunidade. Implementado sem código arbitrário: uma conexão inicia somente regras do evento `Webhook recebido` para o card informado. O limite de taxa é configurado na borda de produção (Traefik/API gateway).

### P2

- Nó Condição com caminhos Sim e Não. Implementado.
- Ramificação explícita, sem ciclos implícitos. Implementado para caminhos Sim/Não.
- Nó de data de campo: por exemplo, `Data e hora da consulta - 24h`. Implementado.
- Modelos comerciais por objetivo, iniciados em rascunho e adaptados pelo administrador. Implementado para follow-up, NPS/Google e aniversário.
- Ações de lembrete de consulta reutilizáveis no mesmo canvas. Implementado com nós de data, atraso e horário comercial.
- Importação assistida de workflows do N8N, sempre desativada até revisão humana.

## Referências E Estratégia

### Sistemas que orientam a experiência

| Referência            | O que adotar                                                                                                         | O que evitar                                                            |
| --------------------- | -------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------- |
| HubSpot Workflows     | Separar gatilho de inscrição, condições de reentrada, agenda e saída do fluxo.                                       | Um catálogo enorme de objetos e regras que não existem no Chatwoot.     |
| Pipedrive Automations | Inserção progressiva por `+`, sequência clara de condição/ação/espera e decisão explícita sobre execuções pendentes. | Limites de produto arbitrários e editor espalhado em muitos painéis.    |
| n8n                   | Histórico de execução por etapa, conexões fora do canvas e disciplina para nós de risco.                             | Código, shell, arquivos e HTTP arbitrário dentro de um funil comercial. |

HubSpot documenta gatilhos por evento, filtro, agenda e webhook e trata reentrada como uma configuração explícita. Pipedrive limita a próxima escolha útil a condição, ação ou espera e pede o tratamento das execuções pendentes quando a automação muda. O n8n mostra a importância de registrar execuções e de auditar nós potencialmente perigosos. [HubSpot: criar workflows](https://knowledge.hubspot.com/workflows/create-workflows), [Pipedrive: atraso e pendências](https://support.pipedrive.com/en/article/workflow-automations-delay-feature), [n8n: auditoria de segurança](https://docs.n8n.io/hosting/securing/security-audit/).

### Três lentes de produto

- **Luke Wroblewski:** divulgação progressiva. O administrador vê a próxima escolha útil, não uma parede de blocos e propriedades.
- **Erika Hall:** linguagem e evidência. Cada nó diz o que fará, quais dados utiliza e por que foi ignorado ou falhou.
- **Ryan Singer:** escopo fechado. O módulo resolve processos comerciais recorrentes e delega integrações complexas ao N8N por webhook assinado.

### Plano de produto revisado

**P0 operacional:** gatilhos de oportunidade e de resposta do cliente; nós de espera, horário comercial, condição, mensagem, ação, nota, etiqueta e webhook; conexões HTTPS aprovadas; histórico de execução; canvas com inserção contextual e modal de configuração do nó. O compositor de mensagem permite texto, emoji, campos pesquisáveis e uma imagem com prévia.

Erros de configuração não podem exigir que o administrador procure pelo canvas: a validação seleciona, destaca e abre a etapa que precisa ser corrigida.

**P1 de governança:** snapshot por execução, decisão ao alterar execuções pendentes, reentrada configurável, supressão/saída, teste guiado com uma oportunidade ativa e passos previstos sem efeitos externos, histórico por oportunidade e webhook de entrada autenticado e mapeado a uma oportunidade existente. A publicação formal com rascunho/versionamento visível continua pendente.

**P2 de escala:** tarefas internas com prazo, templates por segmento e integrações declarativas adicionais, sempre por conexão aprovada. O rodízio de responsáveis está implementado como uma ação atômica do fluxo; a central já exibe saúde operacional com falhas e esperas vencidas.

O Vue Flow é a infraestrutura de interação: oferece zoom, seleção, nós/arestas customizados, controles e minimapa. O produto continua responsável pela linguagem comercial, validação e segurança. [Vue Flow](https://vueflow.dev/)

## Métricas

- Quantidade de regras ativas por board.
- Taxa de execuções concluídas, ignoradas e falhas por nó.
- Tempo entre evento e retomada de uma espera.
- Mensagens bloqueadas por falta de opt-in ou janela do WhatsApp.
- Tempo de configuração de uma automação simples pelo administrador.

## Riscos E Decisões

Um canvas permite desenhar fluxos muito mais rápido do que escrever regras, mas também pode esconder complexidade. Por isso, não permite código, valida tudo no servidor e limita o grafo a 50 nós sem ciclos. Integrações externas usam conexões HTTPS separadas e assinadas; não há URL ou segredo solto dentro de um card do fluxo.
