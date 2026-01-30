require "test_helper"

class HabitTest < ActiveSupport::TestCase
  # Validations
  test "requires name" do
    habit = Habit.new(color_token: 1)
    assert_not habit.valid?
    assert_includes habit.errors[:name], "can't be blank"
  end

  test "requires color_token" do
    habit = Habit.new(name: "Test")
    habit.color_token = nil
    assert_not habit.valid?
    assert_includes habit.errors[:color_token], "can't be blank"
  end

  test "color_token must be between 1 and 12" do
    user = users(:one)
    habit = user.habits.new(name: "Test")

    habit.color_token = 0
    assert_not habit.valid?

    habit.color_token = 13
    assert_not habit.valid?

    habit.color_token = 6
    assert habit.valid?
  end

  # Scopes
  test "with_tag finds habits with matching tag" do
    user = users(:one)
    habit = habits(:one)
    tag = user.tags.create!(name: "work")
    habit.tags << tag

    assert_includes Habit.with_tag("work"), habit
    assert_includes Habit.with_tag("WORK"), habit
    assert_not_includes Habit.with_tag("personal"), habit
  end

  test "with_any_tags finds habits with any matching tags" do
    user = users(:one)
    habit1 = habits(:one)
    habit2 = habits(:two)
    work_tag = user.tags.create!(name: "work")
    personal_tag = user.tags.create!(name: "personal")
    habit1.tags << work_tag
    habit2.tags << personal_tag

    result = Habit.with_any_tags([ "work", "personal" ])
    assert_includes result, habit1
    assert_includes result, habit2
  end

  # Color token assignment
  test "next_unused_token returns first available token" do
    user = users(:one)
    user.habits.destroy_all

    assert_equal 1, Habit.next_unused_token(user.habits)

    user.habits.create!(name: "H1", color_token: 1)
    assert_equal 2, Habit.next_unused_token(user.habits)

    user.habits.create!(name: "H2", color_token: 2)
    assert_equal 3, Habit.next_unused_token(user.habits)
  end

  test "next_unused_token cycles back when all used" do
    user = users(:one)
    user.habits.destroy_all

    (1..12).each do |token|
      user.habits.create!(name: "Habit #{token}", color_token: token)
    end

    assert_equal 1, Habit.next_unused_token(user.habits)
  end

  test "set_defaults assigns active true and next available color token" do
    user = users(:one)
    # Don't destroy existing habits - test that it finds next available
    used_tokens = user.habits.pluck(:color_token)
    expected_token = ((1..12).to_a - used_tokens).min || 1

    habit = user.habits.new(name: "New Habit")
    habit.valid?

    assert_equal true, habit.active
    assert_equal expected_token, habit.color_token
  end

  test "explicitly set color_token is preserved" do
    user = users(:one)
    habit = user.habits.new(name: "New Habit", color_token: 5)
    habit.valid?

    assert_equal 5, habit.color_token
  end

  # Color helpers
  test "color_css_var returns correct CSS variable" do
    habit = Habit.new(color_token: 3)
    assert_equal "var(--habit-color-3)", habit.color_css_var
  end

  test "color_class returns correct CSS class" do
    habit = Habit.new(color_token: 5)
    assert_equal "habit-bg-5", habit.color_class
  end

  # Log queries
  test "logs_for returns logs for specific date ordered by time" do
    habit = habits(:one)
    today = Date.current
    yesterday = Date.yesterday

    log1 = habit.habit_logs.create!(logged_on: today, start_hour: 14, end_hour: 15)
    log2 = habit.habit_logs.create!(logged_on: today, start_hour: 9, end_hour: 10)
    log3 = habit.habit_logs.create!(logged_on: yesterday, start_hour: 9, end_hour: 10)

    result = habit.logs_for(today)
    assert_equal [ log2, log1 ], result.to_a
    assert_not_includes result, log3
  end

  test "hours_for sums duration for date" do
    habit = habits(:one)
    today = Date.current

    habit.habit_logs.create!(logged_on: today, start_hour: 9, end_hour: 11)
    habit.habit_logs.create!(logged_on: today, start_hour: 14, end_hour: 15)

    assert_equal 3.0, habit.hours_for(today)
  end

  test "total_hours sums all log durations" do
    habit = habits(:one)
    habit.habit_logs.destroy_all

    habit.habit_logs.create!(logged_on: Date.current, start_hour: 9, end_hour: 11)
    habit.habit_logs.create!(logged_on: Date.yesterday, start_hour: 14, end_hour: 16)

    assert_equal 4.0, habit.total_hours
  end

  # Tags
  test "add_tags_by_names creates and assigns tags" do
    user = users(:one)
    habit = habits(:one)
    habit.tags.destroy_all

    habit.add_tags_by_names([ "Work", "  focus  ", "IMPORTANT" ], user)

    assert_equal 3, habit.tags.count
    assert_includes habit.tags.pluck(:name), "work"
    assert_includes habit.tags.pluck(:name), "focus"
    assert_includes habit.tags.pluck(:name), "important"
  end

  test "add_tags_by_names skips blank and long names" do
    user = users(:one)
    habit = habits(:one)
    habit.tags.destroy_all

    habit.add_tags_by_names([ "", "   ", "a" * 31, "valid" ], user)

    assert_equal 1, habit.tags.count
    assert_equal "valid", habit.tags.first.name
  end

  test "add_tags_by_names does not duplicate existing tags" do
    user = users(:one)
    habit = habits(:one)
    habit.tags.destroy_all
    existing_tag = user.tags.find_or_create_by!(name: "existing")
    habit.tags << existing_tag

    habit.add_tags_by_names([ "existing", "new" ], user)

    assert_equal 2, habit.tags.count
  end

  # find_or_create_for_user
  test "find_or_create_for_user finds existing habit by id" do
    user = users(:one)
    habit = habits(:one)

    result = Habit.find_or_create_for_user(user, habit_id: habit.id)

    assert_equal habit, result
  end

  test "find_or_create_for_user creates new habit with name" do
    user = users(:one)

    assert_difference("Habit.count") do
      result = Habit.find_or_create_for_user(user, habit_id: nil, new_habit_name: "  New Habit  ")
      assert_equal "New Habit", result.name
      assert_equal user, result.user
    end
  end

  test "find_or_create_for_user returns nil when no params provided" do
    user = users(:one)

    result = Habit.find_or_create_for_user(user, habit_id: nil, new_habit_name: nil)

    assert_nil result
  end

  test "find_or_create_for_user does not find other users habits" do
    user = users(:one)
    other_user = users(:two)
    other_habit = other_user.habits.create!(name: "Other Habit", color_token: 1)

    result = Habit.find_or_create_for_user(user, habit_id: other_habit.id)

    assert_nil result
  end
end
