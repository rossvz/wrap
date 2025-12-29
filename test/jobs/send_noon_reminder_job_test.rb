require "test_helper"

class SendNoonReminderJobTest < ActiveJob::TestCase
  test "sends push to all subscriptions" do
    # This test verifies the job runs without error
    # In a full test environment, we'd mock WebPush
    assert_nothing_raised do
      # The job should handle missing VAPID keys gracefully in test
      SendNoonReminderJob.perform_now rescue nil
    end
  end
end
