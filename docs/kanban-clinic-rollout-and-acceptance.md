# Aceite Da Clinica E Producao

Status: roteiro de apresentacao e liberacao

## Configuracao Recomendada

1. Crie um board para cada clinica.
2. Em `Configuracoes do funil > Acesso`, selecione `Agentes selecionados` e inclua apenas a secretaria da unidade. A medica administradora ve todos os boards automaticamente.
3. Selecione `Caixas selecionadas` e inclua somente o WhatsApp daquela clinica.
4. Desative `captain_integration` no Super Admin para contas que nao contratam Captain. O menu Captain deixa de aparecer e a rota continua protegida pela feature flag.

## Marca Da Instalacao

O fork usa `RAEVO CRM` como `Installation Name` e `Brand Name`. A marca compacta atende favicon e thumbnail; o logotipo completo atende dashboard, login e dark mode. `Brand URL` e `Widget Brand URL` apontam para `https://chatwt.growautomacao.com.br`, removendo a atribuicao ao Chatwoot em email e widget.

## Roteiro De Aceite

### Operacao Comercial

- Criar oportunidade na conversa e no board.
- Abrir a conversa a partir de um card e retornar pelo atalho da oportunidade no painel lateral.
- Criar duas oportunidades para o mesmo contato e confirmar que cada atalho abre o card correto.
- Editar responsavel, valor, proxima acao e campos personalizados; atualizar a pagina e conferir persistencia.
- Mover entre etapas por arrastar e pela alternativa de teclado; validar campos obrigatorios, ganho e perda.
- Conferir linha do tempo, principalmente `Entrou na etapa`, e a API de timeline.
- Testar filtros, busca, lista, Kanban, arquivamento e restauracao.

### Privacidade E Permissoes

- Entrar como medica: ambos os funis e caixas aparecem.
- Entrar como secretaria A: apenas o board e WhatsApp A aparecem.
- Entrar como secretaria B: apenas o board e WhatsApp B aparecem.
- Tentar abrir pela URL um board sem permissao: a API deve negar e nao retornar cards.
- Tentar criar oportunidade usando inbox fora do escopo: a API deve rejeitar.

### Automacoes E Mensagens

- Executar preview de cada regra antes de publicar.
- Confirmar que mensagens WhatsApp fora de 24 horas exigem template aprovado.
- Confirmar opt-in antes de aniversario ou lembrete externo.
- Testar reagendamento: entregas antigas sao canceladas e novas sao programadas sem duplicidade.
- Testar cadencia: resposta do lead, troca de etapa e conclusao encerram os passos conforme a regra.

## Producao E Escala

- Antes do deploy: backup testado de PostgreSQL, imagem imutavel por SHA, `bundle exec rails db:migrate:status` e smoke da nova imagem em ambiente controlado.
- Depois do deploy: conferir migrations, logs de API/Sidekiq, filas `critical` e `default`, Redis, envio de uma mensagem teste e eventos realtime.
- Concorrencia: dois agentes editam e movem a mesma oportunidade; o segundo recebe recuperacao compreensivel, sem perda silenciosa.
- Volume: testar board com 1.000 cards distribuidos entre etapas, busca, filtro e paginacao; monitorar tempo de resposta, consultas N+1, uso de Redis e latencia de Sidekiq.
- Observabilidade: alertas para erro 5xx, fila crescente, retries de automacao, falha de envio e job acima do tempo esperado.
- Rollback: manter a imagem anterior identificada e restaurar somente o codigo quando nao houver migration irreversivel; para dados alterados, seguir o plano de rollback do banco.

## Criterio De Liberacao

Liberar somente quando todos os cenarios acima estiverem aprovados por uma administradora e uma secretaria de cada unidade, sem erro 5xx, sem vazamento entre boards/inboxes e com as filas de automacao drenando normalmente.
