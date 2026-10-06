class AddEmailTokensAndTrendSnapshots < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :email_verified_at, :datetime

    # Single-use links sent by email (password reset, email verification). Only a hash is stored.
    create_table :email_tokens do |t|
      t.references :user, null: false, foreign_key: true
      t.string :purpose, null: false
      t.string :token_digest, null: false
      t.datetime :expires_at, null: false
      t.timestamps
    end
    add_index :email_tokens, :token_digest, unique: true

    # Hourly record of topic scores, used to show what is rising or falling.
    create_table :trend_snapshots do |t|
      t.string :tag, null: false
      t.float :score, null: false
      t.datetime :captured_at, null: false
    end
    add_index :trend_snapshots, :captured_at
  end
end
