# Signing in deletes expired sessions by last_used_at; without an index that scans the whole table.
class AddLastUsedIndexToSessions < ActiveRecord::Migration[8.1]
  def change
    add_index :sessions, :last_used_at
  end
end
