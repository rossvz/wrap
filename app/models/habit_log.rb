class HabitLog < ApplicationRecord
  belongs_to :habit

  validates :logged_on, presence: true, uniqueness: { scope: :habit_id }
  validates :duration_minutes, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :most_recent_first, -> { order(logged_on: :desc, created_at: :desc) }
end
