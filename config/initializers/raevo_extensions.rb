# Extensões do Raevo a classes nativas do Chatwoot. Ficam aqui, e não dentro do
# ficheiro nativo, para um upgrade não as levar sem conflito — ver «Onde mexer:
# os três anéis» em docs/raevo-chatwoot-upstream-maintenance.md.
Rails.application.config.to_prepare do
  Api::V1::Accounts::Conversations::UnreadCountsController.prepend(Raevo::UnreadCountsWithMine)
end
