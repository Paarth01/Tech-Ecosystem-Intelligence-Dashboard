class CreateComparisons < ActiveRecord::Migration[7.1]
  def change
    create_table :comparisons do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title, null: false
      t.json :items
      t.text :result, null: false
      t.boolean :ai_generated, null: false, default: false
      t.timestamps
    end
  end
end
