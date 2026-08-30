module ApplicationHelper
  # Raevo — o produto é vendido em português e só oferece português.
  # O `en` continua registado em `Rails.configuration.i18n.available_locales`
  # porque é o `default_locale` e o alvo de `config.i18n.fallbacks`: removê-lo
  # dali levantaria I18n::InvalidLocale. O que muda aqui é só o que a pessoa vê
  # no seletor de idioma — do painel e do widget.
  RAEVO_LOCALES = %w[pt_BR pt].freeze

  def available_locales_with_name
    LANGUAGES_CONFIG
      .map { |_key, val| val.slice(:name, :iso_639_1_code) }
      .select { |lang| RAEVO_LOCALES.include?(lang[:iso_639_1_code]) }
      .sort_by { |lang| RAEVO_LOCALES.index(lang[:iso_639_1_code]) }
  end

  def feature_help_urls
    features = YAML.safe_load(Rails.root.join('config/features.yml').read).freeze
    features.each_with_object({}) do |feature, hash|
      hash[feature['name']] = feature['help_url'] if feature['help_url']
    end
  end
end
