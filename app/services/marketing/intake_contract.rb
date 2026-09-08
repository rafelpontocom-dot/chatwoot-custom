# O contrato da entrada de leads, num sítio só.
#
# A porta pública e a documentação dentro do produto leem daqui. Enquanto o
# painel descrevia a API por conta própria, faltava-lhe o essencial — o nome do
# header — e um token válido enviado em `Authorization: Bearer` respondia 401
# indistinguível de token inválido. Documentação que se escreve à parte do
# código diverge dele; esta não pode.
class Marketing::IntakeContract
  TOKEN_HEADER = 'X-Raevo-Intake-Token'.freeze
  PATH = '/public/api/v1/marketing/intake'.freeze
  RATE_LIMIT_PER_MINUTE = Marketing::IntakeRateLimiter::LIMIT

  def self.fields
    {
      contact: %w[name email phone_number],
      opportunity: %w[subject],
      control: %w[idempotency_key],
      attribution: Marketing::AttributionFields::ALL_KEYS
    }
  end

  def self.notes
    {
      identity: 'email or phone_number is required',
      idempotency: 'send idempotency_key to make a retry a no-op',
      max_value_length: Marketing::AttributionFields::MAX_VALUE_LENGTH
    }
  end

  # O que o painel precisa para desenhar a documentação sem inventar nada.
  def self.reference
    {
      token_header: TOKEN_HEADER,
      path: PATH,
      rate_limit_per_minute: RATE_LIMIT_PER_MINUTE,
      fields: fields,
      notes: notes
    }
  end
end
