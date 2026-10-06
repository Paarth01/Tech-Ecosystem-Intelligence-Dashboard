class CreateSavedArticles < ActiveRecord::Migration[7.1]
  def change
    create_table :saved_articles do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title, null: false
      t.string :url, null: false
      t.string :source
      t.text :description
      t.string :meta
      t.string :author
      t.string :date
      t.json :tags
      t.timestamps
    end
    add_index :saved_articles, %i[user_id url], unique: true
  end
end
