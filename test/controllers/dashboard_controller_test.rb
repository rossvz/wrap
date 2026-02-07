require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test "should get index" do
    get dashboard_url
    assert_response :success
  end

  test "root goes to dashboard" do
    get root_url
    assert_response :success
  end

  test "should redirect to login when not authenticated" do
    sign_out
    get dashboard_url
    assert_redirected_to new_session_url
  end

  test "dashboard respects timezone cookie" do
    travel_to Time.utc(2025, 12, 30, 1, 0, 0) do
      cookies[:timezone] = "America/Los_Angeles"
      get dashboard_url

      assert_response :success
      assert_includes @response.body, "December 29, 2025"
    end
  end

  test "dashboard shows specific date when date param provided" do
    get dashboard_url(date: "2025-06-15")
    assert_response :success
    assert_includes @response.body, "June 15, 2025"
    assert_includes @response.body, "Sunday"
  end

  test "dashboard falls back to today for invalid date param" do
    travel_to Time.utc(2025, 7, 10, 12, 0, 0) do
      get dashboard_url(date: "not-a-date")
      assert_response :success
      assert_includes @response.body, "July 10, 2025"
    end
  end

  test "dashboard shows prev and next navigation links" do
    travel_to Time.utc(2025, 7, 10, 12, 0, 0) do
      get dashboard_url(date: "2025-07-09")
      assert_response :success
      assert_includes @response.body, "date=2025-07-08"
      assert_includes @response.body, "\u2192"
    end
  end

  test "dashboard hides next button when viewing today" do
    travel_to Time.utc(2025, 7, 10, 12, 0, 0) do
      get dashboard_url
      assert_response :success
      assert_includes @response.body, "\u2190"
      refute_includes @response.body, "date=2025-07-11"
    end
  end

  test "clear_day with date param clears that specific date" do
    travel_to Time.utc(2025, 7, 10, 12, 0, 0) do
      habit = habits(:one)
      past_date = Date.new(2025, 7, 5)
      log = HabitLog.create!(habit: habit, logged_on: past_date, start_hour: 9, end_hour: 11)

      assert HabitLog.exists?(log.id)

      delete clear_day_url(date: past_date.to_s)
      assert_redirected_to dashboard_path(date: past_date.to_s)

      refute HabitLog.exists?(log.id)
    end
  end
end
