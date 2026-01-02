require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "themes list includes catppuccin" do
    assert_includes User::THEMES, "catppuccin"
  end

  test "theme_name returns friendly label for catppuccin" do
    user = users(:one)
    user.theme = "catppuccin"

    assert_equal "Catppuccin Dark", user.theme_name
  end

  test "notification_hours defaults to empty array" do
    user = User.new(email_address: "test@example.com", theme: "default")
    assert_equal [], user.notification_hours
  end

  test "validates maximum of 6 notification hours" do
    user = users(:one)
    user.notification_hours = [ 6, 9, 12, 15, 18, 21, 23 ]
    assert_not user.valid?
    assert_includes user.errors[:notification_hours], "can have at most 6 notification times"
  end

  test "allows exactly 6 notification hours" do
    user = users(:one)
    user.notification_hours = [ 6, 9, 12, 15, 18, 21 ]
    assert user.valid?
  end

  test "validates hours are between 0 and 23" do
    user = users(:one)
    user.notification_hours = [ 25 ]
    assert_not user.valid?
    assert_includes user.errors[:notification_hours], "must be valid hours (0-23)"
  end

  test "validates hours cannot be negative" do
    user = users(:one)
    user.notification_hours = [ -1 ]
    assert_not user.valid?
  end

  test "effective_timezone returns UTC when time_zone is nil" do
    user = users(:one)
    user.time_zone = nil
    assert_equal "UTC", user.effective_timezone
  end

  test "effective_timezone returns UTC when time_zone is blank" do
    user = users(:one)
    user.time_zone = ""
    assert_equal "UTC", user.effective_timezone
  end

  test "effective_timezone returns user timezone when set" do
    user = users(:one)
    user.time_zone = "America/New_York"
    assert_equal "America/New_York", user.effective_timezone
  end
end
