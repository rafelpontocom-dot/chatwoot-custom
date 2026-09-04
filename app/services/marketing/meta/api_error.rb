class Marketing::Meta::ApiError < StandardError
  # `reason` e uma chave estavel que a tela traduz. A mensagem crua do Meta
  # pode citar conta alheia e nunca chega ao browser; o codigo, sim, porque e
  # ele que diz o que a pessoa tem de ir arrumar.
  REASONS = {
    10 => 'permission', 200 => 'permission', 299 => 'permission',
    102 => 'token_expired', 190 => 'token_expired', 2500 => 'token_expired',
    4 => 'rate_limit', 17 => 'rate_limit', 32 => 'rate_limit', 613 => 'rate_limit'
  }.freeze

  attr_reader :reason

  def initialize(message, code: nil)
    super(message)
    @reason = REASONS[code]
  end
end
