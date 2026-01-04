module SummaryCalculations
  extend ActiveSupport::Concern

  included do
    attr_reader :user
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

  private

  def habit_logs
    HabitLog.joins(:habit)
            .where(habits: { user_id: user.id })
            .where(logged_on: date_range)
  end

  def bar_colors
    @bar_colors ||= Habit::COLOR_TOKENS.map { |i| "var(--habit-color-#{i})" }
  end
end
