class Api::V1::Accounts::Forms::TemplatesController < Api::V1::Accounts::BaseController
  before_action :fetch_template, only: %i[show update publish duplicate versions upload_logo destroy_logo]

  def index
    authorize FormTemplate.new(account: Current.account), :index?
    render json: Current.account.form_templates.includes(:active_version).order(updated_at: :desc).map(&:admin_payload)
  end

  def show
    authorize @form_template
    render json: @form_template.admin_payload
  end

  def create
    template = Current.account.form_templates.build(template_params)
    authorize template
    template.save!
    render json: template.admin_payload, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render_invalid(e.record)
  end

  def update
    authorize @form_template
    @form_template.update!(template_params)
    render json: @form_template.admin_payload
  rescue ActiveRecord::RecordInvalid => e
    render_invalid(e.record)
  end

  def publish
    authorize @form_template, :publish?
    @form_template.publish!(schema: schema_params)
    render json: @form_template.reload.admin_payload
  rescue ActiveRecord::RecordInvalid => e
    render_invalid(e.record)
  end

  def duplicate
    authorize @form_template, :duplicate?
    template = Forms::DuplicateTemplateService.new(source: @form_template, **duplicate_params).perform
    render json: template.admin_payload, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render_invalid(e.record)
  end

  def versions
    authorize @form_template, :show?
    versions = @form_template.form_template_versions.order(version_number: :desc)
    render json: versions.map(&:history_payload)
  end

  def upload_logo
    authorize @form_template, :update?
    @form_template.brand_logo.attach(brand_logo_params)
    @form_template.save!
    render json: @form_template.admin_payload
  rescue ActiveRecord::RecordInvalid => e
    render_invalid(e.record)
  end

  def destroy_logo
    authorize @form_template, :update?
    @form_template.brand_logo.purge if @form_template.brand_logo.attached?
    render json: @form_template.admin_payload
  end

  private

  def fetch_template
    @form_template = Current.account.form_templates.includes(:active_version).find(params[:id])
  end

  def template_params
    params.require(:form_template).permit(:name, :slug, :category, :access_classification, :public_enabled, settings: {})
  end

  def schema_params
    params.require(:form_template).require(:schema).permit!.to_h
  end

  def duplicate_params
    params.require(:form_template).permit(:name, :slug).to_h.symbolize_keys
  end

  def brand_logo_params
    params.require(:form_template).require(:brand_logo)
  end

  def render_invalid(record)
    render json: { message: record.errors.full_messages.to_sentence, errors: record.errors }, status: :unprocessable_entity
  end
end
