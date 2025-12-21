class HabitLog < ApplicationRecord
  belongs_to :habit

  validates :logged_on, presence: true
  validates :start_hour, presence: true,
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 23.5 }
  validates :end_hour, presence: true,
            numericality: { greater_than_or_equal_to: 0.5, less_than_or_equal_to: 24 }
  validate :end_hour_after_start_hour

  scope :most_recent_first, -> { order(logged_on: :desc, start_hour: :desc) }
  scope :for_date, ->(date) { where(logged_on: date) }
  scope :ordered_by_time, -> { order(start_hour: :asc) }

  # Duration in hours (e.g., 2.0 for 2 hours, 1.5 for 1.5 hours)
  def duration_hours
    return 0 unless start_hour && end_hour
    end_hour - start_hour
  end

  # Duration in minutes for display/stats
  def duration_minutes
    (duration_hours * 60).to_i
  end

  # Format time for display (e.g., "7am", "7:30am")
  def formatted_start_time
    format_hour(start_hour)
  end

  def formatted_end_time
    format_hour(end_hour)
  end

  def time_range_display
    "#{formatted_start_time} - #{formatted_end_time}"
  end

  private

  def end_hour_after_start_hour
    return unless start_hour && end_hour
    if end_hour <= start_hour
      errors.add(:end_hour, "must be after start hour")
    end
  end

  def format_hour(hour)
    return nil unless hour
    h = hour.to_i
    m = ((hour % 1) * 60).to_i
    period = h >= 12 ? "pm" : "am"
    display_hour = h == 0 ? 12 : (h > 12 ? h - 12 : h)
    m.zero? ? "#{display_hour}#{period}" : "#{display_hour}:#{m.to_s.rjust(2, '0')}#{period}"
  end
end
