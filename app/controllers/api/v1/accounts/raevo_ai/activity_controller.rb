class Api::V1::Accounts::RaevoAi::ActivityController < Api::V1::Accounts::BaseController
  # O que a Elis fez, lido da própria base do Chatwoot.
  #
  # Cada comando que ela executa — criar oportunidade, mover etapa, agendar,
  # cobrar, passar para humano — já fica registado em `raevo_ai_commands` com
  # tipo, estado e hora. Ir buscar isto ao serviço Raevo seria pedir de fora um
  # dado que está aqui dentro, e ainda por cima mais lento e sujeito a a ponte
  # estar de pé.
  #
  # O `result` do comando NUNCA sai daqui: é um recibo interno que pode trazer
  # identificadores e detalhe de execução que a clínica não tem porque ver.
  before_action :authorize_account

  RECENT_LIMIT = 20
  ATTENTION_STATES = %w[failed_retryable failed_terminal].freeze
  PENDING_STATE = 'claimed'.freeze
  UNKNOWN_COMMAND = 'unknown'.freeze

  # Um comando acabado de reclamar não é trabalho parado: é trabalho a decorrer.
  # Contá-lo de imediato punha o painel a acusar pendências que se resolviam
  # sozinhas em segundos, e a clínica aprendia a ignorar o aviso — que é a pior
  # coisa que pode acontecer a um aviso.
  STALE_PENDING_AFTER = 5.minutes

  def show
    integration = Current.account.raevo_ai_integration
    return render json: { recent: [], attention: empty_attention } unless integration

    render json: {
      recent: recent_for(integration),
      attention: attention_for(integration)
    }
  end

  private

  def authorize_account
    authorize Current.account, :show?
  end

  def recent_for(integration)
    integration.raevo_ai_commands
               .order(created_at: :desc, id: :desc)
               .limit(RECENT_LIMIT)
               .map { |command| serialize(command) }
  end

  def serialize(command)
    {
      id: command.id,
      command_type: known_command_type(command.command_type),
      state: command.state,
      occurred_at: command.created_at.iso8601
    }
  end

  # O modelo já recusa tipo fora da lista, mas o que está gravado de antes disso
  # não passou por essa recusa. O ecrã não mostra texto que não reconhece.
  def known_command_type(command_type)
    RaevoAiCommand::COMMAND_TYPES.include?(command_type) ? command_type : UNKNOWN_COMMAND
  end

  # Um comando que falhou é o que precisa de uma pessoa. Um que ficou em
  # `claimed` foi reclamado e nunca aplicado — normalmente porque a execução
  # morreu a meio, e é igualmente trabalho parado. Só conta depois de parado
  # tempo suficiente para não ser apenas trabalho a decorrer.
  def attention_for(integration)
    comandos = integration.raevo_ai_commands
    {
      failed: comandos.where(state: ATTENTION_STATES).count,
      pending: comandos.where(state: PENDING_STATE)
                       .where(created_at: ..STALE_PENDING_AFTER.ago)
                       .count
    }
  end

  def empty_attention
    { failed: 0, pending: 0 }
  end
end
