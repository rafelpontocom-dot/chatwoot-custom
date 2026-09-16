# Horário segurado na página pública enquanto o paciente preenche os dados.
# == Schema Information
#
# Table name: kanban_calendar_slot_holds
#
#  id                             :bigint           not null, primary key
#  expires_at                     :datetime         not null
#  reserved_from                  :datetime         not null
#  reserved_until                 :datetime         not null
#  resource_ids                   :integer          default([]), not null, is an Array
#  starts_at                      :datetime         not null
#  timezone                       :string           not null
#  token                          :string           not null
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#  account_id                     :bigint           not null
#  kanban_calendar_appointment_id :bigint
#  kanban_calendar_procedure_id   :bigint           not null
#
# Indexes
#
#  idx_on_kanban_calendar_appointment_id_d3be1449b6  (kanban_calendar_appointment_id)
#  idx_on_kanban_calendar_procedure_id_7401459b39    (kanban_calendar_procedure_id)
#  index_kanban_calendar_slot_holds_on_account_id    (account_id)
#  index_kanban_calendar_slot_holds_on_expires_at    (expires_at)
#  index_kanban_calendar_slot_holds_on_resource_ids  (resource_ids) USING gin
#  index_kanban_calendar_slot_holds_on_token         (token) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (kanban_calendar_appointment_id => kanban_calendar_appointments.id)
#  fk_rails_...  (kanban_calendar_procedure_id => kanban_calendar_procedures.id)
#
class KanbanCalendarSlotHold < ApplicationRecord
  belongs_to :account
  belongs_to :kanban_calendar_procedure
  belongs_to :kanban_calendar_appointment, optional: true

  validates :starts_at, :reserved_from, :reserved_until, :timezone, :expires_at, presence: true
  validates :resource_ids, presence: true

  before_validation :ensure_token

  scope :active, -> { where('expires_at > ?', Time.current) }
  scope :expired, -> { where(expires_at: ..Time.current) }
  scope :for_resource, ->(resource_id) { where('? = ANY(resource_ids)', resource_id) }
  scope :overlapping, ->(from, to) { where('reserved_from < ? AND reserved_until > ?', to, from) }

  def expired?
    expires_at <= Time.current
  end

  private

  def ensure_token
    self.token ||= SecureRandom.urlsafe_base64(24)
  end
end
