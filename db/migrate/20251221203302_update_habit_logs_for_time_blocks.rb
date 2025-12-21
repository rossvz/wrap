class UpdateHabitLogsForTimeBlocks < ActiveRecord::Migration[8.1]
  def change
    # Add time block columns (decimal for future half-hour support: 7.0 = 7am, 7.5 = 7:30am)
    add_column :habit_logs, :start_hour, :decimal, precision: 3, scale: 1
    add_column :habit_logs, :end_hour, :decimal, precision: 3, scale: 1

    # Remove old unique constraint - we now allow multiple logs per habit per day
    remove_index :habit_logs, [ :habit_id, :logged_on ], unique: true

    # Add a regular (non-unique) index for querying
    add_index :habit_logs, [ :habit_id, :logged_on ]

    # Remove the old duration_minutes column
    remove_column :habit_logs, :duration_minutes, :integer
  end
end
