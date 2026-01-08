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

  # Work Schedule tests
  test "work_hours_enabled? returns false by default" do
    user = users(:one)
    assert_not user.work_hours_enabled?
  end

  test "work_hours_enabled? returns true when enabled" do
    user = users(:one)
    user.work_hours_enabled = "true"
    assert user.work_hours_enabled?
  end

  test "work_start_hour defaults to 9.0" do
    user = users(:one)
    assert_equal 9.0.to_d, user.work_start_hour
  end

  test "work_end_hour defaults to 17.0" do
    user = users(:one)
    assert_equal 17.0.to_d, user.work_end_hour
  end

  test "work_days defaults to Mon-Fri" do
    user = users(:one)
    assert_equal [ 1, 2, 3, 4, 5 ], user.work_days
  end

  test "work_day? returns true for weekday" do
    user = users(:one)
    monday = Date.new(2025, 1, 6) # Monday
    assert user.work_day?(monday)
  end

  test "work_day? returns false for weekend" do
    user = users(:one)
    sunday = Date.new(2025, 1, 5) # Sunday
    assert_not user.work_day?(sunday)
  end

  test "work schedule setters update work_schedule hash" do
    user = users(:one)
    user.work_hours_enabled = "true"
    user.work_start_hour = 8.5
    user.work_end_hour = 18.0
    user.work_days = [ "1", "2", "3" ]

    assert user.work_hours_enabled?
    assert_equal 8.5.to_d, user.work_start_hour
    assert_equal 18.0.to_d, user.work_end_hour
    assert_equal [ 1, 2, 3 ], user.work_days
  end

  test "validates work_start_hour is between 0 and 24" do
    user = users(:one)
    user.work_schedule = { "work_hours_enabled" => true, "work_start_hour" => 25, "work_end_hour" => 17 }
    assert_not user.valid?
  end

  test "validates work_end_hour is between 0 and 24" do
    user = users(:one)
    user.work_schedule = { "work_hours_enabled" => true, "work_start_hour" => 9, "work_end_hour" => 25 }
    assert_not user.valid?
  end

  test "validates work_end_hour must be after work_start_hour" do
    user = users(:one)
    user.work_schedule = { "work_hours_enabled" => true, "work_start_hour" => 17, "work_end_hour" => 9 }
    assert_not user.valid?
  end

  test "validates work_days contains valid day numbers" do
    user = users(:one)
    user.work_schedule = { "work_hours_enabled" => true, "work_start_hour" => 9, "work_end_hour" => 17, "work_days" => [ 7 ] }
    assert_not user.valid?
  end

  test "sanitizes work_schedule to only allowed keys" do
    user = users(:one)
    user.work_schedule = {
      "work_hours_enabled" => true,
      "work_start_hour" => 9,
      "work_end_hour" => 17,
      "work_days" => [ 1, 2, 3, 4, 5 ],
      "malicious_key" => "bad_value"
    }
    user.save!
    assert_nil user.work_schedule["malicious_key"]
  end
end
