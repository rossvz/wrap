require "test_helper"

class InsightsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test "should get show defaults to week" do
    get insights_url
    assert_response :success
    assert_select "h1", "Insights"
  end

  test "should get week view" do
    get insights_url(period: "week")
    assert_response :success
  end

  test "should get month view" do
    get insights_url(period: "month")
    assert_response :success
  end

  test "should get year view" do
    get insights_url(period: "year")
    assert_response :success
  end

  test "navigates to specific date for week" do
    get insights_url(period: "week", date: 1.week.ago.to_date)
    assert_response :success
  end

  test "navigates to specific date for month" do
    get insights_url(period: "month", date: 1.month.ago.to_date)
    assert_response :success
  end

  test "navigates to specific date for year" do
    get insights_url(period: "year", date: 1.year.ago.to_date)
    assert_response :success
  end

  test "handles invalid period param by defaulting to week" do
    get insights_url(period: "invalid")
    assert_response :success
  end

  test "handles invalid date param gracefully" do
    get insights_url(period: "week", date: "garbage")
    assert_response :success
  end

  test "should redirect to login when not authenticated" do
    sign_out
    get insights_url
    assert_redirected_to new_session_url
  end

  test "returns JSON for week view" do
    get insights_url(period: "week", format: :json)
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "week", json["period_type"]
    assert json.key?("stats")
    assert json.key?("hours_by_habit")
  end

  test "returns JSON for month view" do
    get insights_url(period: "month", format: :json)
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "month", json["period_type"]
  end

  test "returns JSON for year view" do
    get insights_url(period: "year", format: :json)
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "year", json["period_type"]
  end
end
