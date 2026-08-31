# == Schema Information
#
# Table name: form_template_versions
#
#  id               :bigint           not null, primary key
#  published_at     :datetime         not null
#  schema           :jsonb            not null
#  version_number   :integer          not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  account_id       :bigint           not null
#  form_template_id :bigint           not null
#
# Indexes
#
#  idx_form_template_versions_unique           (form_template_id,version_number) UNIQUE
#  index_form_template_versions_on_account_id  (account_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (form_template_id => form_templates.id)
#
class FormTemplateVersion < ApplicationRecord
  belongs_to :account
  belongs_to :form_template
  has_many :form_invitations, dependent: :restrict_with_exception
  has_many :form_submissions, dependent: :restrict_with_exception

  validates :version_number, numericality: { only_integer: true, greater_than: 0 }, uniqueness: { scope: :form_template_id }
  validates :published_at, presence: true
  validate :template_belongs_to_account
  validate :schema_has_sections
  validate :sensitive_health_schema_requirements
  before_update :prevent_mutation

  def admin_payload
    {
      id: id,
      version_number: version_number,
      schema: schema,
      published_at: published_at
    }
  end

  def history_payload
    {
      id: id,
      version_number: version_number,
      published_at: published_at
    }
  end

  private

  def template_belongs_to_account
    return if account.blank? || form_template.blank?
    return if account_id == form_template.account_id

    errors.add(:form_template, :invalid)
  end

  def schema_has_sections
    validator = Forms::SchemaValidator.new(schema, **template_validation_flags)
    return if validator.valid?

    validator.errors.each { |error| errors.add(:schema, error) }
  end

  # As três bandeiras saem todas do template; agrupá-las tira a ramificação de
  # dentro da validação e deixa uma coisa só para ler.
  def template_validation_flags
    clinico = form_template&.sensitive_health? || false
    {
      require_public_contact_mapping: (form_template&.public_enabled? && !clinico) || false,
      require_crm_destination: form_template&.access_classification == 'commercial',
      sensitive_health: clinico
    }
  end

  def sensitive_health_schema_requirements
    return unless form_template&.sensitive_health?

    validate_sensitive_health_encryption
    validate_sensitive_health_consent
    validate_sensitive_health_crm_isolation
  end

  def validate_sensitive_health_encryption
    return if Forms::SensitiveAnswerCipher.configured?

    errors.add(:schema, 'requires application encryption to be configured')
  end

  def validate_sensitive_health_consent
    return if sensitive_health_consent.present?

    errors.add(:schema, 'must include a required clinical consent')
  end

  def validate_sensitive_health_crm_isolation
    return if schema['crm_destination'].blank? && schema['crm_mapping'].blank?

    errors.add(:schema, 'cannot include CRM mapping or destination for sensitive health forms')
  end

  def sensitive_health_consent
    schema.fetch('sections', []).flat_map { |section| section.fetch('fields', []) }
          .find { |field| field['type'] == 'consent' && field['required'] == true }
  end

  def prevent_mutation
    errors.add(:base, 'published versions are immutable')
    throw(:abort)
  end
end
