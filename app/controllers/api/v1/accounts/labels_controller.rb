class Api::V1::Accounts::LabelsController < Api::V1::Accounts::BaseController
  before_action :fetch_label, except: [:index, :create, :reorder]
  before_action :check_authorization

  # O título é único na CONTA, não no que cada pessoa vê. Criar uma etiqueta com
  # o nome de uma pessoal de outra pessoa respondia «Title has already been
  # taken», em inglês e cru. Responde-se com um código, e o cliente diz em
  # português que o nome já está em uso e que se escolha outro.
  rescue_from ActiveRecord::RecordInvalid, with: :render_label_invalid

  def index
    @labels = policy_scope(Current.account.labels)
  end

  def show; end

  def create
    @label = Current.account.labels.create!(label_attributes.merge(created_by: Current.user))
  end

  def update
    @label.update!(label_attributes(current: @label))
  end

  def reorder
    label_ids = params.require(:label_ids).map(&:to_i)
    labels = Current.account.labels.find(label_ids).index_by(&:id)

    Label.transaction do
      label_ids.each_with_index { |label_id, index| labels[label_id].update!(position: index) }
    end

    head :ok
  end

  def destroy
    label_title = @label.title
    account_id = Current.account.id
    label_deleted_at = Time.current

    @label.destroy!
    Labels::RemoveAssociationsJob.perform_later(
      label_title: label_title,
      account_id: account_id,
      label_deleted_at: label_deleted_at
    )
    head :ok
  end

  private

  def render_label_invalid(exception)
    return render_record_invalid(exception) unless exception.record.errors.of_kind?(:title, :taken)

    render json: { code: 'title_taken', message: exception.record.errors.full_messages.join(', '), attributes: [:title] },
           status: :unprocessable_entity
  end

  # `check_authorization` do base autoriza a CLASSE. Com visibilidade, a decisão
  # depende da etiqueta concreta — sem isto o agente nunca conseguia renomear a
  # própria etiqueta pessoal, porque a política recebia `Label` e não o registo.
  def check_authorization
    authorize(@label || Label)
  end

  def fetch_label
    @label = Current.account.labels.find(params[:id])
  end

  def permitted_params
    params.require(:label).permit(:title, :description, :color, :show_on_sidebar, :visibility, :team_id)
  end

  def label_attributes(current: nil)
    atributos = permitted_params.to_h.symbolize_keys.merge(clamped_visibility(current: current))
    # «Somente eu» é quem faz a mudança. As etiquetas anteriores à visibilidade
    # não têm autor, e uma pessoal precisa de um (09/10: dava «Ocorreu um erro»).
    atributos[:created_by] = Current.user if atributos[:visibility].to_s == 'personal'
    atributos
  end

  # «Só o administrador cria de todos; o agente cria só para ele» — decisão do
  # Pedro, 07/10. A regra prende-se AQUI e não na tela: a tela é uma sugestão, o
  # pedido é que manda. Um agente que mandasse `visibility: global` à mão
  # continuaria a criar uma etiqueta pessoal.
  def clamped_visibility(current: nil)
    return { visibility: :personal, team_id: nil } unless Current.account_user&.administrator?

    pedida = params[:label][:visibility].presence || current&.visibility || 'global'
    valores = { visibility: pedida }
    valores[:team_id] = nil unless pedida.to_s == 'team'
    valores
  end
end
