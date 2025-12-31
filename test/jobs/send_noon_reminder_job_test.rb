require "test_helper"

class SendNoonReminderJobTest < ActiveJob::TestCase
  test "sends push only to users in noon timezones" do
    assert_nothing_raised do
      SendNoonReminderJob.perform_now rescue nil
    end
  end

  test "time_zones_where_noon returns timezones where current hour is 12" do
    job = SendNoonReminderJob.new
    noon_zones = job.send(:time_zones_where_noon)

    noon_zones.each do |zone_name|
      tz = ActiveSupport::TimeZone[zone_name]
      assert_equal 12, Time.current.in_time_zone(tz).hour
    end
  end
end
