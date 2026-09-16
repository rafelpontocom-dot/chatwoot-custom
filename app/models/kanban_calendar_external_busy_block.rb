# == Schema Information
#
# Table name: kanban_calendar_external_busy_blocks
#
#  id                                   :bigint           not null, primary key
#  all_day                              :boolean          default(FALSE), not null
#  ends_at                              :datetime         not null
#  starts_at                            :datetime         not null
#  created_at                           :datetime         not null
#  updated_at                           :datetime         not null
#  account_id                           :bigint           not null
#  external_event_id                    :string           not null
#  kanban_calendar_google_connection_id :bigint           not null
#  kanban_calendar_resource_id          :bigint           not null
#
# Indexes
#
#  idx_calendar_busy_blocks_on_connection_event              (kanban_calendar_google_connection_id,external_event_id) UNIQUE
#  idx_calendar_busy_blocks_on_resource_range                (kanban_calendar_resource_id,starts_at,ends_at)
#  index_kanban_calendar_external_busy_blocks_on_account_id  (account_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (kanban_calendar_google_connection_id => kanban_calendar_google_connections.id)
#  fk_rails_...  (kanban_calendar_resource_id => kanban_calendar_resources.id)
#
# Um horário em que a agenda Google ligada a um recurso está ocupada. Só o
# intervalo: o título do evento é da vida de quem o marcou, não da clínica.
class KanbanCalendarExternalBusyBlock < ApplicationRecord
  belongs_to :account
  belongs_to :kanban_calendar_resource
  belongs_to :kanban_calendar_google_connection

  validates :external_event_id, presence: true
  validates :starts_at, :ends_at, presence: true
  validate :ends_after_starts

  scope :overlapping, lambda { |starts_at, ends_at|
    where('kanban_calendar_external_busy_blocks.starts_at < ? AND kanban_calendar_external_busy_blocks.ends_at > ?', ends_at, starts_at)
  }

  private

  def ends_after_starts
    return if starts_at.blank? || ends_at.blank? || ends_at > starts_at

    errors.add(:ends_at, 'must be after starts_at')
  end
end
