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
    mapped_fields = mapped_answers_for(contact_mapping.slice(*CONTACT_FIELDS))
    normalize_phone_number!(mapped_fields)
    append_custom_attributes!(mapped_fields)
    mapped_fields
  end

  def mapped_answers_for(mapping)
    mapping.filter_map do |attribute, answer_key|
      [attribute, answer_value(answer_key)] if answer_value(answer_key).present?
    end.to_h
  end

  def normalize_phone_number!(mapped_fields)
    return unless mapped_fields['phone_number']

    mapped_fields['phone_number'] = Forms::PhoneNumberNormalizer.new(
      phone_number: mapped_fields['phone_number'],
      locale: form_template.settings['locale'].presence || submission.account.locale
    ).call
  end

  def append_custom_attributes!(mapped_fields)
    custom_attributes = mapped_answers_for(contact_mapping.fetch('custom_attributes', {}))
    return if custom_attributes.blank?

    mapped_fields[:custom_attributes] = contact.custom_attributes.merge(custom_attributes)
  end

  def contact_mapping
    submission.form_template_version.schema.fetch('crm_mapping', {}).fetch('contact', {}).to_h
  end

  def form_template
    submission.form_template_version.form_template
  end

  def answer_value(key)
    answers[key.to_s]
  end
end
