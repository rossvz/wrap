class AddTimeZoneToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :time_zone, :string

    reversible do |dir|
      dir.up do
        execute <<~SQL
          UPDATE users
          SET time_zone = (
            SELECT sessions.time_zone
            FROM sessions
            WHERE sessions.user_id = users.id
              AND sessions.time_zone IS NOT NULL
            ORDER BY sessions.updated_at DESC
            LIMIT 1
          )
        SQL
      end
    end
  end
end
