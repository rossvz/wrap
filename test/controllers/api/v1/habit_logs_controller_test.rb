require "test_helper"

module Api
  module V1
    class HabitLogsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @habit = habits(:one)
    @api_token = api_tokens(:one)
  end

  test "create creates habit log with valid params" do
    assert_difference("HabitLog.count") do
      post api_v1_habit_logs_url(@habit),
        params: { logged_on: Date.today.iso8601, start_hour: 9.0, end_hour: 11.5 },
        headers: auth_headers(@api_token),
        as: :json
    end

    assert_response :created
    body = JSON.parse(response.body)

    assert body["id"].present?
    assert_equal @habit.id, body["habit"]["id"]
    assert_equal @habit.name, body["habit"]["name"]
    assert_equal Date.today.iso8601, body["logged_on"]
    assert_in_delta 9.0, body["start_hour"].to_f, 0.01
    assert_in_delta 11.5, body["end_hour"].to_f, 0.01
    assert_in_delta 2.5, body["duration_hours"].to_f, 0.01
    assert body["created_at"].present?
  end

  test "create with notes" do
    post api_v1_habit_logs_url(@habit),
      params: { logged_on: Date.today.iso8601, start_hour: 14.0, end_hour: 15.0, notes: "Test notes" },
      headers: auth_headers(@api_token),
      as: :json

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "Test notes", body["notes"]
  end

  test "create returns 401 without token" do
    post api_v1_habit_logs_url(@habit),
      params: { logged_on: Date.today.iso8601, start_hour: 9.0, end_hour: 10.0 },
      as: :json

    assert_response :unauthorized
  end

  test "create returns 404 for other users habit" do
    other_user = users(:two)
    other_habit = other_user.habits.create!(name: "Other", color_token: 3)

    post api_v1_habit_logs_url(other_habit),
      params: { logged_on: Date.today.iso8601, start_hour: 9.0, end_hour: 10.0 },
      headers: auth_headers(@api_token),
      as: :json

    assert_response :not_found
    body = JSON.parse(response.body)
    assert_equal "Not found", body["error"]
  end

  test "create returns 404 for non-existent habit" do
    post api_v1_habit_logs_url(habit_id: 999999),
      params: { logged_on: Date.today.iso8601, start_hour: 9.0, end_hour: 10.0 },
      headers: auth_headers(@api_token),
      as: :json

    assert_response :not_found
  end

  test "create returns 422 with invalid params" do
    post api_v1_habit_logs_url(@habit),
      params: { logged_on: Date.today.iso8601, start_hour: 10.0, end_hour: 9.0 },
      headers: auth_headers(@api_token),
      as: :json

    assert_response :unprocessable_entity
    body = JSON.parse(response.body)
    assert body["errors"].present?
  end

  private

  def auth_headers(token)
    { "Authorization" => "Bearer #{token.token}" }
  end
    end
  end
end
