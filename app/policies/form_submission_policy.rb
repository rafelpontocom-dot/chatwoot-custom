class FormSubmissionPolicy < ApplicationPolicy
  def index?
    administrator?
  end

  def show?
    administrator?
  end

  private

  def administrator?
    account_user&.administrator?
  end
end
