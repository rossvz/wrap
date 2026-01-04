require "test_helper"

class SendHabitReminderJobTest < ActiveJob::TestCase
  setup do
    @user = users(:one)
    @subscription = push_subscriptions(:one)
    @habit = habits(:one)
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

  # Tests for smart reminder deduplication
  test "previous_notification_hour returns previous hour from sorted list" do
    job = SendHabitReminderJob.new
    notification_hours = [ 6, 9, 12, 15, 18, 21 ]

    assert_equal 6, job.send(:previous_notification_hour, notification_hours, 9)
    assert_equal 9, job.send(:previous_notification_hour, notification_hours, 12)
    assert_equal 12, job.send(:previous_notification_hour, notification_hours, 15)
    assert_equal 18, job.send(:previous_notification_hour, notification_hours, 21)
  end

  test "previous_notification_hour returns 0 for first notification of day" do
    job = SendHabitReminderJob.new
    notification_hours = [ 6, 9, 12, 15, 18, 21 ]

    # 6am is the first notification, so block starts at midnight (0)
    assert_equal 0, job.send(:previous_notification_hour, notification_hours, 6)
  end

  test "previous_notification_hour works with custom hour configurations" do
    job = SendHabitReminderJob.new

    # Custom config: 8am, 12pm, 4pm, 8pm
    custom_hours = [ 8, 12, 16, 20 ]
    assert_equal 8, job.send(:previous_notification_hour, custom_hours, 12)
    assert_equal 12, job.send(:previous_notification_hour, custom_hours, 16)
    assert_equal 16, job.send(:previous_notification_hour, custom_hours, 20)
    assert_equal 0, job.send(:previous_notification_hour, custom_hours, 8)

    # Single notification hour
    single_hour = [ 12 ]
    assert_equal 0, job.send(:previous_notification_hour, single_hour, 12)
  end

  test "should_notify? returns false when user has logged in current block" do
    @user.update!(notification_hours: [ 9, 12 ], time_zone: "UTC")
    job = SendHabitReminderJob.new

    travel_to Time.utc(2025, 1, 15, 12, 0, 0) do
      # Create a log between 9am and 12pm (the current block)
      @habit.habit_logs.create!(
        logged_on: Date.new(2025, 1, 15),
        start_hour: 10,
        end_hour: 11
      )

      assert_not job.send(:should_notify?, @user)
    end
  end

  test "should_notify? returns true when user has not logged in current block" do
    @user.update!(notification_hours: [ 9, 12 ], time_zone: "UTC")
    job = SendHabitReminderJob.new

    travel_to Time.utc(2025, 1, 15, 12, 0, 0) do
      # Log from earlier block (before 9am)
      @habit.habit_logs.create!(
        logged_on: Date.new(2025, 1, 15),
        start_hour: 7,
        end_hour: 8
      )

      assert job.send(:should_notify?, @user)
    end
  end

  test "should_notify? returns true when logs are from a different day" do
    @user.update!(notification_hours: [ 9, 12 ], time_zone: "UTC")
    job = SendHabitReminderJob.new

    travel_to Time.utc(2025, 1, 15, 12, 0, 0) do
      # Log from yesterday in the same time range
      @habit.habit_logs.create!(
        logged_on: Date.new(2025, 1, 14),
        start_hour: 10,
        end_hour: 11
      )

      assert job.send(:should_notify?, @user)
    end
  end

  test "should_notify? detects logs that partially overlap with block" do
    @user.update!(notification_hours: [ 9, 12 ], time_zone: "UTC")
    job = SendHabitReminderJob.new

    travel_to Time.utc(2025, 1, 15, 12, 0, 0) do
      # Log that started before block but ends within it
      @habit.habit_logs.create!(
        logged_on: Date.new(2025, 1, 15),
        start_hour: 8,
        end_hour: 10
      )

      assert_not job.send(:should_notify?, @user)
    end
  end

  test "should_notify? detects logs at exact block boundaries" do
    @user.update!(notification_hours: [ 9, 12 ], time_zone: "UTC")
    job = SendHabitReminderJob.new

    travel_to Time.utc(2025, 1, 15, 12, 0, 0) do
      # Log exactly at 9-10am (right at block start)
      @habit.habit_logs.create!(
        logged_on: Date.new(2025, 1, 15),
        start_hour: 9,
        end_hour: 10
      )

      assert_not job.send(:should_notify?, @user)
    end
  end

  test "should_notify? ignores logs that end exactly at block start" do
    @user.update!(notification_hours: [ 9, 12 ], time_zone: "UTC")
    job = SendHabitReminderJob.new

    travel_to Time.utc(2025, 1, 15, 12, 0, 0) do
      # Log that ends exactly at 9am (doesn't overlap with 9-12 block)
      @habit.habit_logs.create!(
        logged_on: Date.new(2025, 1, 15),
        start_hour: 8,
        end_hour: 9
      )

      assert job.send(:should_notify?, @user)
    end
  end

  test "should_notify? handles first notification of day correctly" do
    @user.update!(notification_hours: [ 6, 12 ], time_zone: "UTC")
    job = SendHabitReminderJob.new

    travel_to Time.utc(2025, 1, 15, 6, 0, 0) do
      # Log from early morning (0-6 block for first notification)
      @habit.habit_logs.create!(
        logged_on: Date.new(2025, 1, 15),
        start_hour: 5,
        end_hour: 5.5
      )

      assert_not job.send(:should_notify?, @user)
    end
  end

  test "should_notify? respects user timezone when checking logs" do
    # User in New York (UTC-5), notification at 9am local
    @user.update!(notification_hours: [ 9 ], time_zone: "America/New_York")
    job = SendHabitReminderJob.new

    # 14:00 UTC = 9:00 AM Eastern
    travel_to Time.utc(2025, 1, 15, 14, 0, 0) do
      # Log in Eastern timezone's morning (7-8am = block 0-9)
      @habit.habit_logs.create!(
        logged_on: Date.new(2025, 1, 15),
        start_hour: 7,
        end_hour: 8
      )

      assert_not job.send(:should_notify?, @user)
    end
  end

  test "should_notify? works with multiple habits" do
    @user.update!(notification_hours: [ 9, 12 ], time_zone: "UTC")
    second_habit = @user.habits.create!(name: "Second Habit")
    job = SendHabitReminderJob.new

    travel_to Time.utc(2025, 1, 15, 12, 0, 0) do
      # Log on second habit within block
      second_habit.habit_logs.create!(
        logged_on: Date.new(2025, 1, 15),
        start_hour: 10,
        end_hour: 11
      )

      # Should not notify because second habit has a log
      assert_not job.send(:should_notify?, @user)
    end
  end
end
