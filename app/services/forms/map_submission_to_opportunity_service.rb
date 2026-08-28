class Forms::MapSubmissionToOpportunityService
  Result = Struct.new(:status, keyword_init: true) do
    def mapped?
      status == 'mapped'
    end

    def rejected?
      status == 'rejected'
    end
  end

  def initialize(submission:, kanban_card:)
    @submission = submission
    @kanban_card = kanban_card
  end

  def perform
    return Result.new(status: 'not_configured') if mapping.blank? || sensitive_health_form?

    kanban_card.with_lock do
      raise MappingError unless valid_target_fields?

      values = mapped_values
      next Result.new(status: 'no_answers') if values.blank?

      kanban_card.update!(custom_field_values: kanban_card.custom_field_values.to_h.merge(values))
      Result.new(status: 'mapped')
    end
  rescue MappingError, ActiveRecord::RecordInvalid
    Result.new(status: 'rejected')
  end

  private

  MappingError = Class.new(StandardError)

  attr_reader :submission, :kanban_card

  delegate :answers, to: :submission

  def mapping
    @mapping ||= submission.form_template_version.schema.dig('crm_mapping', 'kanban_card', 'custom_field_values').to_h.stringify_keys
  end

  def mapped_values
    mapping.each_with_object({}) do |(field_key, answer_key), values|
      answer = answers[answer_key]
      values[field_key] = answer if answer.present? || answer == false
    end
  end

  def valid_target_fields?
    definitions = kanban_card.kanban_board.configured_custom_field_definitions.index_by { |field| field['key'] }

    mapping.keys.all? do |field_key|
      definitions[field_key].present? && definitions[field_key]['field_type'] != 'formula'
    end
  end

  def sensitive_health_form?
    submission.form_template_version.form_template.access_classification == 'sensitive_health'
  end
end
