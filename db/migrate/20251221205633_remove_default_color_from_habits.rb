class RemoveDefaultColorFromHabits < ActiveRecord::Migration[8.1]
  def change
    change_column_default :habits, :color, from: "#FDE047", to: nil
  end
end
