# == Schema Information
#
# Table name: form_submissions
#
#  id                           :bigint           not null, primary key
#  answers                      :jsonb            not null
#  metadata                     :jsonb            not null
#  sensitive_answers_ciphertext :text
#  status                       :string           default("submitted"), not null
#  submitted_at                 :datetime         not null
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#  account_id                   :bigint           not null
#  contact_id                   :bigint
#  form_invitation_id           :bigint
#  form_template_version_id     :bigint           not null
#  kanban_card_id               :bigint
#
# Indexes
#
#  idx_on_account_id_status_submitted_at_b7c663f56a             (account_id,status,submitted_at)
#  index_form_submissions_on_account_id                         (account_id)
#  index_form_submissions_on_contact_id                         (contact_id)
#  index_form_submissions_on_form_invitation_id                 (form_invitation_id)
#  index_form_submissions_on_form_invitation_id_and_created_at  (form_invitation_id,created_at)
#  index_form_submissions_on_form_template_version_id           (form_template_version_id)
#  index_form_submissions_on_kanban_card_id                     (kanban_card_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (contact_id => contacts.id)
#  fk_rails_...  (form_invitation_id => form_invitations.id)
#  fk_rails_...  (form_template_version_id => form_template_versions.id)
#  fk_rails_...  (kanban_card_id => kanban_cards.id)
#
class FormSubmission < ApplicationRecord
  STATUSES = %w[submitted discarded].freeze

  belongs_to :account
  belongs_to :form_template_version
  belongs_to :form_invitation, optional: true
  belongs_to :contact, optional: true
  belongs_to :kanban_card, optional: true
  has_many :form_access_audits, dependent: :restrict_with_exception

  enum :status, STATUSES.index_by(&:itself), validate: true

  validates :submitted_at, presence: true
  validate :references_belong_to_account
  validate :sensitive_answers_are_separated

  class << self
    def create_from_answers!(account:, form_template_version:, answers:, **attributes)
      submission = new(
        account: account,
        form_template_version: form_template_version,
        submitted_at: Time.current,
        **attributes
      )
      submission.assign_submitted_answers(answers)
      submission.save!
      submission
    end
  end

  def assign_submitted_answers(value)
    if sensitive_health_form?
      self.answers = {}
      self.sensitive_answers_ciphertext = Forms::SensitiveAnswerCipher.encrypt(value)
    else
      self.answers = value.stringify_keys
      self.sensitive_answers_ciphertext = nil
    end
  end

  def sensitive_answers
    return {} unless sensitive_health_form? && sensitive_answers_ciphertext.present?

    Forms::SensitiveAnswerCipher.decrypt(sensitive_answers_ciphertext)
  end

  def sensitive_health_form?
    form_template_version.form_template.access_classification == 'sensitive_health'
  end

  def summary_payload
    {
      id: id,
      status: status,
      submitted_at: submitted_at,
      form_name: form_template_version.form_template.name,
      form_template_id: form_template_version.form_template_id,
      contact: contact && { id: contact.id, name: contact.name },
      opportunity: kanban_card && { id: kanban_card.id, subject: kanban_card.subject }
    }
  end

  def admin_payload
    summary_payload.merge(
      version_number: form_template_version.version_number,
      answers: answers,
      fields: response_fields
    )
  end

  def sensitive_health_payload
    summary_payload.merge(
      version_number: form_template_version.version_number,
      answers: sensitive_answers,
      fields: response_fields
    )
  end

  private

  def references_belong_to_account
    records = [form_template_version, form_invitation, contact, kanban_card].compact
    return if records.all? { |record| record.account_id == account_id }

    errors.add(:base, 'Submission references must belong to the account')
  end

  def response_fields
    form_template_version.schema.fetch('sections', []).flat_map do |section|
      section.fetch('fields', []).filter_map do |field|
        field.slice('key', 'label', 'type') unless field['type'] == 'hidden'
      end
    end
  end

  def sensitive_answers_are_separated
    return unless sensitive_health_form?

    errors.add(:answers, 'must be empty for sensitive health forms') if answers.present?
    errors.add(:sensitive_answers_ciphertext, 'must be present for sensitive health forms') if sensitive_answers_ciphertext.blank?
  end
end
