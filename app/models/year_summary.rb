class YearSummary
  include StreakCalculator

  attr_reader :user, :year_start

  def initialize(user, date = nil)
    @user = user
    @year_start = (date || Date.current).beginning_of_year
  end

  def year_end
    @year_end ||= year_start.end_of_year
  end

  def date_range
    year_start..year_end
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

  def hours_by_month
    @hours_by_month ||= HabitLog.joins(:habit)
                                .where(habits: { user_id: user.id })
                                .where(logged_on: date_range)
                                .group("strftime('%Y-%m', logged_on)")
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
      labels: months.map { |m| m.strftime("%b") },
      datasets: [ {
        label: "Hours",
        data: months.map { |m| hours_for_month(m) },
        backgroundColor: months.map.with_index { |_, i| bar_colors[i % bar_colors.size] },
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

  def previous_year
    year_start - 1.year
  end

  def next_year
    year_start + 1.year
  end

  def can_navigate_next?
    next_year.beginning_of_year <= Date.current.beginning_of_year
  end

  private

  def habit_logs
    HabitLog.joins(:habit)
            .where(habits: { user_id: user.id })
            .where(logged_on: date_range)
  end

  def months
    @months ||= (0..11).map { |i| year_start + i.months }
  end

  def hours_for_month(month)
    key = month.strftime("%Y-%m")
    (hours_by_month[key] || 0).round(1)
  end
end
