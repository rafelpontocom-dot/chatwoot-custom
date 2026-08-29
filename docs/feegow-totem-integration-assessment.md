# Avaliação de Integração: Totem Feegow

Status: validado tecnicamente, aguarda contrato/API Feegow

## Objetivo

Substituir somente a experiência visual do totem de senha por uma interface RAEVO personalizável, preservando a operação de fila no Feegow.

## Evidências da validação

Em 28 de agosto de 2026, a página pública do totem foi inspecionada sem emitir senha ou alterar dados.

- A página entrega no HTML a lista pública de opções/filas, seus nomes e cores.
- Ao selecionar uma opção, o navegador faz um `POST` para um endpoint Feegow de impressão/emissão de senha.
- O aplicativo macOS baixado é um atalho de aplicativo Chrome para a mesma URL; não contém integração, código de fila ou configuração adicional.
- O endpoint aceita `POST`, mas o preflight de uma origem externa não retorna `Access-Control-Allow-Origin`. Um frontend hospedado em domínio RAEVO não consegue chamá-lo diretamente no navegador.
- O módulo também prepara cabeçalho CSRF e mantém sessão do domínio Feegow. Reproduzir cookies, CSRF ou HTML em um proxy seria acoplamento não homologado e não é caminho de produção.

## Decisão

Não criar um clone que faça scraping/proxy do totem atual nem uma extensão que injete CSS. Esses caminhos quebram com mudanças do Feegow, dificultam suporte e criam risco operacional/LGPD.

O Totem RAEVO é viável se a clínica obtiver da Feegow uma das alternativas abaixo, em ordem de preferência:

1. API oficial para listar filas e emitir senha, autenticada por credencial da clínica.
2. Endpoint homologado de emissão com token de integração restrito ao totem.
3. Webhook/evento de fila para o RAEVO confirmar a emissão e apresentar a senha corretamente.

## Arquitetura proposta

1. **Totem RAEVO público**: interface em modo tela cheia, com identidade da clínica, botões grandes, acessibilidade, temporizador de retorno e impressão.
2. **Servidor RAEVO**: guarda credencial da clínica cifrada, lista procedimentos/filas autorizadas e solicita a senha ao Feegow. Nenhum segredo vai para o navegador.
3. **Evento/auditoria**: grava somente identificador local, fila, instante, resultado e número de senha quando devolvido pelo provedor; não registra dados de saúde desnecessários.
4. **Fallback operacional**: falha do provedor mostra orientação objetiva para recepção e não confirma senha sem resposta do Feegow.

## Escopo de prova de conceito

- Uma clínica e uma unidade.
- Lista de filas/procedimentos autorizados.
- Emissão de uma senha por ação.
- Tela de confirmação e impressão opcional.
- Retorno automático à tela inicial.
- Logs técnicos sanitizados e painel simples de saúde da integração.

## Critérios de aceite

- O totem RAEVO nunca emite ou mostra senha localmente antes da confirmação do Feegow.
- Uma ação de toque gera no máximo uma solicitação externa, com bloqueio temporário contra duplo toque.
- O totem funciona sem sessão/cookie do domínio Feegow no navegador.
- A credencial do Feegow não aparece em HTML, JavaScript, logs do navegador ou URL.
- Quando o serviço externo falha, nenhuma senha é inventada e a recepção recebe uma instrução clara.

## Próximo passo necessário

Solicitar à Feegow a documentação ou habilitação de API para totem/fila, incluindo:

- autenticação suportada;
- consulta de filas/opções por unidade;
- emissão de senha;
- retorno do número/posição/status;
- limites de uso, idempotência e ambiente de teste;
- webhook/eventos, se disponíveis.
