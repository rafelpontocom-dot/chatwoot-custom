class FormSubmissionPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope if account_user&.administrator?

      template_ids = account.form_templates.where(access_classification: 'sensitive_health').filter_map do |template|
        template.id if template.clinically_accessible_to?(user)
      end
      return scope.none if template_ids.empty?

      version_ids = FormTemplateVersion.where(form_template_id: template_ids).select(:id)
      scope.where(form_template_version_id: version_ids)
    end
  end

  def index?
    administrator? || clinical_submission_access?
  end

  def show?
    return false unless record.account_id == account.id
    return true if administrator?
    return false unless record.sensitive_health_form?

    record.form_template_version.form_template.clinically_accessible_to?(user)
  end

  def export?
    record.account_id == account.id && administrator?
  end

  # Resolver o que ficou proposto é trabalho de quem atende, não só de quem
  # administra — mas nunca num formulário clínico, que não propõe nada.
  def resolve_pending_action?
    record.account_id == account.id && !record.sensitive_health_form?
  end

  private

  def administrator?
    account_user&.administrator?
  end

  def clinical_submission_access?
    account.form_templates.where(access_classification: 'sensitive_health').any? do |template|
      template.clinically_accessible_to?(user)
    end
  end
end
