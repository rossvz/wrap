class AddUserToHabits < ActiveRecord::Migration[8.1]
  def change
    # Allow null initially to handle existing data - will be populated via rake task
    add_reference :habits, :user, foreign_key: true
  end
end
