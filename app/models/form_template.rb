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
  BRAND_LOGO_CONTENT_TYPES = %w[image/jpeg image/png image/webp].freeze
  BRAND_LOGO_MAX_SIZE = 2.megabytes
  CONTENT_IMAGE_MAX_SIZE = 5.megabytes

  include Rails.application.routes.url_helpers

  belongs_to :account
  belongs_to :active_version, class_name: 'FormTemplateVersion', optional: true

  has_many :form_template_versions, dependent: :destroy
  # As respostas ficam presas à versão que as recebeu, não ao template: uma
  # publicação nova não pode reescrever o que já foi respondido.
  has_many :form_submissions, through: :form_template_versions
  has_one_attached :brand_logo
  has_many_attached :content_images

  validates :name, :slug, presence: true
  validates :slug, uniqueness: { scope: :account_id }
  validates :public_token, uniqueness: true, allow_nil: true
  validates :public_token, presence: true, if: :public_enabled?
  validates :category, inclusion: { in: CATEGORIES }
  validates :access_classification, inclusion: { in: ACCESS_CLASSIFICATIONS }
  validate :active_version_belongs_to_template
  validate :sensitive_health_not_public
  validate :public_form_contact_mapping
  validate :clinical_access_belongs_to_account
  validate :clinical_retention_is_valid
  validate :abandonment_delay_is_valid
  validate :critical_response_is_valid
  validate :public_captcha_is_valid
  validate :brand_logo_is_valid
  validate :content_images_are_valid
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

  def clinical_retention_days
    return unless sensitive_health?

    Integer(settings&.fetch('clinical_retention_days', nil), exception: false)
  end

  def abandonment_delay_hours
    return if sensitive_health?

    Integer(settings&.fetch('abandonment_delay_hours', nil), exception: false)
  end

  def critical_response_rule
    return if sensitive_health?

    settings&.fetch('critical_response', {}).to_h.stringify_keys
  end

  def public_captcha_provider
    settings&.fetch('captcha_provider', nil).presence
  end

  def public_captcha_site_key
    settings&.fetch('captcha_site_key', nil).to_s.strip.presence
  end

  def clinical_access_user_ids
    clinical_access_ids('user_ids')
  end

  def clinical_access_team_ids
    clinical_access_ids('team_ids')
  end

  def clinically_accessible_to?(user)
    return false unless sensitive_health? && user.present?
    return true if clinical_access_user_ids.include?(user.id)

    user.teams.where(account_id: account_id).exists?(id: clinical_access_team_ids)
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
      brand_logo_url: brand_logo_url,
      settings: settings,
      active_version: active_version&.admin_payload,
      submissions_count: form_submissions.count,
      created_at: created_at,
      updated_at: updated_at
    }
  end

  def brand_logo_url
    return unless brand_logo.attached?

    rails_blob_path(brand_logo, only_path: true)
  end

  def content_image_url(image)
    rails_blob_path(image, only_path: true)
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

  def public_form_contact_mapping
    return unless public_enabled? && active_version.present? && !sensitive_health?

    validator = Forms::SchemaValidator.new(
      active_version.schema,
      require_public_contact_mapping: true
    )
    return if validator.valid?

    validator.errors.each { |error| errors.add(:active_version, error) }
  end

  def clinical_access_belongs_to_account
    return unless sensitive_health?

    invalid_users = clinical_access_user_ids - account.users.where(id: clinical_access_user_ids).pluck(:id)
    invalid_teams = clinical_access_team_ids - account.teams.where(id: clinical_access_team_ids).pluck(:id)

    errors.add(:settings, 'contains a user outside this account') if invalid_users.any?
    errors.add(:settings, 'contains a team outside this account') if invalid_teams.any?
  end

  def clinical_retention_is_valid
    return unless sensitive_health?
    return if settings&.fetch('clinical_retention_days', nil).blank?
    return if clinical_retention_days.to_i.positive?

    errors.add(:settings, 'clinical retention must be at least one day')
  end

  def abandonment_delay_is_valid
    return if sensitive_health? || settings&.fetch('abandonment_delay_hours', nil).blank?
    return if abandonment_delay_hours.to_i.between?(1, 720)

    errors.add(:settings, 'abandonment delay must be between one hour and thirty days')
  end

  def critical_response_is_valid
    validator = Forms::CriticalResponseRuleValidator.new(self)
    return if validator.valid?

    validator.errors.each { |error| errors.add(:settings, error) }
  end

  def public_captcha_is_valid
    return if public_captcha_provider.blank?

    errors.add(:settings, 'captcha provider is invalid') unless public_captcha_provider == 'turnstile'
    errors.add(:settings, 'captcha site key is required') if public_captcha_site_key.blank?
  end

  def brand_logo_is_valid
    return unless brand_logo.attached?

    errors.add(:brand_logo, 'is too big') if brand_logo.byte_size > BRAND_LOGO_MAX_SIZE
    return if BRAND_LOGO_CONTENT_TYPES.include?(brand_logo.content_type)

    errors.add(:brand_logo, 'filetype not supported')
  end

  def content_images_are_valid
    content_images.each do |image|
      errors.add(:content_images, 'is too big') if image.byte_size > CONTENT_IMAGE_MAX_SIZE
      next if BRAND_LOGO_CONTENT_TYPES.include?(image.content_type)

      errors.add(:content_images, 'filetype not supported')
    end
  end

  def clinical_access_ids(key)
    Array(settings&.dig('clinical_access', key)).filter_map do |value|
      Integer(value, exception: false)
    end.uniq
  end

  def clear_active_version
    update!(active_version: nil) if active_version_id.present?
  end
end
