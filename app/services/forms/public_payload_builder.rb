class Forms::PublicPayloadBuilder
  PUBLIC_THEMES = %w[calm warm contrast].freeze

  def initialize(form_template:, form_template_version: nil)
    @form_template = form_template
    @form_template_version = form_template_version || form_template.active_version
  end

  def call
    {
      form: form_payload,
      version: form_template_version.version_number,
      schema: public_schema
    }
  end

  private

  attr_reader :form_template, :form_template_version

  def form_payload
    {
      name: form_template.name,
      category: form_template.category,
      locale: form_template.settings['locale'].presence || form_template.account.locale,
      description: form_template.settings['description'],
      brand_name: public_brand_name,
      brand_logo_url: form_template.brand_logo_url || public_brand_logo_url,
      privacy_policy_url: public_privacy_policy_url,
      theme: public_theme,
      captcha_provider: form_template.public_captcha_provider,
      captcha_site_key: form_template.public_captcha_site_key
    }
  end

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

  def public_brand_logo_url
    public_http_url('brand_logo_url')
  end

  def public_privacy_policy_url
    public_http_url('privacy_policy_url')
  end

  def public_http_url(setting)
    value = form_template.settings[setting].to_s.strip
    return if value.blank? || value.length > 2048

    uri = URI.parse(value)
    value if uri.is_a?(URI::HTTP) && uri.host.present?
  rescue URI::InvalidURIError
    nil
  end
end
