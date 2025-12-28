require "test_helper"

class HabitTest < ActiveSupport::TestCase
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
