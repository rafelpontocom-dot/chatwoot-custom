# Entrega o aviso de resposta ao endereço que a clínica configurou.
#
# Fora do pedido de propósito: um destino lento ou em baixo não pode segurar a
# submissão do paciente, que já está guardada e não se pode perder.
class Forms::SubmissionWebhookJob < ApplicationJob
  queue_as :low
  # Só três tentativas: se o destino esteve em baixo uma tarde inteira, insistir
  # para sempre enche a fila sem entregar nada.
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  TIMEOUT = 5

  def perform(url, payload)
    uri = URI.parse(url)
    return unless uri.scheme == 'https' && uri.host.present?

    HTTParty.post(
      url,
      body: payload.to_json,
      headers: { 'Content-Type' => 'application/json' },
      timeout: TIMEOUT
    )
  end
end
