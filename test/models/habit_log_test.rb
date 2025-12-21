require "test_helper"

class HabitLogTest < ActiveSupport::TestCase
  test "duration_hours calculates correctly" do
    log = HabitLog.new(start_hour: 9, end_hour: 11)
    assert_equal 2, log.duration_hours
  end

  test "duration_minutes calculates correctly" do
    log = HabitLog.new(start_hour: 9, end_hour: 11)
    assert_equal 120, log.duration_minutes
  end

  test "validates end_hour after start_hour" do
    habit = habits(:one)
    log = habit.habit_logs.build(logged_on: Date.current, start_hour: 10, end_hour: 9)
    assert_not log.valid?
    assert_includes log.errors[:end_hour], "must be after start hour"
  end

  test "validates start_hour presence" do
    habit = habits(:one)
    log = habit.habit_logs.build(logged_on: Date.current, end_hour: 10)
    assert_not log.valid?
    assert_includes log.errors[:start_hour], "can't be blank"
  end

  test "validates end_hour presence" do
    habit = habits(:one)
    log = habit.habit_logs.build(logged_on: Date.current, start_hour: 9)
    assert_not log.valid?
    assert_includes log.errors[:end_hour], "can't be blank"
  end

  test "formatted_start_time displays correctly" do
    log = HabitLog.new(start_hour: 9)
    assert_equal "9am", log.formatted_start_time

    log = HabitLog.new(start_hour: 14)
    assert_equal "2pm", log.formatted_start_time

    log = HabitLog.new(start_hour: 0)
    assert_equal "12am", log.formatted_start_time
  end

  test "time_range_display shows full range" do
    log = HabitLog.new(start_hour: 9, end_hour: 11)
    assert_equal "9am - 11am", log.time_range_display
  end
end
