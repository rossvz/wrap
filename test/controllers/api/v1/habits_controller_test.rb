require "test_helper"

module Api
  module V1
    class HabitsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @api_token = api_tokens(:one)
  end

  test "index returns habits as JSON with valid token" do
    get api_v1_habits_url, headers: auth_headers(@api_token)

    assert_response :success
    habits = JSON.parse(response.body)

    assert_kind_of Array, habits
    assert habits.length >= 1

    habit = habits.find { |h| h["name"] == "Reading" }
    assert habit.present?
    assert_equal @user.habits.find_by(name: "Reading").id, habit["id"]
    assert habit.key?("description")
    assert habit.key?("color_token")
    assert habit.key?("active")
  end

  test "index returns 401 without token" do
    get api_v1_habits_url

    assert_response :unauthorized
    body = JSON.parse(response.body)
    assert_equal "Unauthorized", body["error"]
  end

  test "index returns 401 with invalid token" do
    get api_v1_habits_url, headers: { "Authorization" => "Bearer invalid_token" }

    assert_response :unauthorized
  end

  test "index only returns current user habits" do
    other_user = users(:two)
    other_habit = other_user.habits.create!(name: "Other Habit", color_token: 5)

    get api_v1_habits_url, headers: auth_headers(@api_token)

    assert_response :success
    habits = JSON.parse(response.body)
    habit_names = habits.map { |h| h["name"] }

    assert_not_includes habit_names, "Other Habit"
  end

  test "index updates api token last_used_at" do
    original_time = @api_token.last_used_at

    freeze_time do
      get api_v1_habits_url, headers: auth_headers(@api_token)

      @api_token.reload
      assert_equal Time.current, @api_token.last_used_at
    end
  end

  private

  def auth_headers(token)
    { "Authorization" => "Bearer #{token.token}" }
  end
    end
  end
end
