namespace :raevo_ai do
  desc 'Provision a disabled Raevo AI integration using a server-side command token'
  task provision: :environment do
    integration = RaevoAiIntegration.find_by!(clinic_id: ENV.fetch('RAEVO_AI_CLINIC_ID'))
    stages = JSON.parse(ENV.fetch('RAEVO_AI_CRM_STAGES'))
    board_ids = ENV.fetch('RAEVO_AI_TAB_BOARD_IDS').split(',').map(&:to_i)

    result = RaevoAi::IntegrationProvisioner.new(
      integration: integration,
      command_token: ENV.fetch('RAEVO_AI_COMMAND_TOKEN')
    ).provision!(
      board_key: ENV.fetch('RAEVO_AI_CRM_BOARD_KEY'),
      board_id: ENV.fetch('RAEVO_AI_CRM_BOARD_ID'),
      initial_stage_id: ENV.fetch('RAEVO_AI_CRM_INITIAL_STAGE_ID'),
      stages: stages,
      ai_tab_board_ids: board_ids
    )

    puts JSON.generate(result)
  end
end
