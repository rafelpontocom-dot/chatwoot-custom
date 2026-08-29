class FormFieldGroupPolicy < ApplicationPolicy
  def index?
    administrator?
  end

  def create?
    administrator?
  end

  def destroy?
    administrator?
  end

  private

  def administrator?
    account_user&.administrator?
  end
end
