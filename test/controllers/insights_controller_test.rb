require "test_helper"

class InsightsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test "should get show" do
    get insights_url
    assert_response :success
  end

  test "navigates to previous week" do
    get insights_url(week: 1.week.ago.to_date)
    assert_response :success
  end

  test "handles invalid week param" do
    get insights_url(week: "garbage")
    assert_response :success
  end

  test "should redirect to login when not authenticated" do
    sign_out
    get insights_url
    assert_redirected_to new_session_url
  end
end
