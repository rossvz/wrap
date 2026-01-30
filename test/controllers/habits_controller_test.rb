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

  test "should not create habit with invalid params" do
    assert_no_difference("Habit.count") do
      post habits_url, params: { habit: { name: "", color_token: 1 } }
    end
    assert_response :unprocessable_entity
  end

  test "should not update habit with invalid params" do
    patch habit_url(@habit), params: { habit: { name: "" } }
    assert_response :unprocessable_entity
    @habit.reload
    assert_not_equal "", @habit.name
  end

  test "should create habit with JSON response" do
    assert_difference("Habit.count") do
      post habits_url, params: { habit: { name: "JSON Habit", color_token: 3 } }, as: :json
    end
    assert_response :created
  end

  test "should update habit with JSON response" do
    patch habit_url(@habit), params: { habit: { name: "Updated Name" } }, as: :json
    assert_response :ok
    @habit.reload
    assert_equal "Updated Name", @habit.name
  end

  test "should destroy habit with JSON response" do
    assert_difference("Habit.count", -1) do
      delete habit_url(@habit), as: :json
    end
    assert_response :no_content
  end

  test "should create habit with tags" do
    tag = @user.tags.create!(name: "work")

    assert_difference("Habit.count") do
      post habits_url, params: {
        habit: { name: "Tagged Habit", color_token: 3, tag_ids: [ tag.id ] }
      }
    end

    assert_includes Habit.last.tags, tag
  end

  test "should create habit with new tags" do
    assert_difference([ "Habit.count", "Tag.count" ]) do
      post habits_url, params: {
        habit: { name: "Tagged Habit", color_token: 3 },
        new_tags: [ "brandnew" ]
      }
    end

    assert_includes Habit.last.tags.pluck(:name), "brandnew"
  end

  test "should not assign other users tags" do
    other_user = users(:two)
    other_tag = other_user.tags.create!(name: "othertag")

    post habits_url, params: {
      habit: { name: "Test", color_token: 3, tag_ids: [ other_tag.id ] }
    }

    assert_not_includes Habit.last.tags, other_tag
  end

  test "should not update other users habits" do
    other_user = users(:two)
    other_habit = other_user.habits.create!(name: "Other Habit", color_token: 1)

    patch habit_url(other_habit), params: { habit: { name: "Hacked" } }
    assert_response :not_found
    other_habit.reload
    assert_equal "Other Habit", other_habit.name
  end

  test "should not destroy other users habits" do
    other_user = users(:two)
    other_habit = other_user.habits.create!(name: "Other Habit", color_token: 1)

    assert_no_difference("Habit.count") do
      delete habit_url(other_habit)
    end
    assert_response :not_found
  end
end
