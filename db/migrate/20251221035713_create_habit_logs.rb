class CreateHabitLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :habit_logs do |t|
      t.references :habit, null: false, foreign_key: true
      t.date :logged_on, null: false
      t.integer :duration_minutes, null: false, default: 0
      t.text :notes

      t.timestamps
    end

    add_index :habit_logs, [ :habit_id, :logged_on ], unique: true
  end
end
