require "test_helper"

class WeekSummaryTest < ActiveSupport::TestCase
  test "initializes with user and date" do
    user = users(:one)
    summary = WeekSummary.new(user, Date.new(2025, 12, 21))

    assert_equal user, summary.user
    assert_equal Date.new(2025, 12, 15), summary.week_start
  end

  test "defaults to current week" do
    user = users(:one)
    summary = WeekSummary.new(user)

    assert_equal Date.current.beginning_of_week(:monday), summary.week_start
  end

  test "calculates week_end correctly" do
    user = users(:one)
    summary = WeekSummary.new(user, Date.new(2025, 12, 21))

    assert_equal Date.new(2025, 12, 21), summary.week_end
  end

  test "calculates total_hours from habit logs in the week" do
    user = users(:one)
    summary = WeekSummary.new(user, Date.new(2025, 12, 21))

    assert_equal 4.0, summary.total_hours
  end

  test "calculates daily_average correctly" do
    user = users(:one)
    summary = WeekSummary.new(user, Date.new(2025, 12, 21))

    assert_equal 4.0, summary.daily_average
  end

  test "counts active days" do
    user = users(:one)
    summary = WeekSummary.new(user, Date.new(2025, 12, 21))

    assert_equal 1, summary.active_days_count
  end

  test "hours_by_day groups hours by date" do
    user = users(:one)
    summary = WeekSummary.new(user, Date.new(2025, 12, 21))

    assert_equal 4.0, summary.hours_by_day[Date.new(2025, 12, 21)]
  end

  test "hours_by_habit returns habits sorted by hours" do
    user = users(:one)
    summary = WeekSummary.new(user, Date.new(2025, 12, 21))

    habits = summary.hours_by_habit
    assert_equal 2, habits.size
    assert_equal 2.0, habits.first[:hours]
    assert_includes habits.map { |h| h[:name] }, "Reading"
  end

  test "empty? returns true when no logs" do
    user = users(:one)
    summary = WeekSummary.new(user, Date.new(2020, 1, 1))

    assert summary.empty?
  end

  test "empty? returns false when logs exist" do
    user = users(:one)
    summary = WeekSummary.new(user, Date.new(2025, 12, 21))

    assert_not summary.empty?
  end

  test "chart_data returns data in Chart.js format" do
    user = users(:one)
    summary = WeekSummary.new(user, Date.new(2025, 12, 21))

    data = summary.chart_data
    assert_includes data.keys, :labels
    assert_includes data.keys, :datasets
    assert_equal 7, data[:labels].size
  end

  test "doughnut_chart_data returns habits with colors" do
    user = users(:one)
    summary = WeekSummary.new(user, Date.new(2025, 12, 21))

    data = summary.doughnut_chart_data
    assert_includes data.keys, :labels
    assert_includes data.keys, :datasets
    assert_equal 2, data[:labels].size
  end

  test "can_navigate_next? returns false for current week" do
    user = users(:one)
    summary = WeekSummary.new(user, Date.current)

    assert_not summary.can_navigate_next?
  end

  test "can_navigate_next? returns true for past week" do
    user = users(:one)
    summary = WeekSummary.new(user, Date.current - 2.weeks)

    assert summary.can_navigate_next?
  end

  test "previous_week_start returns correct date" do
    user = users(:one)
    summary = WeekSummary.new(user, Date.new(2025, 12, 21))

    assert_equal Date.new(2025, 12, 8), summary.previous_week_start
  end

  test "next_week_start returns correct date" do
    user = users(:one)
    summary = WeekSummary.new(user, Date.new(2025, 12, 21))

    assert_equal Date.new(2025, 12, 22), summary.next_week_start
  end

  test "period_label returns formatted date range" do
    user = users(:one)
    summary = WeekSummary.new(user, Date.new(2025, 12, 21))

    assert_match(/Dec 15/, summary.period_label)
    assert_match(/Dec 21/, summary.period_label)
  end

  test "chart_title returns Hours by Day" do
    user = users(:one)
    summary = WeekSummary.new(user)

    assert_equal "Hours by Day", summary.chart_title
  end

  test "previous_period_date delegates to previous_week_start" do
    user = users(:one)
    summary = WeekSummary.new(user, Date.new(2025, 12, 21))

    assert_equal summary.previous_week_start, summary.previous_period_date
  end

  test "next_period_date delegates to next_week_start" do
    user = users(:one)
    summary = WeekSummary.new(user, Date.new(2025, 12, 21))

    assert_equal summary.next_week_start, summary.next_period_date
  end
end
