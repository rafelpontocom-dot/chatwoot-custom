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
      command_type: command.command_type,
      state: command.state,
      occurred_at: command.created_at.iso8601
    }
  end

  # Um comando que falhou é o que precisa de uma pessoa. Um que ficou em
  # `claimed` foi reclamado e nunca aplicado — normalmente porque a execução
  # morreu a meio, e é igualmente trabalho parado.
  def attention_for(integration)
    counts = integration.raevo_ai_commands
                        .where(state: ATTENTION_STATES + [PENDING_STATE])
                        .group(:state)
                        .count
    {
      failed: ATTENTION_STATES.sum { |state| counts.fetch(state, 0) },
      pending: counts.fetch(PENDING_STATE, 0)
    }
  end

  def empty_attention
    { failed: 0, pending: 0 }
  end
end
