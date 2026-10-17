# RAEVO (17/10, 123jpnbcxh4) — o `ConversationFinder` sem a paginação do fim: o
# recorte inteiro da lista, para «selecionar as N do filtro».
class Raevo::ConversationFinderAll < ConversationFinder
  private

  attr_reader :conversations
end
