# == Schema Information
#
# Table name: marketing_lead_forms
#
#  id                               :bigint           not null, primary key
#  active                           :boolean          default(FALSE), not null
#  crm_destination                  :jsonb            not null
#  field_mapping                    :jsonb            not null
#  last_lead_at                     :datetime
#  last_synced_at                   :datetime
#  name                             :string
#  page_name                        :string
#  questions                        :jsonb            not null
#  received_count                   :integer          default(0), not null
#  created_at                       :datetime         not null
#  updated_at                       :datetime         not null
#  account_id                       :bigint           not null
#  external_form_id                 :string           not null
#  marketing_provider_connection_id :bigint           not null
#  page_id                          :string           not null
#
# Indexes
#
#  index_marketing_lead_forms_on_account_and_form  (account_id,external_form_id) UNIQUE
#  index_marketing_lead_forms_on_account_id        (account_id)
#  index_marketing_lead_forms_on_connection        (marketing_provider_connection_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (marketing_provider_connection_id => marketing_provider_connections.id)
#
class MarketingLeadForm < ApplicationRecord
  belongs_to :account
  belongs_to :marketing_provider_connection

  validates :page_id, :external_form_id, presence: true
  validates :external_form_id, uniqueness: { scope: :account_id }
  validate :destination_present_when_active

  scope :active, -> { where(active: true) }

  # As perguntas como o Meta as devolve: `name` e a chave que vem no lead.
  def question_keys
    Array(questions).filter_map { |question| question['key'].presence }
  end

  def public_payload
    {
      id: id,
      page_id: page_id,
      page_name: page_name,
      external_form_id: external_form_id,
      name: name,
      questions: questions,
      field_mapping: field_mapping,
      crm_destination: crm_destination,
      active: active,
      last_synced_at: last_synced_at,
      last_lead_at: last_lead_at,
      received_count: received_count
    }
  end

  private

  # Antes de ligar, o lead precisa saber onde cair — senao ele chega e se perde.
  def destination_present_when_active
    return unless active?

    destination = crm_destination.to_h
    %w[kanban_board_id kanban_stage_id inbox_id].each do |key|
      errors.add(:crm_destination, "#{key} is required to activate") if destination[key].blank?
    end
  end
end
