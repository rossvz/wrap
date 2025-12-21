json.extract! habit, :id, :name, :description, :color, :active, :created_at, :updated_at
json.url habit_url(habit, format: :json)
