class BaseSummary
  include StreakCalculator
  include SummaryCalculations

  attr_reader :period_start

  def initialize(user, date = nil)
    @user = user
    @period_start = normalize_date(date || Date.current)
  end

  def date_range
    period_start..period_end
  end

  def chart_data
    {
      labels: chart_labels,
      datasets: [ {
        label: "Hours",
        data: chart_values,
        backgroundColor: chart_labels.map.with_index { |_, i| bar_colors[i % bar_colors.size] },
        borderColor: "var(--ink-color)",
        borderWidth: 2
      } ]
    }
  end

  def can_navigate_next?
    normalize_date(next_period_date) <= normalize_date(Date.current)
  end

  # Abstract methods - subclasses must implement
  def period_end
    raise NotImplementedError, "#{self.class} must implement #period_end"
  end

  def previous_period_date
    raise NotImplementedError, "#{self.class} must implement #previous_period_date"
  end

  def next_period_date
    raise NotImplementedError, "#{self.class} must implement #next_period_date"
  end

  def period_label
    raise NotImplementedError, "#{self.class} must implement #period_label"
  end

  def chart_title
    raise NotImplementedError, "#{self.class} must implement #chart_title"
  end

  private

  def normalize_date(date)
    raise NotImplementedError, "#{self.class} must implement #normalize_date"
  end

  def chart_labels
    raise NotImplementedError, "#{self.class} must implement #chart_labels"
  end

  def chart_values
    raise NotImplementedError, "#{self.class} must implement #chart_values"
  end

  def days
    @days ||= date_range.to_a
  end
end
