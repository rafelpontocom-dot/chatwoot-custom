class KanbanCalendar::ConflictError < StandardError
  attr_reader :resource_ids

  def initialize(resource_ids)
    @resource_ids = resource_ids
    super('One or more calendar resources are already booked for this time')
  end
end
