class CreateTagsAndTaggings < ActiveRecord::Migration[8.1]
  def change
    create_table :tags do |t|
      t.string :name, null: false
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.integer :taggings_count, default: 0, null: false
      t.timestamps
    end

    add_index :tags, [ :user_id, :name ], unique: true
    add_index :tags, :name

    create_table :taggings do |t|
      t.references :tag, null: false, foreign_key: { on_delete: :cascade }
      t.references :habit, null: false, foreign_key: { on_delete: :cascade }
      t.timestamps
    end

    add_index :taggings, [ :habit_id, :tag_id ], unique: true
  end
end
