class Api::V1::Accounts::Marketing::ModuleController < Api::V1::Accounts::BaseController
  before_action :fetch_setting

  def show
    authorize @marketing_module_setting, :show?
    render json: @marketing_module_setting.public_payload
  end

  def update
    authorize @marketing_module_setting, :update?
    @marketing_module_setting.assign_attributes(module_attributes)
    ensure_disable_confirmation
    @marketing_module_setting.apply_enabled_state(actor: Current.user)
    @marketing_module_setting.save!
    render json: @marketing_module_setting.public_payload
  rescue ActiveRecord::RecordInvalid => e
    render json: { message: e.record.errors.full_messages.to_sentence, errors: e.record.errors }, status: :unprocessable_entity
  end

  private

  def fetch_setting
    @marketing_module_setting = Current.account.marketing_module_setting || Current.account.build_marketing_module_setting
  end

  def module_params
    params.require(:marketing_module).permit(:enabled, :lock_version, :confirm_disable, settings: {})
  end

  def module_attributes
    module_params.except(:confirm_disable)
  end

  # Desligar para de captar atribuicao para a conta inteira; a partir dai o
  # lead entra sem saber de onde veio, e isso nao se recupera depois.
  def ensure_disable_confirmation
    return unless @marketing_module_setting.enabled_change_to_be_saved == [true, false]
    return if ActiveModel::Type::Boolean.new.cast(module_params[:confirm_disable])

    @marketing_module_setting.errors.add(:enabled, 'requires confirmation before disabling the marketing module')
    raise ActiveRecord::RecordInvalid, @marketing_module_setting
  end
end
