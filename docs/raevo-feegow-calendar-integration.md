# Feegow e a agenda do Raevo

Estado em 2026-09-16. Fase 1 feita e no git (`220d4c9f4`), por subir.

## O problema

A clínica marca no Feegow e a secretária marca no Raevo. As duas agendas não se
falavam, e o CRM deixava marcar em cima de uma consulta que já existia no
prontuário.

## O que já existia antes desta fase

| O quê | Onde | Estado |
| --- | --- | --- |
| A IA marca no Feegow (exige nome completo + CPF) | `ELIS IA RAEVO/apps/agents-volt/src/tools/calcom.ts`, ação `criar_agendamento` | Em produção desde 2026-06-08 |
| Cliente Feegow completo (paciente, disponibilidade, marcar, cancelar, catálogos) | `apps/agents-volt/src/tools/feegow-client.ts` | Em produção |
| Volta do status **só** do que a IA criou e ligou a uma conversa | `apps/agents-volt/src/calendar-sync/feegow-calendar-sync.ts` | Script manual, sem agendador |
| Consulta vinda de fora é só-leitura no Raevo | `source_read_only` em `KanbanCalendarAppointment` | Em produção |

O sync antigo **não** tenta casar paciente por semelhança — é decisão
deliberada, registada no próprio código.

## Decisões tomadas com o Pedro (2026-09-16)

1. **Feegow → Raevo primeiro.** Nada é escrito no prontuário nesta fase.
2. **Ligação direta à API.** O n8n fica para o que a API não cobre; não entra no
   caminho de marcar nem de sincronizar.
3. **Token no Raevo, por conta**, com validade à vista e aviso antes de vencer.
4. **CPF** só será exigido quando a marcação for espelhada no Feegow — fase 2.

## O que foi feito na fase 1

- **Bloqueio de horário deixou de ser «do Google».** `kanban_calendar_external_busy_blocks`
  ganhou `provider`, a chave única passou a (agenda, provedor, id externo) e a
  coluna da conexão Google saiu. É cache: cada importação reconstrói a janela.
- **`KanbanCalendarFeegowConnection`** — uma por conta: `api_url`, `api_token`
  encriptado, `token_expires_at`, `status`, `last_error`, `last_imported_at`.
- **`KanbanCalendar::FeegowClient`** — só leitura: `/appoints/search` (com
  paginação), `/professional/list`, `/company/list-unity`. Cabeçalho
  `x-access-token`.
- **`KanbanCalendar::FeegowImportService`** — janela de 1 dia atrás a 180 à
  frente, por profissional mapeado; reimporta a janela inteira e apaga o que já
  não veio (trata remarcado e cancelado); ignora status cancelado/faltou;
  duração do Feegow ou 30 min.
- **Mapa agenda ↔ profissional** em `kanban_calendar_resources.settings['feegow']`.
  Agenda sem mapa não importa nada.
- **Jobs** `ImportFeegowCalendarJob` e `ImportAllFeegowCalendarsJob`, chamados
  pelo `TriggerScheduledItemsJob` a cada 5 minutos, ao lado do Google.
- **Tela** em Configurações › Agendas: token, validade («vence em N dias», âmbar
  a 14 dias, vermelho depois), «Sincronizar agora», última importação, erro do
  Feegow e o seletor «Profissional no Feegow» em cada agenda.
- **Privacidade:** guarda-se só o intervalo. Nome de paciente não entra.

### Verificado

Feegow falso + Sidekiq real: consulta cancelada ignorada; horários do Dr. Bruno
passaram de 09:00 e 11:00 para só 11:00; marcar às 09:00 recusado com
`ConflictError`; bloqueios de Google e Feegow convivem na mesma agenda.
1.748 specs de backend e 711 de frontend verdes.

### Migrations

- `20260916120000_add_provider_to_calendar_busy_blocks`
- `20260916121000_create_kanban_calendar_feegow_connections`

## Como ligar numa clínica

1. Configurações › Agendas › Feegow: colar o token e, se souber, a validade
   (vazio assume 90 dias).
2. Em cada agenda, escolher o profissional correspondente no Feegow.
3. «Sincronizar agora». O erro do Feegow, se houver, aparece ali.

## Fase 2 — desenhada, não construída

- **Raevo → Feegow:** marcar/cancelar no CRM cria/cancela no prontuário,
  guardando o `agendamento_id`.
- **CPF:** atributo do contato, exigido **apenas** quando a agenda espelha no
  Feegow. O cliente do runtime já procura paciente por CPF antes de criar, o que
  evita duplicado.
- **Quem manda:** o que nasce no Feegow muda no Feegow (`source_read_only`).

## Riscos conhecidos

- **Sem webhook** documentado: a importação é por sondagem de 5 em 5 minutos.
  Mudança no prontuário aparece no Raevo em até 5 minutos.
- **Limite de chamadas** desconhecido: uma chamada por profissional mapeado por
  ciclo, com paginação. Se o Feegow reclamar, o intervalo sobe.
- **Token de 90 dias** é o ponto frágil: sem aviso, a agenda pára em silêncio.
- **Uma conta = uma clínica** nesta fase; o token é da conta.
