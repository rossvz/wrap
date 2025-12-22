class DaySummary
  START_HOUR = 6
  END_HOUR = 24

  attr_reader :user, :date

  def initialize(user, date = Date.current)
    @user = user
    @date = date
  end

  def habits
    @habits ||= user.habits.where(active: true).order(created_at: :asc)
  end

  def time_blocks
    @time_blocks ||= HabitLog.includes(:habit)
                             .where(logged_on: date, habit_id: habits.select(:id))
                             .order(:start_hour)
  end

  def total_hours
    @total_hours ||= time_blocks.sum(&:duration_hours).round(1)
  end

  # Returns array of { habit: Habit, hours: Float } sorted by most hours
  def activity_breakdown
    @activity_breakdown ||= time_blocks.group_by(&:habit).map do |habit, logs|
      { habit: habit, hours: logs.sum(&:duration_hours) }
    end.sort_by { |entry| -entry[:hours] }
  end

  # Total hours in the day view (6am to midnight)
  def total_day_hours
    END_HOUR - START_HOUR
  end

  def empty?
    time_blocks.empty?
  end
end
