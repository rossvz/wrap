class AddTimeZoneToSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :sessions, :time_zone, :string
  end
end
