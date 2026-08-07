class KanbanCalendar::ResourceAvailabilityValidator
  def initialize(resources:, starts_at:, duration_minutes:, record:)
    @resources = resources
    @starts_at = starts_at
    @duration_minutes = duration_minutes
    @record = record
  end

  def validate!
    return if unavailable_resources.empty?

    @record.errors.add(:base, "Resources are unavailable: #{unavailable_resources.map(&:name).join(', ')}")
    raise ActiveRecord::RecordInvalid, @record
  end

  private

  def unavailable_resources
    @unavailable_resources ||= @starts_at.flat_map do |starts_at|
      @resources.reject do |resource|
        KanbanCalendar::AvailabilityQuery.new(
          resource: resource,
          starts_at: starts_at,
          ends_at: starts_at + @duration_minutes.minutes
        ).available?
      end
    end.uniq
  end
end
