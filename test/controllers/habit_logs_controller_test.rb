require "test_helper"

class HabitLogsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @habit = habits(:one)
    @habit_log = habit_logs(:one)
    sign_in_as(@user)
  end

  test "should get index" do
    get habit_habit_logs_url(@habit)
    assert_response :success
  end

  test "should get edit" do
    get edit_habit_habit_log_url(@habit, @habit_log)
    assert_response :success
  end

  test "should create habit_log" do
    assert_difference("HabitLog.count") do
      post habit_logs_url, params: {
        habit_id: @habit.id,
        habit_log: { logged_on: Date.current, start_hour: 9, end_hour: 10 }
      }
    end
    assert_redirected_to dashboard_url
  end

  test "should create habit_log via turbo_stream" do
    assert_difference("HabitLog.count") do
      post habit_logs_url, params: {
        habit_id: @habit.id,
        habit_log: { logged_on: Date.current, start_hour: 9, end_hour: 10 }
      }, as: :turbo_stream
    end
    assert_response :success
  end

  test "should create habit_log and new habit when new_habit_name provided" do
    assert_difference([ "HabitLog.count", "Habit.count" ]) do
      post habit_logs_url, params: {
        habit_log: {
          logged_on: Date.current,
          start_hour: 9,
          end_hour: 10,
          new_habit_name: "Brand New Habit"
        }
      }
    end
    assert_equal "Brand New Habit", Habit.last.name
  end

  test "should redirect when no habit provided" do
    post habit_logs_url, params: {
      habit_log: { logged_on: Date.current, start_hour: 9, end_hour: 10 }
    }
    assert_redirected_to dashboard_url
    assert_equal "Could not find or create habit.", flash[:alert]
  end

  test "should update habit_log" do
    patch habit_habit_log_url(@habit, @habit_log), params: {
      habit_log: { start_hour: 10, end_hour: 12 }
    }
    assert_redirected_to habit_url(@habit)
    @habit_log.reload
    assert_equal 10, @habit_log.start_hour
    assert_equal 12, @habit_log.end_hour
  end

  test "should update habit_log via turbo_stream" do
    patch habit_habit_log_url(@habit, @habit_log), params: {
      habit_log: { start_hour: 10, end_hour: 12 }
    }, as: :turbo_stream
    assert_response :success
  end

  test "should update habit_log and change habit" do
    other_habit = habits(:two)
    patch habit_habit_log_url(@habit, @habit_log), params: {
      habit_log: { habit_id: other_habit.id, start_hour: 10, end_hour: 12 }
    }
    @habit_log.reload
    assert_equal other_habit.id, @habit_log.habit_id
  end

  test "should destroy habit_log" do
    assert_difference("HabitLog.count", -1) do
      delete habit_habit_log_url(@habit, @habit_log)
    end
    assert_redirected_to habit_url(@habit)
  end

  test "should destroy habit_log via turbo_stream" do
    assert_difference("HabitLog.count", -1) do
      delete habit_habit_log_url(@habit, @habit_log), as: :turbo_stream
    end
    assert_response :success
  end

  test "should redirect to login when not authenticated" do
    sign_out
    get habit_habit_logs_url(@habit)
    assert_redirected_to new_session_url
  end

  test "should not access other users habit logs" do
    other_user = users(:two)
    other_habit = other_user.habits.create!(name: "Other Habit", color_token: 1)
    other_log = other_habit.habit_logs.create!(logged_on: Date.current, start_hour: 9, end_hour: 10)

    get habit_habit_logs_url(other_habit)
    assert_response :not_found
  end
end
