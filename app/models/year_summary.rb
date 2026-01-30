class YearSummary < BaseSummary
  alias_method :year_start, :period_start

  def year_end
    @year_end ||= year_start.end_of_year
  end

  def period_end
    year_end
  end

  def hours_by_month
    @hours_by_month ||= habit_logs
                          .select(:logged_on, Arel.sql("end_hour - start_hour AS duration"))
                          .group_by { |log| log.logged_on.strftime("%Y-%m") }
                          .transform_values { |logs| logs.sum { |l| l[:duration] } }
  end

  def previous_year
    year_start - 1.year
  end

  def next_year
    year_start + 1.year
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

  def normalize_date(date)
    date.beginning_of_year
  end

  def months
    @months ||= (0..11).map { |i| year_start + i.months }
  end

  def chart_labels
    months.map { |m| m.strftime("%b") }
  end

  def chart_values
    months.map { |m| hours_for_month(m) }
  end

  def hours_for_month(month)
    key = month.strftime("%Y-%m")
    (hours_by_month[key] || 0).round(1)
  end
end
