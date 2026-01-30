class MonthSummary < BaseSummary
  alias_method :month_start, :period_start

  def month_end
    @month_end ||= month_start.end_of_month
  end

  def period_end
    month_end
  end

  def previous_month
    month_start - 1.month
  end

  def next_month
    month_start + 1.month
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

  def normalize_date(date)
    date.beginning_of_month
  end

  def chart_labels
    days.map { |d| d.day.to_s }
  end

  def chart_values
    days.map { |d| (hours_by_day[d] || 0).round(1) }
  end
end
