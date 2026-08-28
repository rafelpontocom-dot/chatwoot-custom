class Forms::PublicPayloadBuilder
  PUBLIC_THEMES = %w[calm warm contrast].freeze

  def initialize(form_template:, form_template_version: nil)
    @form_template = form_template
    @form_template_version = form_template_version || form_template.active_version
  end

  def call
    {
      form: {
        name: form_template.name,
        category: form_template.category,
        locale: form_template.settings['locale'].presence || form_template.account.locale,
        description: form_template.settings['description'],
        brand_name: public_brand_name,
        theme: public_theme
      },
      version: form_template_version.version_number,
      schema: public_schema
    }
  end

  private

  attr_reader :form_template, :form_template_version

  def public_schema
    schema = form_template_version.schema.deep_dup
    schema.delete('crm_mapping')
    schema.delete('crm_destination')
    schema['sections'] = schema.fetch('sections', []).map do |section|
      section.merge('fields' => section.fetch('fields', []).reject { |field| field['type'] == 'hidden' })
    end
    schema
  end

  def public_brand_name
    form_template.settings['brand_name'].to_s.strip.presence || form_template.account.name
  end

  def public_theme
    configured_theme = form_template.settings['theme'].to_s
    PUBLIC_THEMES.include?(configured_theme) ? configured_theme : 'calm'
  end
end
