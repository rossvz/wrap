class AddColorTokenToHabits < ActiveRecord::Migration[8.1]
  # Map existing hex colors to tokens
  HEX_TO_TOKEN = {
    "#FDE047" => 1, # yellow
    "#BEF264" => 2, # lime
    "#FDA4AF" => 3, # rose
    "#F0ABFC" => 4, # fuchsia
    "#7DD3FC" => 5, # sky
    "#6EE7B7" => 6, # emerald
    "#FDBA74" => 7, # orange
    "#C4B5FD" => 8  # violet
  }.freeze

  def up
    add_column :habits, :color_token, :integer

    # Migrate existing colors to tokens
    execute <<-SQL.squish
      UPDATE habits SET color_token = CASE UPPER(color)
        WHEN '#FDE047' THEN 1
        WHEN '#BEF264' THEN 2
        WHEN '#FDA4AF' THEN 3
        WHEN '#F0ABFC' THEN 4
        WHEN '#7DD3FC' THEN 5
        WHEN '#6EE7B7' THEN 6
        WHEN '#FDBA74' THEN 7
        WHEN '#C4B5FD' THEN 8
        ELSE 1
      END
    SQL

    change_column_null :habits, :color_token, false
    change_column_default :habits, :color_token, 1

    # Remove old color column
    remove_column :habits, :color
  end

  def down
    add_column :habits, :color, :string

    # Restore colors from tokens
    execute <<-SQL.squish
      UPDATE habits SET color = CASE color_token
        WHEN 1 THEN '#FDE047'
        WHEN 2 THEN '#BEF264'
        WHEN 3 THEN '#FDA4AF'
        WHEN 4 THEN '#F0ABFC'
        WHEN 5 THEN '#7DD3FC'
        WHEN 6 THEN '#6EE7B7'
        WHEN 7 THEN '#FDBA74'
        WHEN 8 THEN '#C4B5FD'
        ELSE '#FDE047'
      END
    SQL

    change_column_null :habits, :color, false
    remove_column :habits, :color_token
  end
end
