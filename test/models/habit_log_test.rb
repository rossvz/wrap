require "test_helper"

class HabitLogTest < ActiveSupport::TestCase
  # Validations
  test "validates logged_on presence" do
    habit = habits(:one)
    log = habit.habit_logs.build(start_hour: 9, end_hour: 10)
    assert_not log.valid?
    assert_includes log.errors[:logged_on], "can't be blank"
  end

  test "validates start_hour range" do
    habit = habits(:one)

    log = habit.habit_logs.build(logged_on: Date.current, start_hour: -1, end_hour: 10)
    assert_not log.valid?

    log = habit.habit_logs.build(logged_on: Date.current, start_hour: 24, end_hour: 24)
    assert_not log.valid?

    log = habit.habit_logs.build(logged_on: Date.current, start_hour: 23.5, end_hour: 24)
    assert log.valid?
  end

  test "validates end_hour range" do
    habit = habits(:one)

    log = habit.habit_logs.build(logged_on: Date.current, start_hour: 0, end_hour: 0)
    assert_not log.valid?

    log = habit.habit_logs.build(logged_on: Date.current, start_hour: 0, end_hour: 25)
    assert_not log.valid?

    log = habit.habit_logs.build(logged_on: Date.current, start_hour: 23, end_hour: 24)
    assert log.valid?
  end

  # Scopes
  test "most_recent_first orders by date desc then start_hour desc" do
    habit = habits(:one)
    habit.habit_logs.destroy_all

    log1 = habit.habit_logs.create!(logged_on: Date.yesterday, start_hour: 9, end_hour: 10)
    log2 = habit.habit_logs.create!(logged_on: Date.current, start_hour: 14, end_hour: 15)
    log3 = habit.habit_logs.create!(logged_on: Date.current, start_hour: 9, end_hour: 10)

    result = habit.habit_logs.most_recent_first
    assert_equal [ log2, log3, log1 ], result.to_a
  end

  test "for_date returns only logs for that date" do
    habit = habits(:one)
    habit.habit_logs.destroy_all
    today = Date.current

    log1 = habit.habit_logs.create!(logged_on: today, start_hour: 9, end_hour: 10)
    log2 = habit.habit_logs.create!(logged_on: Date.yesterday, start_hour: 9, end_hour: 10)

    result = HabitLog.for_date(today)
    assert_includes result, log1
    assert_not_includes result, log2
  end

  test "for_user returns only logs for that user" do
    user1 = users(:one)
    user2 = users(:two)
    habit1 = habits(:one)
    habit2 = user2.habits.create!(name: "Other", color_token: 1)

    habit1.habit_logs.destroy_all
    log1 = habit1.habit_logs.create!(logged_on: Date.current, start_hour: 9, end_hour: 10)
    log2 = habit2.habit_logs.create!(logged_on: Date.current, start_hour: 9, end_hour: 10)

    result = HabitLog.for_user(user1)
    assert_includes result, log1
    assert_not_includes result, log2
  end

  test "ordered_by_time orders by start_hour asc" do
    habit = habits(:one)
    habit.habit_logs.destroy_all
    today = Date.current

    log1 = habit.habit_logs.create!(logged_on: today, start_hour: 14, end_hour: 15)
    log2 = habit.habit_logs.create!(logged_on: today, start_hour: 9, end_hour: 10)

    result = habit.habit_logs.ordered_by_time
    assert_equal [ log2, log1 ], result.to_a
  end

  # Duration calculations
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

  test "formatted times handle half hours" do
    log = HabitLog.new(start_hour: 9.5, end_hour: 11.5)
    assert_equal "9:30am", log.formatted_start_time
    assert_equal "11:30am", log.formatted_end_time
  end

  test "formatted times handle noon" do
    log = HabitLog.new(start_hour: 12, end_hour: 13)
    assert_equal "12pm", log.formatted_start_time
    assert_equal "1pm", log.formatted_end_time
  end

  test "formatted times handle midnight" do
    log = HabitLog.new(start_hour: 0, end_hour: 1)
    assert_equal "12am", log.formatted_start_time
    assert_equal "1am", log.formatted_end_time
  end

  test "duration_hours returns 0 when missing values" do
    log = HabitLog.new
    assert_equal 0, log.duration_hours

    log.start_hour = 9
    assert_equal 0, log.duration_hours
  end

  test "duration_hours handles half hours" do
    log = HabitLog.new(start_hour: 9.5, end_hour: 11)
    assert_equal 1.5, log.duration_hours
  end

  test "show_extended_details? returns true for long sessions" do
    log = HabitLog.new(start_hour: 9, end_hour: 11)
    assert log.show_extended_details?

    log = HabitLog.new(start_hour: 9, end_hour: 10.5)
    assert_not log.show_extended_details?
  end
end
