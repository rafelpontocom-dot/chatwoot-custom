# == Schema Information
#
# Table name: kanban_calendar_procedure_resources
#
#  id                           :bigint           not null, primary key
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#  kanban_calendar_procedure_id :bigint           not null
#  kanban_calendar_resource_id  :bigint           not null
#
# Indexes
#
#  index_calendar_procedure_resources_on_procedure_and_resource  (kanban_calendar_procedure_id,kanban_calendar_resource_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (kanban_calendar_procedure_id => kanban_calendar_procedures.id)
#  fk_rails_...  (kanban_calendar_resource_id => kanban_calendar_resources.id)
#
class KanbanCalendarProcedureResource < ApplicationRecord
  belongs_to :kanban_calendar_procedure
  belongs_to :kanban_calendar_resource

  validates :kanban_calendar_resource_id, uniqueness: { scope: :kanban_calendar_procedure_id }
end
