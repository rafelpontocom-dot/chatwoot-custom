# == Schema Information
#
# Table name: marketing_touchpoints
#
#  id              :bigint           not null, primary key
#  dedupe_digest   :string           not null
#  occurred_at     :datetime         not null
#  payload         :jsonb            not null
#  source          :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :bigint           not null
#  contact_id      :bigint
#  conversation_id :bigint
#  kanban_card_id  :bigint
#
# Indexes
#
#  index_marketing_touchpoints_on_account_and_digest          (account_id,dedupe_digest) UNIQUE
#  index_marketing_touchpoints_on_account_contact_and_time    (account_id,contact_id,occurred_at)
#  index_marketing_touchpoints_on_account_id                  (account_id)
#  index_marketing_touchpoints_on_account_id_and_occurred_at  (account_id,occurred_at)
#  index_marketing_touchpoints_on_account_source_and_time     (account_id,source,occurred_at)
#  index_marketing_touchpoints_on_contact_id                  (contact_id)
#  index_marketing_touchpoints_on_conversation_id             (conversation_id)
#  index_marketing_touchpoints_on_kanban_card_id              (kanban_card_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (contact_id => contacts.id) ON DELETE => nullify
#  fk_rails_...  (conversation_id => conversations.id) ON DELETE => nullify
#  fk_rails_...  (kanban_card_id => kanban_cards.id) ON DELETE => nullify
#
class MarketingTouchpoint < ApplicationRecord
  # De onde soubemos que a pessoa veio, e por qual porta.
  SOURCES = %w[widget_referer form_submission meta_lead_ad api_attribute ctwa click_link].freeze

  belongs_to :account
  belongs_to :contact, optional: true
  belongs_to :conversation, optional: true
  belongs_to :kanban_card, optional: true

  validates :source, inclusion: { in: SOURCES }
  validates :occurred_at, presence: true
  validates :dedupe_digest, presence: true, uniqueness: { scope: :account_id }
  validate :records_belong_to_account

  scope :recent_first, -> { order(occurred_at: :desc, id: :desc) }

  def self.digest_for(*parts)
    Digest::SHA256.hexdigest(parts.map(&:to_s).join('|'))
  end

  private

  # Um toque nunca pode apontar para o contato de outra conta.
  def records_belong_to_account
    { contact: contact, conversation: conversation, kanban_card: kanban_card }.each do |name, record|
      next if record.blank? || record.account_id == account_id

      errors.add(name, :invalid)
    end
  end
end
