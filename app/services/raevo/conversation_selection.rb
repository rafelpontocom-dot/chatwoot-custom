# RAEVO (17/10, 123jpnbcxh4) — as conversas sobre as quais uma ação em massa age.
#
# Três formas de dizer quais, as mesmas que a lista usa para as mostrar:
# - `ids`: as que a pessoa marcou (números visíveis, `display_id`, como o nativo);
# - `filters`: o recorte simples da lista (aba, estado, caixa, etiqueta, time);
# - `query`: o filtro avançado ou a pasta guardada.
#
# Nas duas últimas reaproveita o `ConversationFinder` e o `Conversations::FilterService`
# sem a paginação: «selecionar as 312 do filtro» é exatamente o que a lista mostraria
# se se carregasse até ao fim, com as mesmas permissões de quem pede.
class Raevo::ConversationSelection
  MAX = 5000

  def initialize(account:, user:, scope:)
    @account = account
    @user = user
    @scope = scope.to_h.with_indifferent_access
  end

  def display_ids
    relation.reorder(nil).limit(MAX).pluck(:display_id)
  end

  def count
    [relation.reorder(nil).count(:all), MAX].min
  end

  private

  def relation
    @relation ||= if @scope.key?(:ids)
                    by_ids
                  elsif @scope.key?(:query)
                    Raevo::ConversationFilterAll.new({ payload: Array(@scope[:query]) }.with_indifferent_access, @user, @account)
                                                .perform[:conversations]
                  else
                    Raevo::ConversationFinderAll.new(@user, @scope[:filters].to_h.with_indifferent_access).perform[:conversations]
                  end
  end

  def by_ids
    conversations = @account.conversations.where(display_id: Array(@scope[:ids]))
    Conversations::PermissionFilterService.new(conversations, @user, @account).perform
  end
end
