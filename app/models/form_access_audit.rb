# == Schema Information
#
# Table name: form_access_audits
#
#  id                 :bigint           not null, primary key
#  action             :string           not null
#  occurred_at        :datetime         not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  account_id         :bigint           not null
#  actor_id           :bigint
#  form_submission_id :bigint           not null
#
# Indexes
#
#  idx_on_account_id_action_occurred_at_5ce9ba1709                 (account_id,action,occurred_at)
#  index_form_access_audits_on_account_id                          (account_id)
#  index_form_access_audits_on_actor_id                            (actor_id)
#  index_form_access_audits_on_form_submission_id                  (form_submission_id)
#  index_form_access_audits_on_form_submission_id_and_occurred_at  (form_submission_id,occurred_at)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (actor_id => users.id)
#  fk_rails_...  (form_submission_id => form_submissions.id)
#
class FormAccessAudit < ApplicationRecord
  ACTIONS = %w[view].freeze

  belongs_to :account
  belongs_to :form_submission
  belongs_to :actor, class_name: 'User', optional: true

  validates :action, inclusion: { in: ACTIONS }
  validates :occurred_at, presence: true
  validate :references_belong_to_account

  private

  def references_belong_to_account
    return if form_submission.blank? || form_submission.account_id == account_id

    errors.add(:form_submission, 'must belong to the account')
  end
end
