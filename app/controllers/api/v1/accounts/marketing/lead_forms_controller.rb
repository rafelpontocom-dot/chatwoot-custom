class Api::V1::Accounts::Marketing::LeadFormsController < Api::V1::Accounts::BaseController
  before_action :ensure_marketing_module_enabled
  before_action :fetch_lead_form, only: [:update]

  # `configure?`, nao `view?`: o /me/accounts do Meta devolve TODAS as paginas
  # que a pessoa administra. Numa agencia que atende varias clinicas, isso
  # inclui as paginas dos outros clientes — nao e coisa para a secretaria de
  # uma clinica enxergar.
  def index
    authorize MarketingLeadForm, :configure?
    render json: { payload: lead_forms.map(&:public_payload) }
  end

  # Aqui se escolhe onde o lead cai e qual pergunta vira qual campo. Ligar sem
  # destino e recusado pelo proprio modelo.
  def update
    authorize MarketingLeadForm, :configure?
    @lead_form.update!(lead_form_params)
    render json: @lead_form.public_payload
  rescue ActiveRecord::RecordInvalid => e
    render json: { message: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  private

  def lead_forms
    Current.account.marketing_lead_forms.order(:page_name, :name)
  end

  def fetch_lead_form
    @lead_form = lead_forms.find(params[:id])
  end

  def lead_form_params
    params.require(:lead_form).permit(
      :active,
      field_mapping: {},
      crm_destination: [:kanban_board_id, :kanban_stage_id, :inbox_id, :opportunity_policy,
                        :origem_do_lead, :sub_origem]
    )
  end

  def ensure_marketing_module_enabled
    return if Current.account.marketing_module_setting&.enabled?

    render json: { message: 'Marketing module is not enabled for this account' }, status: :forbidden
  end
end
