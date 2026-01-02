class MonthSummary
  include StreakCalculator
  include SummaryCalculations

  attr_reader :month_start

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

  def chart_data
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

  def previous_month
    month_start - 1.month
  end

  def next_month
    month_start + 1.month
  end

  def can_navigate_next?
    next_month.beginning_of_month <= Date.current.beginning_of_month
  end

  def previous_period_date
    previous_month
  end

  def next_period_date
    next_month
  end

  def period_label
    month_start.strftime("%B %Y")
  end

  def chart_title
    "Hours by Day"
  end

  private

  def days
    @days ||= date_range.to_a
  end
end
