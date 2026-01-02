class AddNotificationHoursToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :notification_hours, :text, default: "[]", null: false
  end
end
