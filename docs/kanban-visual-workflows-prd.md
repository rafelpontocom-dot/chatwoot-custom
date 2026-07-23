# PRD: Fluxos Visuais Do Kanban

## Contexto

O Kanban comercial do Chatwoot precisa automatizar etapas repetitivas de venda sem transferir a equipe para N8N, Kommo ou planilhas. O administrador deve conseguir entender uma regra olhando para um fluxo, enquanto a equipe comercial recebe ações claras e auditáveis na oportunidade.

O produto não é um clone genérico de ferramentas de automação. Ele é um construtor de processos comerciais limitado aos dados, permissões e canais que o board já conhece.

## Objetivo

Permitir que administradores criem automações lineares e seguras para oportunidades: iniciar por um evento comercial, esperar, enviar uma mensagem compatível ou executar uma ação no card.

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

1. O administrador abre Configurações do board > Automações > Regra comercial.
2. Define nome, evento e condições de entrada no formulário da regra.
3. Abre o Construtor visual e monta o caminho da automação.
4. Seleciona um nó para configurar seu conteúdo no painel lateral.
5. Salva. O backend valida todos os nós antes de ativar a regra.
6. Quando o evento ocorre, a execução fica registrada no histórico da regra.
7. Se houver uma espera, o card segue operando normalmente; a execução retoma no horário salvo.

## Nós Da Primeira Entrega

| Nó | Finalidade | Configuração obrigatória |
| --- | --- | --- |
| Gatilho | Início visual do fluxo; o evento continua configurado na regra. | Um por fluxo. |
| Aguardar | Pausa a execução por horas. | Número positivo de horas. |
| Enviar mensagem | Envia WhatsApp ou e-mail na conversa compatível do contato. | Canal, opt-in e texto. |
| Ação comercial | Atualiza a oportunidade. | Tipo e parâmetros da ação. |
| Fim | Encerra o caminho. | Nenhuma. |

As ações comerciais disponíveis são: mover etapa, definir responsável, criar próxima ação, preencher campo personalizado e arquivar oportunidade.

## Regras De Mensagem Externa

- Mensagem exige opt-in explícito no atributo do contato configurado pelo administrador.
- WhatsApp usa uma conversa compatível e somente envia quando ela pode receber resposta livre.
- Fora da janela de 24 horas, a execução é marcada como ignorada. Templates oficiais entram em etapa posterior.
- E-mail exige uma conversa de e-mail compatível.
- Ausência de conversa, opt-in ou janela não causa repetição infinita: fica registrada como `skipped` no histórico e o fluxo continua.
- A mensagem permite a variável inicial `{{contact_name}}`.

## Regras De Confiabilidade

- Uma execução é idempotente por regra e evento comercial.
- Esperas são persistidas; nenhum processo fica aberto aguardando tempo.
- Desativar a regra antes da retomada impede a continuidade e registra a execução como ignorada.
- Arquivar a oportunidade antes da retomada também interrompe o fluxo.
- A configuração deve rejeitar referências a etapas, agentes e campos fora do board ou conta.

## Estados Visíveis

| Estado | Significado |
| --- | --- |
| Em fila | Evento recebido, ainda não iniciado. |
| Executando | Um job está processando os nós. |
| Aguardando | Parado em um nó de espera, com data agendada. |
| Concluído | Chegou ao nó Fim. |
| Ignorado | Regra desativada, oportunidade inativa ou envio sem pré-requisito. |
| Falhou | Erro técnico registrado para diagnóstico. |

## Critérios De Aceite P0

- Criar, editar e salvar um fluxo linear válido.
- Rejeitar fluxo com nó desconhecido, ids duplicados ou conexão inválida.
- Aguardar e retomar na data persistida.
- Executar cada ação comercial com referências válidas.
- Não enviar mensagem sem opt-in, conversa compatível ou janela de WhatsApp.
- Interromper execução pendente quando a regra for desativada ou o card arquivado.
- Mostrar textos da interface em Português Brasil e manter traduções em inglês para a base do produto.
- Funcionar com mouse, teclado e foco visível nos controles do construtor.

## Evolução Planejada

### P1

- Prévia do que será alterado ou enviado antes de salvar. Implementado pela ação Testar, sem efeitos colaterais.
- Teste da regra com uma oportunidade selecionada e relatório por nó. Implementado.
- Cancelamento manual de uma execução em espera. Implementado.
- Horários silenciosos e limite de frequência.
- Template oficial de WhatsApp e seleção de idioma.
- Histórico visual por oportunidade, com ator e horário.

### P2

- Nó Condição com caminhos Sim e Não. Implementado.
- Ramificação explícita, sem ciclos implícitos. Implementado para caminhos Sim/Não.
- Nó de data de campo: por exemplo, `Data e hora da consulta - 24h`. Implementado.
- Ações de cadência de follow-up e lembrete de consulta no mesmo canvas.
- Importação assistida de workflows do N8N, sempre desativada até revisão humana.

## Métricas

- Quantidade de regras ativas por board.
- Taxa de execuções concluídas, ignoradas e falhas por nó.
- Tempo entre evento e retomada de uma espera.
- Mensagens bloqueadas por falta de opt-in ou janela do WhatsApp.
- Tempo de configuração de uma automação simples pelo administrador.

## Riscos E Decisões

Um canvas permite desenhar fluxos muito mais rápido do que escrever regras, mas também pode esconder complexidade. Por isso, a primeira versão é linear, não permite código e valida tudo no servidor. Condições, ramificações e integrações externas só entram com prévia, limites e trilha de auditoria.
