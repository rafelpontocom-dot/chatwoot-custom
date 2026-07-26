class KanbanAutomations::TriggerEvents
  def self.valid?(event_names)
    (Array(event_names).map(&:to_s).reject(&:blank?) - KanbanAutomationRule::EVENT_NAMES).blank?
  end
end
