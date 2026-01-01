class WeekSummary
  include StreakCalculator

  attr_reader :user, :week_start

  def initialize(user, date = nil)
    @user = user
    @week_start = (date || Date.current).beginning_of_week(:monday)
  end

  def week_end
    @week_end ||= week_start.end_of_week(:monday)
  end

  def date_range
    week_start..week_end
  end

  def hours_by_day
    @hours_by_day ||= HabitLog.joins(:habit)
                              .where(habits: { user_id: user.id })
                              .where(logged_on: date_range)
                              .group(:logged_on)
                              .sum("end_hour - start_hour")
  end

  def total_hours
    @total_hours ||= hours_by_day.values.sum.round(1)
  end

  def daily_average
    return 0.0 if active_days_count.zero?
    (total_hours / active_days_count.to_f).round(1)
  end

  def active_days_count
    @active_days_count ||= habit_logs.distinct.count(:logged_on)
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
      labels: days.map { |d| d.strftime("%a") },
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

  def previous_week_start
    week_start - 1.week
  end

  def next_week_start
    week_start + 1.week
  end

  def can_navigate_next?
    next_week_start.beginning_of_week(:monday) <= Date.current.beginning_of_week(:monday)
  end

  def current_week?
    week_start >= Date.current.beginning_of_week(:monday)
  end

  private

  def habit_logs
    HabitLog.joins(:habit)
            .where(habits: { user_id: user.id })
            .where(logged_on: date_range)
  end

  def days
    date_range.to_a
  end
end
