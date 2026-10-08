class LabelPolicy < ApplicationPolicy
  def index?
    @account_user.administrator? || @account_user.agent?
  end

  # O agente passa a poder criar etiqueta — mas só PESSOAL. Quem decide isso é o
  # controlador, que prende a visibilidade antes de gravar; aqui só se diz que a
  # porta está aberta. «Só de todos é que é do administrador» é a decisão do Pedro
  # de 07/10.
  def create?
    @account_user.administrator? || @account_user.agent?
  end

  # A mesma regra da lista: não se mostra por id o que não se mostra na lista.
  def show?
    visible?
  end

  # Sem isto o agente criava uma etiqueta pessoal e nunca mais lhe mudava o nome
  # nem a apagava.
  def update?
    (@account_user.administrator? && visible?) || own_personal_label?
  end

  # A ordem é UMA lista partilhada por toda a conta: quem a reordena mexe no que
  # os outros veem.
  def reorder?
    @account_user.administrator?
  end

  def destroy?
    (@account_user.administrator? && visible?) || own_personal_label?
  end

  private

  def own_personal_label?
    record.is_a?(Label) && record.personal? && record.created_by_id == @user&.id
  end

  def visible?
    return false unless record.is_a?(Label)

    Pundit.policy_scope!(user_context, Label).exists?(id: record.id)
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.manageable_by_administrator(user) if account_user&.administrator?

      scope.visible_to(user)
    end
  end
end
