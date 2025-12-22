require "test_helper"

class DaySummaryTest < ActiveSupport::TestCase
  test "initializes with user and date" do
    user = users(:one)
    summary = DaySummary.new(user, Date.new(2025, 12, 21))

    assert_equal user, summary.user
    assert_equal Date.new(2025, 12, 21), summary.date
  end

  test "defaults to current date" do
    user = users(:one)
    summary = DaySummary.new(user)

    assert_equal Date.current, summary.date
  end

  test "returns active habits for user" do
    user = users(:one)
    summary = DaySummary.new(user)

    assert_includes summary.habits, habits(:one)
    assert_includes summary.habits, habits(:two)
  end

  test "returns time blocks for the date" do
    user = users(:one)
    summary = DaySummary.new(user, Date.new(2025, 12, 21))

    assert_equal 2, summary.time_blocks.count
    assert_includes summary.time_blocks, habit_logs(:one)
    assert_includes summary.time_blocks, habit_logs(:two)
  end

  test "calculates total hours" do
    user = users(:one)
    summary = DaySummary.new(user, Date.new(2025, 12, 21))

    # habit_logs(:one) is 9-11 (2h), habit_logs(:two) is 14-16 (2h)
    assert_equal 4.0, summary.total_hours
  end

  test "returns activity breakdown sorted by hours" do
    user = users(:one)
    summary = DaySummary.new(user, Date.new(2025, 12, 21))

    breakdown = summary.activity_breakdown
    assert_equal 2, breakdown.size
    assert_equal 2.0, breakdown.first[:hours]
  end

  test "empty? returns true when no time blocks" do
    user = users(:one)
    summary = DaySummary.new(user, Date.new(2020, 1, 1))

    assert summary.empty?
  end

  test "empty? returns false when time blocks exist" do
    user = users(:one)
    summary = DaySummary.new(user, Date.new(2025, 12, 21))

    assert_not summary.empty?
  end

  test "total_day_hours returns 18" do
    user = users(:one)
    summary = DaySummary.new(user)

    assert_equal 18, summary.total_day_hours
  end
end
