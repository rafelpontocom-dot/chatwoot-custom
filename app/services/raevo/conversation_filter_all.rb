# RAEVO (17/10, 123jpnbcxh4) — o filtro avançado (e as pastas) sem a paginação do
# fim, para «selecionar as N do filtro».
class Raevo::ConversationFilterAll < Conversations::FilterService
  attr_reader :conversations
end
