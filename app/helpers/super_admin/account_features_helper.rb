module SuperAdmin::AccountFeaturesHelper
  def self.account_features
    YAML.safe_load(Rails.root.join('config/features.yml').read).freeze
  end

  def self.account_premium_features
    account_features.filter { |feature| feature['premium'] }.pluck('name')
  end

  # As que o `Internal::ReconcilePlanConfigService` desliga todas as noites num
  # plano `community` — que não é a mesma lista do `premium: true`.
  #
  # A caixa do Super Admin ficava cinzenta para TUDO o que fosse `premium`, e
  # por isso era impossível ligar uma funcionalidade que o job já não volta a
  # desligar. Cinzento deve dizer «não adianta, vai ser desfeito», e não «é
  # pago»: a segunda leitura mentia depois de tirarmos `custom_roles` da lista.
  def self.reconciled_premium_features
    path = Rails.root.join('enterprise/config/premium_features.yml')
    return account_premium_features unless File.exist?(path)

    YAML.safe_load(path.read).freeze
  end

  # Returns a hash mapping feature names to their display names
  def self.feature_display_names
    account_features.each_with_object({}) do |feature, hash|
      hash[feature['name']] = feature['display_name']
    end
  end

  def self.filter_internal_features(features)
    return features if ChatwootApp.chatwoot_cloud?

    internal_features = account_features.select { |f| f['chatwoot_internal'] }.pluck('name')
    features.except(*internal_features)
  end

  def self.filter_deprecated_features(features)
    deprecated_features = account_features.select { |f| f['deprecated'] }.pluck('name')
    features.except(*deprecated_features)
  end

  def self.sort_and_transform_features(features, display_names)
    features.sort_by { |key, _| display_names[key] || key }
            .to_h
            .transform_keys { |key| [key, display_names[key]] }
  end

  def self.partition_features(features)
    filtered = filter_internal_features(features)
    filtered = filter_deprecated_features(filtered)
    display_names = feature_display_names

    regular, premium = filtered.partition { |key, _value| account_premium_features.exclude?(key) }

    [
      sort_and_transform_features(regular, display_names),
      sort_and_transform_features(premium, display_names)
    ]
  end

  def self.filtered_features(features)
    regular, premium = partition_features(features)
    regular.merge(premium)
  end
end
