require "test_helper"

class SendHabitReminderJobTest < ActiveJob::TestCase
  setup do
    @user = users(:one)
    @subscription = push_subscriptions(:one)
  end

  test "job runs without error" do
    @user.update!(notification_hours: [ 12 ], time_zone: "UTC")

    travel_to Time.utc(2025, 1, 15, 12, 0, 0) do
      assert_nothing_raised do
        SendHabitReminderJob.perform_now
      end
    end
  end

  test "should_notify? returns true when current hour matches user preference" do
    @user.update!(notification_hours: [ 12 ], time_zone: "UTC")

    job = SendHabitReminderJob.new

    travel_to Time.utc(2025, 1, 15, 12, 0, 0) do
      assert job.send(:should_notify?, @user)
    end
  end

  test "should_notify? returns false when current hour does not match" do
    @user.update!(notification_hours: [ 9 ], time_zone: "UTC")

    job = SendHabitReminderJob.new

    travel_to Time.utc(2025, 1, 15, 12, 0, 0) do
      assert_not job.send(:should_notify?, @user)
    end
  end

  test "should_notify? respects user timezone" do
    @user.update!(notification_hours: [ 9 ], time_zone: "America/New_York")

    job = SendHabitReminderJob.new

    # 14:00 UTC = 9:00 AM Eastern (EST is UTC-5)
    travel_to Time.utc(2025, 1, 15, 14, 0, 0) do
      assert job.send(:should_notify?, @user)
    end
  end

  test "should_notify? treats nil timezone as UTC" do
    @user.update!(notification_hours: [ 12 ], time_zone: nil)

    job = SendHabitReminderJob.new

    travel_to Time.utc(2025, 1, 15, 12, 0, 0) do
      assert job.send(:should_notify?, @user)
    end
  end

  test "should_notify? returns false for empty notification_hours" do
    @user.update!(notification_hours: [], time_zone: "UTC")

    job = SendHabitReminderJob.new

    travel_to Time.utc(2025, 1, 15, 12, 0, 0) do
      assert_not job.send(:should_notify?, @user)
    end
  end

  test "job skips users without push subscriptions" do
    @subscription.destroy
    @user.update!(notification_hours: [ 12 ], time_zone: "UTC")

    travel_to Time.utc(2025, 1, 15, 12, 0, 0) do
      assert_nothing_raised do
        SendHabitReminderJob.perform_now
      end
    end
  end

  test "job skips users with empty notification_hours" do
    @user.update!(notification_hours: [], time_zone: "UTC")

    travel_to Time.utc(2025, 1, 15, 12, 0, 0) do
      assert_nothing_raised do
        SendHabitReminderJob.perform_now
      end
    end
  end
end
