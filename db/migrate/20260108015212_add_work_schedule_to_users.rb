class AddWorkScheduleToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :work_schedule, :text, default: "{}", null: false
  end
end
