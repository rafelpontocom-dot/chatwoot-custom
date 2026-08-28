class Forms::MapSubmissionToCrmService
  CONTACT_FIELDS = %w[name email phone_number].freeze

  def initialize(submission:)
    @submission = submission
  end

  def perform
    return if contact.blank? || sensitive_health_form?

    attributes = mapped_contact_attributes
    contact.update!(attributes) if attributes.present?
  end

  private

  attr_reader :submission

  delegate :answers, to: :submission

  def contact
    submission.contact
  end

  def sensitive_health_form?
    submission.form_template_version.form_template.access_classification == 'sensitive_health'
  end

  def mapped_contact_attributes
    mapped_fields = contact_mapping.slice(*CONTACT_FIELDS).filter_map do |attribute, answer_key|
      [attribute, answer_value(answer_key)] if answer_value(answer_key).present?
    end.to_h

    custom_attributes = contact_mapping.fetch('custom_attributes', {}).filter_map do |attribute, answer_key|
      [attribute, answer_value(answer_key)] if answer_value(answer_key).present?
    end.to_h
    mapped_fields[:custom_attributes] = contact.custom_attributes.merge(custom_attributes) if custom_attributes.present?
    mapped_fields
  end

  def contact_mapping
    submission.form_template_version.schema.fetch('crm_mapping', {}).fetch('contact', {}).to_h
  end

  def answer_value(key)
    answers[key.to_s]
  end
end
