class Api::V1::Accounts::Forms::FieldGroupsController < Api::V1::Accounts::BaseController
  before_action :fetch_field_group, only: :destroy

  def index
    authorize FormFieldGroup.new(account: Current.account), :index?
    render json: Current.account.form_field_groups.order(:name).map(&:admin_payload)
  end

  def create
    field_group = Current.account.form_field_groups.build(field_group_params)
    authorize field_group
    field_group.save!

    render json: field_group.admin_payload, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render_invalid(e.record)
  end

  def destroy
    authorize @field_group
    @field_group.destroy!
    head :no_content
  end

  private

  def fetch_field_group
    @field_group = Current.account.form_field_groups.find(params[:id])
  end

  def field_group_params
    params.require(:form_field_group).permit(
      :name,
      section: [
        :key,
        :title,
        :description,
        {
          fields: [
            :key,
            :label,
            :type,
            :required,
            :help_text,
            { options: [] },
            { visible_when: %i[field operator value] }
          ]
        }
      ]
    )
  end

  def render_invalid(record)
    render json: { message: record.errors.full_messages.to_sentence, errors: record.errors }, status: :unprocessable_entity
  end
end
