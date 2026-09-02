module AccountSettingsSchema
  extend ActiveSupport::Concern

  # A moeda da conta. Um consultório tem uma; Portugal em EUR e Brasil em BRL
  # são contas diferentes, não funis diferentes.
  SUPPORTED_CURRENCIES = %w[BRL EUR USD GBP].freeze

  included do
    validate :validate_currency
  end

  CAPTAIN_MODEL_PROPERTIES = Llm::Models.feature_keys.index_with { { 'type': %w[string null] } }.freeze
  CAPTAIN_FEATURE_PROPERTIES = Llm::Models.feature_keys.index_with { { 'type': %w[boolean null] } }.freeze

  SETTINGS_PARAMS_SCHEMA = {
    'type': 'object',
    'properties':
      {
        'auto_resolve_after': { 'type': %w[integer null], 'minimum': 10, 'maximum': 1_439_856 },
        'auto_resolve_message': { 'type': %w[string null] },
        'auto_resolve_ignore_waiting': { 'type': %w[boolean null] },
        'audio_transcriptions': { 'type': %w[boolean null] },
        'auto_resolve_label': { 'type': %w[string null] },
        'currency': { 'type': %w[string null] },
        'reporting_timezone': { 'type': %w[string null] },
        'keep_pending_on_bot_failure': { 'type': %w[boolean null] },
        'captain_auto_resolve_mode': { 'type': %w[string null], 'enum': ['evaluated', 'legacy', 'disabled', nil] },
        'captain_false_promise_harness_enabled': { 'type': %w[boolean null] },
        'conversation_required_attributes': {
          'type': %w[array null],
          'items': { 'type': 'string' }
        },
        'captain_models': {
          'type': %w[object null],
          'properties': CAPTAIN_MODEL_PROPERTIES,
          'additionalProperties': false
        },
        'captain_features': {
          'type': %w[object null],
          'properties': CAPTAIN_FEATURE_PROPERTIES,
          'additionalProperties': false
        }
      },
    'required': [],
    'additionalProperties': true
  }.to_json.freeze

  private

  def validate_currency
    return if currency.blank? || SUPPORTED_CURRENCIES.include?(currency)

    errors.add(:currency, I18n.t('errors.account.currency.invalid'))
  end
end
