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
  include FormTemplateSettings

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

  # O que basta para escolher um formulário e enviá-lo. Sem schema, sem
  # definições, sem contagem de respostas: quem envia não tem que ver o que a
  # clínica configurou nem quantas pessoas já responderam.
  def invitation_payload
    {
      id: id,
      name: name,
      category: category,
      access_classification: access_classification
    }
  end

  # Um convite individual precisa de versão publicada, e o formulário público
  # não se envia a ninguém — vive por link aberto.
  def sendable?
    active_version.present? && %w[commercial sensitive_health].include?(access_classification)
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
