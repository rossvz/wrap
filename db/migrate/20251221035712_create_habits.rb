class CreateHabits < ActiveRecord::Migration[8.1]
  def change
    create_table :habits do |t|
      t.string :name, null: false
      t.text :description
      t.string :color, null: false, default: "#FDE047"
      t.boolean :active, null: false, default: true

      t.timestamps
    end
  end
end
