class RepointAppointmentRemindersToCalendarField < ActiveRecord::Migration[7.1]
  # A data de inicio do card era o campo por omissao das regras de lembrete, e
  # nada a mantinha em sincronia: marcar ou remarcar consulta na Agenda nao lhe
  # tocava. O lembrete saia na data velha, ou nao saia.
  #
  # A Agenda ja espelha a data da proxima consulta num campo do card a cada
  # marcacao, remarcacao e cancelamento. As regras passam a ler esse campo.
  def up
    say "#{repoint!} rule(s) now read the field the calendar keeps in sync"

    # Sem campo da Agenda no quadro nao ha para onde apontar. Desativar a regra
    # por conta propria calaria um lembrete que talvez ainda saia, e essa e uma
    # decisao de quem atende, nao desta migracao.
    orphans = select_all(<<~SQL.squish).rows.flatten
      SELECT id FROM kanban_appointment_reminder_rules WHERE field_key = 'system_starts_at'
    SQL
    say "rule(s) left untouched, board has no calendar field: #{orphans.join(', ')}" if orphans.any?
  end

  # Reverter e desnecessario e nao seria seguro: a chave antiga apontava para um
  # campo que ja ninguem preenche. Uma regra repontada funciona com o codigo
  # antigo e com o novo, porque os dois leem `custom_field_values[field_key]`
  # para qualquer chave que nao seja a de sistema — voltar atras so devolveria
  # o defeito.
  def down; end

  private

  def repoint!
    execute(<<~SQL.squish).cmd_tuples
      UPDATE kanban_appointment_reminder_rules AS rules
         SET field_key = boards.calendar_legacy_next_appointment_field_key,
             updated_at = NOW()
        FROM kanban_boards AS boards
       WHERE rules.kanban_board_id = boards.id
         AND rules.field_key = 'system_starts_at'
         AND COALESCE(boards.calendar_legacy_next_appointment_field_key, '') <> ''
    SQL
  end
end
