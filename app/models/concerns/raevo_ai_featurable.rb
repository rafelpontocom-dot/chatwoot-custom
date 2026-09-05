module RaevoAiFeaturable
  extend ActiveSupport::Concern

  def all_features
    super.merge('raevo_ai' => raevo_ai_integration&.enabled? || false)
  end
end
