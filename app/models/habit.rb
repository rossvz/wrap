class Habit < ApplicationRecord
  has_many :habit_logs, dependent: :destroy

  validates :name, presence: true
  validates :color, presence: true

  after_initialize :set_defaults, if: :new_record?

  def set_defaults
    self.color ||= "#FDE047"
    self.active = true if self.active.nil?
  end

  def log_for(date)
    habit_logs.find_by(logged_on: date)
  end

  def minutes_for(date)
    log_for(date)&.duration_minutes.to_i
  end
end
