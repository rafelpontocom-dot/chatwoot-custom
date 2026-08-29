# == Schema Information
#
# Table name: form_invitation_drafts
#
#  id                           :bigint           not null, primary key
#  answers                      :jsonb            not null
#  current_section_index        :integer          default(0), not null
#  sensitive_answers_ciphertext :text
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#  account_id                   :bigint           not null
#  form_invitation_id           :bigint           not null
#
# Indexes
#
#  index_form_invitation_drafts_on_account_id          (account_id)
#  index_form_invitation_drafts_on_form_invitation_id  (form_invitation_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (form_invitation_id => form_invitations.id)
#
class FormInvitationDraft < ApplicationRecord
  NON_DRAFT_FIELD_TYPES = %w[hidden attachment].freeze

  belongs_to :account
  belongs_to :form_invitation

  validates :current_section_index,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :invitation_belongs_to_account

  def assign_answers(value)
    sanitized = permitted_answers(value)
    if sensitive_health_form?
      self.answers = {}
      self.sensitive_answers_ciphertext = Forms::SensitiveAnswerCipher.encrypt(sanitized)
    else
      self.answers = sanitized
      self.sensitive_answers_ciphertext = nil
    end
  end

  def assign_current_section_index(value)
    maximum_index = [form_invitation.form_template_version.schema.fetch('sections', []).size - 1, 0].max
    self.current_section_index = value.to_i.clamp(0, maximum_index)
  end

  def public_payload
    { answers: sensitive_health_form? ? sensitive_answers : answers, current_section_index: current_section_index }
  end

  private

  def invitation_belongs_to_account
    return if form_invitation.blank? || account_id == form_invitation.account_id

    errors.add(:form_invitation, :invalid)
  end

  def sensitive_health_form?
    form_invitation.form_template_version.form_template.sensitive_health?
  end

  def sensitive_answers
    return {} if sensitive_answers_ciphertext.blank?

    Forms::SensitiveAnswerCipher.decrypt(sensitive_answers_ciphertext)
  end

  def permitted_answers(value)
    allowed_keys = form_invitation.form_template_version.schema.fetch('sections', []).flat_map do |section|
      section.fetch('fields', [])
             .reject { |field| NON_DRAFT_FIELD_TYPES.include?(field['type']) }
             .map { |field| field['key'] }
    end
    value.to_h.stringify_keys.slice(*allowed_keys)
  end
end
