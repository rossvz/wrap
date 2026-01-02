require "test_helper"

class SendHabitReminderJobTest < ActiveJob::TestCase
  setup do
    @user = users(:one)
    @subscription = push_subscriptions(:one)
  end

  test "timezones_at_hour returns timezones where current hour matches" do
    job = SendHabitReminderJob.new

    # Travel to a specific time to make the test deterministic
    travel_to Time.utc(2025, 1, 15, 12, 0, 0) do
      # At 12:00 UTC, find timezones where it's currently hour 12
      noon_zones = job.send(:timezones_at_hour, 12)

      noon_zones.each do |zone_name|
        tz = ActiveSupport::TimeZone[zone_name]
        assert_equal 12, Time.current.in_time_zone(tz).hour
      end
    end
  end

  test "configured_hours returns unique hours from all users" do
    @user.update!(notification_hours: [ 9, 12 ])
    users(:two).update!(notification_hours: [ 12, 18 ])

    job = SendHabitReminderJob.new
    hours = job.send(:configured_hours)

    assert_includes hours, 9
    assert_includes hours, 12
    assert_includes hours, 18
    assert_equal 3, hours.size
  end

  test "configured_hours returns empty array when no users have hours set" do
    User.update_all(notification_hours: "[]")

    job = SendHabitReminderJob.new
    hours = job.send(:configured_hours)

    assert_equal [], hours
  end

  test "job runs without error" do
    @user.update!(notification_hours: [ 12 ], time_zone: "UTC")

    travel_to Time.utc(2025, 1, 15, 12, 0, 0) do
      assert_nothing_raised do
        SendHabitReminderJob.perform_now
      end
    end
  end

  test "users_to_notify finds users with matching hour and timezone" do
    @user.update!(notification_hours: [ 12 ], time_zone: "UTC")

    job = SendHabitReminderJob.new

    travel_to Time.utc(2025, 1, 15, 12, 0, 0) do
      timezone_names = job.send(:timezones_at_hour, 12)
      users = job.send(:users_to_notify, 12, timezone_names)

      assert_includes users, @user
    end
  end

  test "users_to_notify excludes users with non-matching hour" do
    @user.update!(notification_hours: [ 9 ], time_zone: "UTC")

    job = SendHabitReminderJob.new

    travel_to Time.utc(2025, 1, 15, 12, 0, 0) do
      timezone_names = job.send(:timezones_at_hour, 12)
      users = job.send(:users_to_notify, 12, timezone_names)

      assert_not_includes users, @user
    end
  end

  test "users_to_notify excludes users without push subscriptions" do
    @subscription.destroy
    @user.update!(notification_hours: [ 12 ], time_zone: "UTC")

    job = SendHabitReminderJob.new

    travel_to Time.utc(2025, 1, 15, 12, 0, 0) do
      timezone_names = job.send(:timezones_at_hour, 12)
      users = job.send(:users_to_notify, 12, timezone_names)

      assert_not_includes users, @user
    end
  end

  test "users_to_notify treats nil timezone as UTC" do
    @user.update!(notification_hours: [ 12 ], time_zone: nil)

    job = SendHabitReminderJob.new

    travel_to Time.utc(2025, 1, 15, 12, 0, 0) do
      timezone_names = job.send(:timezones_at_hour, 12)
      users = job.send(:users_to_notify, 12, timezone_names)

      assert_includes users, @user
    end
  end

  test "users_to_notify excludes users with empty notification_hours" do
    @user.update!(notification_hours: [], time_zone: "UTC")

    job = SendHabitReminderJob.new

    travel_to Time.utc(2025, 1, 15, 12, 0, 0) do
      timezone_names = job.send(:timezones_at_hour, 12)
      users = job.send(:users_to_notify, 12, timezone_names)

      assert_not_includes users, @user
    end
  end
end
