# rubocop:disable Metrics/ClassLength
class ReplaceLegacyKanbanMarketingFields < ActiveRecord::Migration[7.1]
  # Migration data repair intentionally bypasses model validations.
  # rubocop:disable Rails/SkipsModelValidations
  CANONICAL_FIELDS = [
    [
      'origem_do_lead',
      'Origem',
      'select',
      [
        'Mídia Paga',
        'WhatsApp Directo',
        'Indicação',
        'Google',
        'Site',
        'Facebook',
        'Referência Médica',
        'Outro',
        'Orgânico',
        'Parceria'
      ]
    ],
    [
      'sub_origem',
      'Sub-origem',
      'select',
      [
        '[MP] Google',
        '[MP] Meta',
        '[MP] YouTube',
        '[MP] TikTok',
        '[ORG] Google',
        '[ORG] Instagram',
        '[ORG] Facebook',
        '[ORG] Site Direto',
        '[ORG] WhatsApp',
        '[IND] Paciente',
        '[IND] Parceiro',
        '[OUT] Desconhecido'
      ]
    ],
    ['campaign', 'Campanha', 'text', []],
    ['adset', 'Conjunto', 'text', []],
    ['ad', 'Anuncio', 'text', []],
    ['utm_content', 'utm_content', 'text', []],
    ['utm_medium', 'utm_medium', 'text', []],
    ['utm_campaign', 'utm_campaign', 'text', []],
    ['utm_source', 'utm_source', 'text', []],
    ['utm_term', 'utm_term', 'text', []],
    ['utm_referrer', 'utm_referrer', 'text', []],
    ['referrer', 'referrer', 'text', []],
    ['gclientid', 'gclientid', 'text', []],
    ['gclid', 'gclid', 'text', []],
    ['fvclid', 'fvclid', 'text', []],
    ['ttad_name', 'ttad_name', 'text', []],
    ['ttad_id', 'ttad_id', 'text', []],
    ['fbc', 'fbc', 'text', []],
    ['fbp', 'fbp', 'text', []],
    ['ttclid', 'ttclid', 'text', []],
    ['campaign_id', 'campaign_id', 'text', []],
    ['adset_id', 'adset_id', 'text', []],
    ['ad_id', 'ad_id', 'text', []],
    ['landing_page', 'landing_page', 'url', []],
    ['event_id', 'event_id', 'text', []],
    ['landing_page_full', 'landing_page_full', 'textarea', []]
  ].freeze

  LEGACY_ALIASES = {
    'campaign_name' => 'campaign',
    'adset_name' => 'adset',
    'ad_name' => 'ad',
    'google_client_id' => 'gclientid',
    'tiktok_ad_id' => 'ttad_id',
    'tiktok_ad_name' => 'ttad_name',
    'fbclid' => 'fvclid'
  }.freeze

  OBSOLETE_KEYS = %w[utm_id gbraid wbraid dclid msclkid].freeze

  def up
    KanbanBoard.reset_column_information

    KanbanBoard.unscoped.find_each do |board|
      definitions = Array(board.custom_field_definitions)
      next unless marketing_preset_present?(definitions)

      normalized_definitions, renamed_keys = normalize_definitions(definitions)
      compact_keys = normalize_compact_keys(board.compact_card_field_keys, renamed_keys)

      board.update_columns(
        custom_field_definitions: normalized_definitions,
        compact_card_field_keys: compact_keys,
        updated_at: Time.current
      )
      migrate_card_values(board, renamed_keys)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def canonical_keys
    @canonical_keys ||= CANONICAL_FIELDS.map(&:first)
  end

  def marketing_preset_present?(definitions)
    definitions.any? do |definition|
      next false unless marketing_definition?(definition)

      key = definition['key'].to_s
      canonical_keys.include?(key) ||
        LEGACY_ALIASES.key?(key) ||
        OBSOLETE_KEYS.include?(key)
    end
  end

  def marketing_definition?(definition)
    layout = definition['layout'] || {}
    layout['section'].to_s == 'marketing'
  end

  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
  def normalize_definitions(definitions)
    normalized = []
    seen_keys = []
    renamed_keys = {}
    position = 1

    definitions.each do |definition|
      key = definition['key'].to_s
      canonical_key = LEGACY_ALIASES.fetch(key, key)
      unless marketing_definition?(definition) && marketing_key?(canonical_key, key)
        normalized << definition
        next
      end

      next if OBSOLETE_KEYS.include?(key) || seen_keys.include?(canonical_key)

      preset = CANONICAL_FIELDS.find { |field| field.first == canonical_key }
      next unless preset

      normalized << normalized_definition(definition, preset, position)
      renamed_keys[key] = canonical_key if key != canonical_key
      seen_keys << canonical_key
      position += 1
    end

    CANONICAL_FIELDS.each do |preset|
      next if seen_keys.include?(preset.first)

      normalized << normalized_definition({}, preset, position)
      position += 1
    end

    [normalized, renamed_keys]
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

  def marketing_key?(canonical_key, original_key)
    canonical_keys.include?(canonical_key) ||
      LEGACY_ALIASES.key?(original_key) ||
      OBSOLETE_KEYS.include?(original_key)
  end

  def normalized_definition(source, preset, position)
    key, label, field_type, options = preset
    {
      'key' => key,
      'label' => label,
      'field_type' => field_type,
      'options' => options,
      'required_stage_ids' => Array(source['required_stage_ids']).map(&:to_i).uniq,
      'important' => ActiveModel::Type::Boolean.new.cast(source['important']),
      'condition' => source['condition'].is_a?(Hash) ? source['condition'] : {},
      'formula' => nil,
      'formula_result_type' => nil,
      'layout' => {
        'section' => 'marketing',
        'position' => position,
        'width' => key == 'landing_page_full' ? 'full' : 'half'
      }
    }
  end

  def normalize_compact_keys(keys, renamed_keys)
    Array(keys).filter_map do |key|
      canonical_key = renamed_keys.fetch(key.to_s, key.to_s)
      next if OBSOLETE_KEYS.include?(canonical_key)

      canonical_key
    end.uniq
  end

  # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  def migrate_card_values(board, renamed_keys)
    board.kanban_cards.find_each do |card|
      values = (card.custom_field_values || {}).stringify_keys
      changed = false

      renamed_keys.each do |legacy_key, canonical_key|
        next unless values.key?(legacy_key)
        next if values.key?(canonical_key) && values[canonical_key].present?

        values[canonical_key] = values[legacy_key]
        values.delete(legacy_key)
        changed = true
      end

      OBSOLETE_KEYS.each do |key|
        changed ||= values.delete(key).present?
      end

      card.update_columns(custom_field_values: values, updated_at: Time.current) if changed
    end
  end
  # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  # rubocop:enable Rails/SkipsModelValidations
end
# rubocop:enable Metrics/ClassLength
