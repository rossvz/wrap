class WeekSummary < BaseSummary
  alias_method :week_start, :period_start

  def week_end
    @week_end ||= week_start.end_of_week(:monday)
  end

  def period_end
    week_end
  end

  def previous_week_start
    week_start - 1.week
  end

  def next_week_start
    week_start + 1.week
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

  def normalize_date(date)
    date.beginning_of_week(:monday)
  end

  def chart_labels
    days.map { |d| d.strftime("%a") }
  end

  def chart_values
    days.map { |d| (hours_by_day[d] || 0).round(1) }
  end
end
