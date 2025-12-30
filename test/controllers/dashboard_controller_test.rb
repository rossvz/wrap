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
end
