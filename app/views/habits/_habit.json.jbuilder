json.extract! habit, :id, :name, :description, :color_token, :active, :created_at, :updated_at
json.url habit_url(habit, format: :json)
json.tags habit.tags do |tag|
  json.extract! tag, :id, :name
end
