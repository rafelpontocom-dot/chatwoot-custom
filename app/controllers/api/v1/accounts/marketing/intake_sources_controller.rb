class Api::V1::Accounts::Marketing::IntakeSourcesController < Api::V1::Accounts::BaseController
  before_action :ensure_marketing_module_enabled
  before_action :fetch_source, only: [:update, :destroy, :rotate]

  def index
    authorize MarketingIntakeSource, :view?
    render json: { payload: sources.map(&:public_payload) }
  end

  # O token so aparece aqui, uma vez. Depois disso a tela mostra a origem sem
  # ele; quem perdeu gera outro.
  def create
    authorize MarketingIntakeSource, :configure?
    source = sources.create!(source_params)
    render json: source.public_payload(reveal_token: true), status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { message: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  def update
    authorize MarketingIntakeSource, :configure?
    @source.update!(source_params)
    render json: @source.public_payload
  rescue ActiveRecord::RecordInvalid => e
    render json: { message: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  def rotate
    authorize MarketingIntakeSource, :configure?
    @source.regenerate_token
    render json: @source.public_payload(reveal_token: true)
  end

  # Desligar em vez de apagar: a origem some da porta na hora, e os toques que
  # ela ja trouxe continuam explicando de onde vieram os leads de ontem.
  def destroy
    authorize MarketingIntakeSource, :configure?
    @source.update!(active: false)
    head :no_content
  end

  private

  def sources
    Current.account.marketing_intake_sources
  end

  def fetch_source
    @source = sources.find(params[:id])
  end

  def ensure_marketing_module_enabled
    return if Current.account.marketing_module_setting&.enabled?

    render json: { message: 'Marketing module is not enabled for this account' }, status: :forbidden
  end

  def source_params
    params.require(:intake_source).permit(
      :name, :active, crm_destination: [:kanban_board_id, :kanban_stage_id, :inbox_id, :opportunity_policy]
    )
  end
end
