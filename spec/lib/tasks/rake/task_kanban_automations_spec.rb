require 'rails_helper'
require 'rake'

Rake::Task.define_task(:environment) unless Rake::Task.task_defined?(:environment)
load Rails.root.join('lib/tasks/kanban_automations.rake') unless Rake::Task.task_defined?('kanban_automations:smoke')

RSpec.describe Rake::Task do
  describe 'kanban_automations:smoke' do
    let(:task) { described_class['kanban_automations:smoke'] }

    after { task.reenable }

    it 'reports the deployed automation prerequisites without changing data' do
      output = capture_stdout { task.invoke }

      expect(output).to include('Kanban automations smoke passed')
      expect(output).to include('open_next_action_index')
      expect(output).to include('workflow_jobs')
    end

    it 'fails clearly when the overdue next-action index is missing' do
      allow(KanbanCard.connection).to receive(:indexes).with('kanban_cards').and_return([])

      expect { task.invoke }
        .to raise_error(RuntimeError, 'Kanban automations smoke failed: open_next_action_index')
    end

    def capture_stdout
      original_stdout = $stdout
      $stdout = StringIO.new
      yield
      $stdout.string
    ensure
      $stdout = original_stdout
    end
  end
end
