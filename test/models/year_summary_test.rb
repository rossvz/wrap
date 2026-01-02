require "test_helper"

class YearSummaryTest < ActiveSupport::TestCase
  test "initializes with user and date" do
    user = users(:one)
    summary = YearSummary.new(user, Date.new(2025, 6, 15))

    assert_equal user, summary.user
    assert_equal Date.new(2025, 1, 1), summary.year_start
  end

  test "defaults to current year" do
    user = users(:one)
    summary = YearSummary.new(user)

    assert_equal Date.current.beginning_of_year, summary.year_start
  end

  test "calculates year_end correctly" do
    user = users(:one)
    summary = YearSummary.new(user, Date.new(2025, 6, 15))

    assert_equal Date.new(2025, 12, 31), summary.year_end
  end

  test "calculates total_hours from habit logs in the year" do
    user = users(:one)
    summary = YearSummary.new(user, Date.new(2025, 12, 21))

    assert_equal 4.0, summary.total_hours
  end

  test "calculates daily_average correctly" do
    user = users(:one)
    summary = YearSummary.new(user, Date.new(2025, 12, 21))

    assert_equal 4.0, summary.daily_average
  end

  test "counts active days" do
    user = users(:one)
    summary = YearSummary.new(user, Date.new(2025, 12, 21))

    assert_equal 1, summary.active_days_count
  end

  test "hours_by_habit returns habits sorted by hours" do
    user = users(:one)
    summary = YearSummary.new(user, Date.new(2025, 12, 21))

    habits = summary.hours_by_habit
    assert_equal 2, habits.size
    assert_equal 2.0, habits.first[:hours]
  end

  test "empty? returns true when no logs" do
    user = users(:one)
    summary = YearSummary.new(user, Date.new(2020, 1, 1))

    assert summary.empty?
  end

  test "empty? returns false when logs exist" do
    user = users(:one)
    summary = YearSummary.new(user, Date.new(2025, 12, 21))

    assert_not summary.empty?
  end

  test "chart_data returns monthly data in Chart.js format" do
    user = users(:one)
    summary = YearSummary.new(user, Date.new(2025, 12, 21))

    data = summary.chart_data
    assert_includes data.keys, :labels
    assert_includes data.keys, :datasets
    assert_equal 12, data[:labels].size
    assert_equal "Jan", data[:labels].first
  end

  test "doughnut_chart_data returns habits with colors" do
    user = users(:one)
    summary = YearSummary.new(user, Date.new(2025, 12, 21))

    data = summary.doughnut_chart_data
    assert_includes data.keys, :labels
    assert_includes data.keys, :datasets
    assert_equal 2, data[:labels].size
  end

  test "can_navigate_next? returns false for current year" do
    user = users(:one)
    summary = YearSummary.new(user, Date.current)

    assert_not summary.can_navigate_next?
  end

  test "can_navigate_next? returns true for past year" do
    user = users(:one)
    summary = YearSummary.new(user, Date.current - 2.years)

    assert summary.can_navigate_next?
  end

  test "previous_year returns correct date" do
    user = users(:one)
    summary = YearSummary.new(user, Date.new(2025, 6, 15))

    assert_equal Date.new(2024, 1, 1), summary.previous_year
  end

  test "next_year returns correct date" do
    user = users(:one)
    summary = YearSummary.new(user, Date.new(2025, 6, 15))

    assert_equal Date.new(2026, 1, 1), summary.next_year
  end
end
