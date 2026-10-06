# Replaces the single plaintext users.auth_token with one row per signed-in browser.
# Only a SHA-256 hash of each token is stored, and each session expires.
class CreateSessions < ActiveRecord::Migration[7.1]
  def change
    create_table :sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :token_digest, null: false
      t.datetime :last_used_at, null: false
      t.timestamps
    end
    add_index :sessions, :token_digest, unique: true

    remove_index :users, :auth_token, unique: true
    remove_column :users, :auth_token, :string, null: false
  end
end
