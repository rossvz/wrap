class MonthSummary
  include StreakCalculator

  attr_reader :user, :month_start

  def initialize(user, date = nil)
    @user = user
    @month_start = (date || Date.current).beginning_of_month
  end

  def month_end
    @month_end ||= month_start.end_of_month
  end

  def date_range
    month_start..month_end
  end

  def total_hours
    @total_hours ||= habit_logs.sum("end_hour - start_hour").round(1)
  end

  def daily_average
    return 0.0 if active_days_count.zero?
    (total_hours / active_days_count.to_f).round(1)
  end

  def active_days_count
    @active_days_count ||= habit_logs.distinct.count(:logged_on)
  end

  def hours_by_day
    @hours_by_day ||= HabitLog.joins(:habit)
                              .where(habits: { user_id: user.id })
                              .where(logged_on: date_range)
                              .group(:logged_on)
                              .sum("end_hour - start_hour")
  end

  def hours_by_habit
    @hours_by_habit ||= HabitLog
      .joins(:habit)
      .where(habits: { user_id: user.id, active: true })
      .where(logged_on: date_range)
      .group("habits.id", "habits.name", "habits.color_token")
      .sum("end_hour - start_hour")
      .map { |(id, name, color_token), hours|
        { habit_id: id, name: name, color_token: color_token, hours: hours.round(1) }
      }
      .select { |h| h[:hours] > 0 }
      .sort_by { |h| -h[:hours] }
  end

  def empty?
    total_hours.zero?
  end

  def chart_data
    bar_colors = (1..8).map { |i| "var(--habit-color-#{i})" }
    {
      labels: days.map { |d| d.day.to_s },
      datasets: [ {
        label: "Hours",
        data: days.map { |d| (hours_by_day[d] || 0).round(1) },
        backgroundColor: days.map.with_index { |_, i| bar_colors[i % bar_colors.size] },
        borderColor: "var(--ink-color)",
        borderWidth: 2
      } ]
    }
  end

  def doughnut_chart_data
    habits = hours_by_habit
    {
      labels: habits.map { |h| h[:name] },
      datasets: [ {
        data: habits.map { |h| h[:hours] },
        backgroundColor: habits.map { |h| "var(--habit-color-#{h[:color_token]})" },
        borderColor: "var(--ink-color)",
        borderWidth: 2
      } ]
    }
  end

  def previous_month
    month_start - 1.month
  end

  def next_month
    month_start + 1.month
  end

  def can_navigate_next?
    next_month.beginning_of_month <= Date.current.beginning_of_month
  end

  private

  def habit_logs
    HabitLog.joins(:habit)
            .where(habits: { user_id: user.id })
            .where(logged_on: date_range)
  end

  def days
    @days ||= date_range.to_a
  end
end
