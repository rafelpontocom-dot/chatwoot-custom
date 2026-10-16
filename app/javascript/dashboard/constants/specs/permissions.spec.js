import { AVAILABLE_CUSTOM_ROLE_PERMISSIONS } from '../permissions';

// Contrato de upgrade `raevo-custom-role-permissions`: o ecrã de funções
// personalizadas (CustomRoleModal) desenha uma caixa por item desta lista. Se um
// upgrade do Chatwoot a reescrever sem as permissões do Raevo, deixa de ser
// possível dar a uma secretária acesso ao Pipeline, ao Financeiro ou ao Marketing.
// O servidor valida a mesma lista em `enterprise/app/models/custom_role.rb`.
const RAEVO_PERMISSIONS = [
  'kanban_view',
  'kanban_create',
  'kanban_edit',
  'kanban_assign',
  'kanban_move',
  'kanban_close',
  'kanban_bulk',
  'kanban_configure',
  'kanban_automate',
  'kanban_automation_publish',
  'kanban_automation_test',
  'kanban_automation_execution',
  'kanban_manage',
  'kanban_report',
  'finance_view',
  'finance_create',
  'finance_manage',
  'finance_refund',
  'finance_configure',
  'marketing_view',
  'marketing_configure',
];

describe('AVAILABLE_CUSTOM_ROLE_PERMISSIONS', () => {
  it('offers every Pipeline, Finance and Marketing permission of Raevo', () => {
    expect(AVAILABLE_CUSTOM_ROLE_PERMISSIONS).toEqual(
      expect.arrayContaining(RAEVO_PERMISSIONS)
    );
  });
});
