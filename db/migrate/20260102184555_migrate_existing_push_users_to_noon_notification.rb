class MigrateExistingPushUsersToNoonNotification < ActiveRecord::Migration[8.1]
  def up
    execute <<-SQL
      UPDATE users
      SET notification_hours = '[12]'
      WHERE id IN (SELECT DISTINCT user_id FROM push_subscriptions)
    SQL
  end

  def down
    execute <<-SQL
      UPDATE users
      SET notification_hours = '[]'
    SQL
  end
end
