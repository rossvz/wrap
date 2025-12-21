require "test_helper"

class HabitsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @habit = habits(:one)
    sign_in_as(@user)
  end

  test "should get index" do
    get habits_url
    assert_response :success
  end

  test "should get new" do
    get new_habit_url
    assert_response :success
  end

  test "should create habit" do
    assert_difference("Habit.count") do
      post habits_url, params: { habit: { active: @habit.active, color_token: @habit.color_token, description: @habit.description, name: @habit.name } }
    end

    assert_redirected_to habit_url(Habit.last)
  end

  test "should show habit" do
    get habit_url(@habit)
    assert_response :success
  end

  test "should get edit" do
    get edit_habit_url(@habit)
    assert_response :success
  end

  test "should update habit" do
    patch habit_url(@habit), params: { habit: { active: @habit.active, color_token: @habit.color_token, description: @habit.description, name: @habit.name } }
    assert_redirected_to habit_url(@habit)
  end

  test "should destroy habit" do
    assert_difference("Habit.count", -1) do
      delete habit_url(@habit)
    end

    assert_redirected_to habits_url
  end

  test "should redirect to login when not authenticated" do
    sign_out
    get habits_url
    assert_redirected_to new_session_url
  end

  test "should not access other users habits" do
    other_user = users(:two)
    other_habit = other_user.habits.create!(name: "Other Habit", color_token: 1)

    # The controller scopes to current_user.habits.find() so this should 404
    get habit_url(other_habit)
    assert_response :not_found
  end
end
