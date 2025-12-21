class Habit < ApplicationRecord
  COLORS = [
    { hex: "#FDE047", class: "bg-yellow-300" },
    { hex: "#BEF264", class: "bg-lime-300" },
    { hex: "#FDA4AF", class: "bg-rose-300" },
    { hex: "#F0ABFC", class: "bg-fuchsia-300" },
    { hex: "#7DD3FC", class: "bg-sky-300" },
    { hex: "#6EE7B7", class: "bg-emerald-300" },
    { hex: "#FDBA74", class: "bg-orange-300" },
    { hex: "#C4B5FD", class: "bg-violet-300" }
  ].freeze

  has_many :habit_logs, dependent: :destroy

  validates :name, presence: true
  validates :color, presence: true

  after_initialize :set_defaults, if: :new_record?

  def self.random_unused_color
    used_colors = pluck(:color).map(&:upcase)
    available_colors = COLORS.map { |c| c[:hex] }.reject { |hex| used_colors.include?(hex.upcase) }
    available_colors = COLORS.map { |c| c[:hex] } if available_colors.empty?
    available_colors.sample
  end

  def set_defaults
    self.color ||= Habit.random_unused_color
    self.active = true if self.active.nil?
  end

  def logs_for(date)
    habit_logs.for_date(date).ordered_by_time
  end

  def hours_for(date)
    logs_for(date).sum(&:duration_hours)
  end

  def total_hours
    habit_logs.sum(&:duration_hours)
  end
end
