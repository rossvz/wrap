class Habit < ApplicationRecord
  has_many :habit_logs, dependent: :destroy

  validates :name, presence: true
  validates :color, presence: true

  def log_for(date)
    habit_logs.find_by(logged_on: date)
  end

  def minutes_for(date)
    log_for(date)&.duration_minutes.to_i
  end
end
