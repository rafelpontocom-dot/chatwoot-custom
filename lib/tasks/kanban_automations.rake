namespace :kanban_automations do
  desc 'Verify Kanban automation prerequisites without changing data'
  task smoke: :environment do
    checks = {
      open_next_action_index: KanbanCard.connection.indexes('kanban_cards').any? do |index|
        index.name == 'index_open_kanban_cards_on_next_action_at'
      end,
      workflow_jobs: defined?(KanbanAutomations::ExecuteRuleJob) && defined?(KanbanAutomations::ContinueWorkflowJob),
      overdue_next_action_job: defined?(KanbanAutomations::DispatchOverdueNextActionsJob),
      connection_audits: KanbanAutomationConnectionAudit.table_exists?
    }

    failed_checks = checks.filter_map { |name, passed| name unless passed }
    raise "Kanban automations smoke failed: #{failed_checks.join(', ')}" if failed_checks.any?

    checks.each_key { |name| puts "[ok] #{name}" }
    puts 'Kanban automations smoke passed'
  end
end
