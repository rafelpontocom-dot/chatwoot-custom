# Junta às contagens nativas as conversas por ler de quem pede (123jpnbcxh5).
# Entra por prepend (config/initializers/raevo_extensions.rb): o controlador e o
# contador do Chatwoot ficam como vieram.
module Raevo::UnreadCountsWithMine
  private

  def unread_counts
    super.merge(mine_count: Raevo::UnreadMineCount.new(account: Current.account, user: Current.user).count)
  end
end
