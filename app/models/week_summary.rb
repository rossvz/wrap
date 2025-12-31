class WeekSummary
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

  def empty?
    total_hours.zero?
  end

  def chart_data
    {
      labels: days.map { |d| d.strftime("%a") },
      datasets: [ {
        label: "Hours",
        data: days.map { |d| (hours_by_day[d] || 0).round(1) },
        backgroundColor: "var(--accent-primary)",
        borderColor: "#000",
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

  def current_week?
    week_start >= Date.current.beginning_of_week(:monday)
  end

  private

  def days
    date_range.to_a
  end
end
