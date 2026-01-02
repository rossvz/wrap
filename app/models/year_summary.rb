class YearSummary
  include StreakCalculator
  include SummaryCalculations

  attr_reader :year_start

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

  def hours_by_month
    @hours_by_month ||= habit_logs
                          .select(:logged_on, Arel.sql("end_hour - start_hour AS duration"))
                          .group_by { |log| log.logged_on.strftime("%Y-%m") }
                          .transform_values { |logs| logs.sum { |l| l[:duration] } }
  end

  def chart_data
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

  def previous_year
    year_start - 1.year
  end

  def next_year
    year_start + 1.year
  end

  def can_navigate_next?
    next_year.beginning_of_year <= Date.current.beginning_of_year
  end

  def previous_period_date
    previous_year
  end

  def next_period_date
    next_year
  end

  def period_label
    year_start.year.to_s
  end

  def chart_title
    "Hours by Month"
  end

  private

  def months
    @months ||= (0..11).map { |i| year_start + i.months }
  end

  def hours_for_month(month)
    key = month.strftime("%Y-%m")
    (hours_by_month[key] || 0).round(1)
  end
end
