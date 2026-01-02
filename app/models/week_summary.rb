class WeekSummary
  include StreakCalculator
  include SummaryCalculations

  attr_reader :week_start

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

  def chart_data
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

  def previous_week_start
    week_start - 1.week
  end

  def next_week_start
    week_start + 1.week
  end

  def can_navigate_next?
    next_week_start.beginning_of_week(:monday) <= Date.current.beginning_of_week(:monday)
  end

  def previous_period_date
    previous_week_start
  end

  def next_period_date
    next_week_start
  end

  def period_label
    "#{week_start.strftime('%b %-d')} – #{week_end.strftime('%b %-d, %Y')}"
  end

  def chart_title
    "Hours by Day"
  end

  private

  def days
    @days ||= date_range.to_a
  end
end
