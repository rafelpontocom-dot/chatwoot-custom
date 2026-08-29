# == Schema Information
#
# Table name: form_invitations
#
#  id                       :bigint           not null, primary key
#  abandoned_at             :datetime
#  completed_at             :datetime
#  expires_at               :datetime
#  max_uses                 :integer          default(1), not null
#  opened_at                :datetime
#  sent_at                  :datetime
#  status                   :string           default("active"), not null
#  token_digest             :string           not null
#  uses_count               :integer          default(0), not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  account_id               :bigint           not null
#  contact_id               :bigint
#  form_template_version_id :bigint           not null
#  kanban_card_id           :bigint
#
# Indexes
#
#  index_form_invitations_for_abandonment              (status,abandoned_at,sent_at)
#  index_form_invitations_for_account_status           (account_id,status,expires_at)
#  index_form_invitations_on_account_id                (account_id)
#  index_form_invitations_on_contact_id                (contact_id)
#  index_form_invitations_on_form_template_version_id  (form_template_version_id)
#  index_form_invitations_on_kanban_card_id            (kanban_card_id)
#  index_form_invitations_on_token_digest              (token_digest) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (contact_id => contacts.id)
#  fk_rails_...  (form_template_version_id => form_template_versions.id)
#  fk_rails_...  (kanban_card_id => kanban_cards.id)
#
class FormInvitation < ApplicationRecord
  STATUSES = %w[active consumed expired revoked].freeze

  belongs_to :account
  belongs_to :form_template_version
  belongs_to :contact, optional: true
  belongs_to :kanban_card, optional: true
  has_one :form_invitation_draft, dependent: :destroy
  has_many :form_submissions, dependent: :restrict_with_exception

  enum :status, STATUSES.index_by(&:itself), validate: true

  validates :token_digest, presence: true, uniqueness: true
  validates :max_uses, numericality: { only_integer: true, greater_than: 0 }
  validates :uses_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :context_belongs_to_account
  validate :contact_matches_kanban_card
  validate :individual_forms_require_context
  validate :sensitive_health_requires_single_use

  def self.find_available_by_token(token)
    invitation = find_by(token_digest: digest_token(token))
    invitation&.expire_if_needed!
    invitation if invitation&.available?
  end

  def self.digest_token(token)
    OpenSSL::HMAC.hexdigest('SHA256', Rails.application.secret_key_base, token)
  end

  def available?
    active? && (expires_at.blank? || expires_at.future?) && uses_count < max_uses
  end

  def expire_if_needed!(now: Time.current)
    with_lock do
      next false unless active? && expires_at.present? && expires_at < now

      update!(status: 'expired')
      form_invitation_draft&.destroy!
      true
    end
  end

  def individual_public_access_allowed?
    template = form_template_version.form_template
    template.access_classification == 'commercial' || (template.sensitive_health? && contact.present?)
  end

  def consume!
    with_lock do
      unless available?
        errors.add(:base, 'invitation is unavailable')
        raise ActiveRecord::RecordInvalid, self
      end

      self.uses_count += 1
      self.status = 'consumed' if uses_count >= max_uses
      self.completed_at ||= Time.current if consumed?
      save!
    end
  end

  def mark_opened!
    with_lock do
      next false if opened_at.present? || !available?

      update!(opened_at: Time.current)
      true
    end
  end

  def mark_sent!
    with_lock do
      next false if sent_at.present? || !available?

      update!(sent_at: Time.current)
      true
    end
  end

  def mark_abandoned!(now: Time.current)
    with_lock do
      next false unless sent_at.present? && opened_at.blank? && completed_at.blank? && available? && abandoned_at.blank?

      update!(abandoned_at: now)
      true
    end
  end

  def revoke!
    expire_if_needed!
    unless active?
      errors.add(:base, 'only active invitations can be revoked')
      raise ActiveRecord::RecordInvalid, self
    end

    transaction do
      update!(status: 'revoked')
      form_invitation_draft&.destroy!
    end
  end

  def admin_payload
    {
      id: id,
      form_template_version_id: form_template_version_id,
      contact_id: contact_id,
      kanban_card_id: kanban_card_id,
      status: display_status,
      created_at: created_at,
      expires_at: expires_at,
      max_uses: max_uses,
      uses_count: uses_count,
      sent_at: sent_at,
      opened_at: opened_at,
      completed_at: completed_at
    }
  end

  private

  def display_status
    return 'abandoned' if active? && abandoned_at.present?
    return 'expired' if active? && expires_at.present? && expires_at.past?

    status
  end

  def context_belongs_to_account
    records = [form_template_version, contact, kanban_card].compact
    return if records.all? { |record| record.account_id == account_id }

    errors.add(:base, 'Invitation context must belong to the account')
  end

  def contact_matches_kanban_card
    return if contact.blank? || kanban_card.blank? || kanban_card.contact_id == contact_id

    errors.add(:base, 'Invitation contact must match the linked opportunity')
  end

  def individual_forms_require_context
    return unless individual_form?

    errors.add(:contact, 'must be present for individual forms') if contact.blank?
    errors.add(:kanban_card, 'must be present for individual forms') if kanban_card.blank?
  end

  def individual_form?
    template = form_template_version&.form_template
    template&.access_classification == 'commercial' || template&.sensitive_health?
  end

  def sensitive_health_requires_single_use
    return unless form_template_version&.form_template&.sensitive_health?
    return if max_uses == 1

    errors.add(:max_uses, 'must be one for sensitive health forms')
  end
end
