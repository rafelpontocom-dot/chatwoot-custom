# PRD: Raevo Marketing

## Progresso atual

Fase 1 entregue: captação automática de atribuição, área Marketing, API de
entrada de leads, conexão com o Meta e recepção de Lead Ads.

Falta, e não é código: App Review do `leads_retrieval`, criar o app Meta
separado e preencher as credenciais no Super Admin. Sem isso o Meta não
entrega lead nenhum, por mais correto que o código esteja.

## Decisão de produto

A clínica não sabia, dentro do Raevo, de onde vinha cada paciente. A informação
existia espalhada por workflows de n8n que escreviam em Kommo, LSCRM e planilhas
do Google — nunca chegava ao funil, que é onde a decisão é tomada.

A aba Marketing da oportunidade já tinha os campos certos há meses. O que
faltava não era onde guardar: era quem preenche.

Nenhum fork do Chatwoot faz isto. Nem o `fazer-ai/chatwoot`, o maior fork
brasileiro, tem uma ocorrência de `utm_source`, `leadgen` ou `conversions_api`.

## Problemas

- A origem do lead era digitada à mão, quando era digitada.
- Um anúncio que traz paciente e um que não traz eram indistinguíveis no funil.
- A landing page mandava lead para o Kommo; o Raevo ficava de fora.
- Lead Ads do Facebook exigia digitação manual, enquanto o Kommo criava sozinho.

## Objetivos

1. Toda oportunidade nasce sabendo de onde veio, sem ninguém digitar.
2. Qualquer origem — landing, n8n, parceiro, Meta — entra por uma porta só.
3. A equipe vê a origem no funil, não num relatório à parte.
4. O Raevo substitui gradualmente os workflows de n8n, sem virada de chave.

## Não objetivos

- **Custo e ROAS nesta fase.** Não existe entidade de custo no banco, e mostrar
  retorno sem investimento seria número falso. Vem na Fase 2, via Reportei.
- **Conversions API.** Mandar "virou paciente" de volta ao Meta e ao Google
  depende de captar o click id primeiro, que é o que esta fase resolve.
- **Google Ads e TikTok conectando.** O Reportei já tem essas contas; conectar
  de novo só para ler custo seria trabalho duplicado.

## Princípios

- **Captação é irreversível.** O que não se captura hoje não se recupera amanhã.
  Guardar é barato; por isso a lista branca é generosa e o descarte é tardio.
- **O que já está escrito manda.** O carimbo nunca sobrepõe valor existente:
  quem digitou continua valendo, e o n8n continua ganhando enquanto for a
  autoridade.
- **Nada liga sozinho.** O módulo é opt-in por conta, e os serviços de captação
  verificam isso — subir o código não muda nada para quem não ativou.
- **Antes de prometer ROAS, medir se estamos aprendendo.** A primeira métrica da
  tela é a taxa de captação, não receita.

## Disponibilidade por conta

Opt-in em `marketing_module_settings`, no formato do Financeiro. Módulos Raevo
não entram em `config/features.yml`: quem decide é a conta, não a instalação.

Desligar exige confirmação explícita — a captação para para a conta inteira, e
as origens perdidas nesse intervalo não voltam.

## Personas e jornadas

**Secretária.** Abre a oportunidade e lê na aba Marketing de onde a pessoa veio.
Não configura nada. Vê porque saber a origem faz parte de atender — por isso
`marketing_view` é o padrão do agente, não uma permissão a conceder.

**Gestor de tráfego.** Conecta a conta do Meta, assina as páginas, mapeia os
formulários e cria os tokens de entrada para as landings. Precisa de
`marketing_configure`.

**Integrador (n8n, agência).** Faz `GET /intake/schema`, descobre os campos e
posta. Nunca fala conosco para perguntar qual campo mandar.

## Escopo P0 — entregue

- Captação pelo widget, lendo a URL que ele já reportava.
- Tabela de toques como fonte da verdade, com primeiro e último toque no contato.
- Carimbo na aba Marketing no nascimento da oportunidade.
- Área Marketing: taxa de captação, origens, campanhas, leads recentes.
- API de entrada de leads, auto-descritiva, com token por origem.
- Conexão Meta, assinatura de página, formulários e recepção de leadgen.

## Escopo P1

- Tela de reprocessamento das entregas de webhook.
- Links próprios `/r/:slug` para anúncio que vai direto ao WhatsApp — **pendente
  de decisão**: exige repontar os links dos anúncios, que é trabalho de operação.
- CTWA pelo WAHA, se o spike mostrar que o dado do anúncio sobrevive.

## Escopo P2

- Custo e ROAS via Reportei (Fase 2).
- Conversions API para Meta e Google.
- Atribuição multi-toque, que é quando a tabela de toques passa a ganhar
  histórico em vez de só primeiro e último.

## Telas

**Marketing → Painel.** Taxa de captação em destaque, origens e campanhas com
barra de proporção, leads recentes com contato e oportunidade.

**Marketing → Configurações (engrenagem).** Opt-in, contas de anúncio, páginas
com assinatura de `leadgen`, formulários, e entrada de leads com os tokens.

Google e TikTok aparecem apagados e marcados como "em breve": ausência visível
lê-se como decisão, ausência invisível lê-se como coisa quebrada.

## Métricas de sucesso

- **Taxa de captação** — leads com origem conhecida sobre o total. É a métrica
  honesta de largada, e uma taxa baixa é a lista de anúncios que ainda chegam
  por uma porta que não sabemos ler.
- Leads do Meta criando oportunidade sem digitação.
- Workflows de n8n desligados, um a um.

## Critérios de aceite

- Conversa vinda de URL com UTM gera oportunidade com os campos preenchidos.
- `POST /intake` cria contato e oportunidade; repetir não duplica.
- Lead do Meta chega com campanha, conjunto e anúncio no card.
- Conta sem o módulo ativo não registra nada.
- Agente sem `marketing_view` não vê o ícone nem alcança a API.

## Riscos e decisões em aberto

1. **App Review do Meta** é o caminho crítico e não depende de nós.
2. **A API de entrada é escrita pública.** Token vazado vira contato falso.
   Mitigado por header, revogação imediata, limite e idempotência — e continua
   sendo a superfície mais exposta do módulo.
3. **CTWA pelo WAHA é desconhecido.** Nada depende disso; se falhar, a
   atribuição de WhatsApp fica no que já existe, sem regressão.
4. **Fusão de contatos** perde o `marketing_attribution` do perdedor; as linhas
   de toque sobrevivem e permitem reconstruir.
