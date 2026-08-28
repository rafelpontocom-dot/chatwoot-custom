class Forms::DuplicateTemplateService
  def initialize(source:, name:, slug:)
    @source = source
    @name = name
    @slug = slug
  end

  def perform
    FormTemplate.transaction do
      copy = source.account.form_templates.create!(
        name: name,
        slug: slug,
        category: source.category,
        access_classification: source.access_classification,
        settings: source.settings,
        public_enabled: false
      )
      copy.publish!(schema: source.active_version.schema) if source.active_version.present?
      copy
    end
  end

  private

  attr_reader :source, :name, :slug
end
