# == Schema Information
#
# Table name: form_templates
#
#  id                    :bigint           not null, primary key
#  access_classification :string           default("commercial"), not null
#  category              :string           default("lead_capture"), not null
#  name                  :string           not null
#  public_enabled        :boolean          default(FALSE), not null
#  public_token          :string
#  settings              :jsonb            not null
#  slug                  :string           not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  account_id            :bigint           not null
#  active_version_id     :bigint
#
# Indexes
#
#  index_form_templates_on_account_id           (account_id)
#  index_form_templates_on_account_id_and_slug  (account_id,slug) UNIQUE
#  index_form_templates_on_active_version_id    (active_version_id)
#  index_form_templates_on_public_token         (public_token) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (active_version_id => form_template_versions.id)
#
class FormTemplate < ApplicationRecord
  CATEGORIES = %w[lead_capture pre_consultation clinical consent other].freeze
  ACCESS_CLASSIFICATIONS = %w[commercial restricted sensitive_health].freeze

  belongs_to :account
  belongs_to :active_version, class_name: 'FormTemplateVersion', optional: true

  has_many :form_template_versions, dependent: :destroy

  validates :name, :slug, presence: true
  validates :slug, uniqueness: { scope: :account_id }
  validates :public_token, uniqueness: true, allow_nil: true
  validates :public_token, presence: true, if: :public_enabled?
  validates :category, inclusion: { in: CATEGORIES }
  validates :access_classification, inclusion: { in: ACCESS_CLASSIFICATIONS }
  validate :active_version_belongs_to_template
  validate :sensitive_health_not_public
  before_validation :assign_public_token
  before_destroy :clear_active_version, prepend: true

  def publish!(schema:)
    with_lock do
      version = form_template_versions.create!(
        account: account,
        version_number: next_version_number,
        schema: schema,
        published_at: Time.current
      )
      update!(active_version: version)
      version
    end
  end

  def sensitive_health?
    access_classification == 'sensitive_health'
  end

  def admin_payload
    {
      id: id,
      name: name,
      slug: slug,
      category: category,
      access_classification: access_classification,
      public_enabled: public_enabled,
      public_token: public_token,
      settings: settings,
      active_version: active_version&.admin_payload,
      created_at: created_at,
      updated_at: updated_at
    }
  end

  private

  def next_version_number
    form_template_versions.maximum(:version_number).to_i + 1
  end

  def assign_public_token
    self.public_token ||= SecureRandom.urlsafe_base64(24)
  end

  def active_version_belongs_to_template
    return if active_version.blank? || active_version.form_template_id == id

    errors.add(:active_version, :invalid)
  end

  def sensitive_health_not_public
    return unless sensitive_health? && public_enabled?

    errors.add(:public_enabled, 'cannot be enabled for sensitive health forms')
  end

  def clear_active_version
    update!(active_version: nil) if active_version_id.present?
  end
end
