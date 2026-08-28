class Api::V1::Accounts::Finance::ModuleController < Api::V1::Accounts::BaseController
  before_action :fetch_setting

  def show
    authorize @finance_module_setting, :show?
    render json: @finance_module_setting.public_payload
  end

  def update
    authorize @finance_module_setting, :update?
    @finance_module_setting.assign_attributes(module_attributes)
    ensure_disable_confirmation
    @finance_module_setting.apply_enabled_state(actor: Current.user)
    @finance_module_setting.save!
    render json: @finance_module_setting.public_payload
  rescue ActiveRecord::RecordInvalid => e
    render json: { message: e.record.errors.full_messages.to_sentence, errors: e.record.errors }, status: :unprocessable_entity
  end

  private

  def fetch_setting
    @finance_module_setting = Current.account.finance_module_setting || Current.account.build_finance_module_setting
  end

  def module_params
    params.require(:finance_module).permit(
      :enabled,
      :market,
      :default_payment_provider,
      :default_invoicing_provider,
      :lock_version,
      :confirm_disable,
      settings: {}
    )
  end

  def module_attributes
    module_params.except(:confirm_disable)
  end

  def ensure_disable_confirmation
    return unless @finance_module_setting.enabled_change_to_be_saved == [true, false]
    return if ActiveModel::Type::Boolean.new.cast(module_params[:confirm_disable])

    @finance_module_setting.errors.add(:enabled, 'requires confirmation before disabling the finance module')
    raise ActiveRecord::RecordInvalid, @finance_module_setting
  end
end
