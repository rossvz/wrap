class AddInsightsIndex < ActiveRecord::Migration[8.1]
  def change
    add_index :habit_logs, [ :logged_on, :habit_id ],
              name: "index_habit_logs_on_logged_on_and_habit_id"
  end
end
