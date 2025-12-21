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
end
