require "test_helper"

class WorkScheduleTest < ActiveSupport::TestCase
  test "initializes with empty hash by default" do
    schedule = WorkSchedule.new
    assert_equal({}, schedule.data)
  end

  test "initializes with provided data" do
    schedule = WorkSchedule.new("work_hours_enabled" => true, "work_start_hour" => 8)
    assert schedule.enabled?
    assert_equal 8.to_d, schedule.start_hour
  end

  test "enabled? returns false by default" do
    schedule = WorkSchedule.new
    assert_not schedule.enabled?
  end

  test "enabled? returns true when enabled" do
    schedule = WorkSchedule.new("work_hours_enabled" => true)
    assert schedule.enabled?
  end

  test "enabled= sets the value" do
    schedule = WorkSchedule.new
    schedule.enabled = true
    assert schedule.enabled?
  end

  test "start_hour defaults to 9.0" do
    schedule = WorkSchedule.new
    assert_equal 9.0.to_d, schedule.start_hour
  end

  test "start_hour= sets the value as decimal" do
    schedule = WorkSchedule.new
    schedule.start_hour = 8.5
    assert_equal 8.5.to_d, schedule.start_hour
  end

  test "end_hour defaults to 17.0" do
    schedule = WorkSchedule.new
    assert_equal 17.0.to_d, schedule.end_hour
  end

  test "end_hour= sets the value as decimal" do
    schedule = WorkSchedule.new
    schedule.end_hour = 18.5
    assert_equal 18.5.to_d, schedule.end_hour
  end

  test "work_days defaults to Mon-Fri" do
    schedule = WorkSchedule.new
    assert_equal [ 1, 2, 3, 4, 5 ], schedule.work_days
  end

  test "work_days= converts strings to integers" do
    schedule = WorkSchedule.new
    schedule.work_days = [ "1", "2", "3" ]
    assert_equal [ 1, 2, 3 ], schedule.work_days
  end

  test "work_days= rejects blank values" do
    schedule = WorkSchedule.new
    schedule.work_days = [ "1", "", "3", nil ]
    assert_equal [ 1, 3 ], schedule.work_days
  end

  test "work_day? returns true for days in work_days" do
    schedule = WorkSchedule.new("work_days" => [ 1, 2, 3 ])
    monday = Date.new(2025, 1, 6)
    assert schedule.work_day?(monday)
  end

  test "work_day? returns false for days not in work_days" do
    schedule = WorkSchedule.new("work_days" => [ 1, 2, 3, 4, 5 ])
    sunday = Date.new(2025, 1, 5)
    assert_not schedule.work_day?(sunday)
  end

  test "to_h returns only allowed keys" do
    schedule = WorkSchedule.new(
      "work_hours_enabled" => true,
      "work_start_hour" => 9,
      "work_end_hour" => 17,
      "work_days" => [ 1, 2, 3, 4, 5 ],
      "malicious_key" => "bad_value"
    )
    result = schedule.to_h
    assert_equal %w[work_hours_enabled work_start_hour work_end_hour work_days].sort, result.keys.sort
    assert_nil result["malicious_key"]
  end

  test "valid? returns true when disabled" do
    schedule = WorkSchedule.new("work_hours_enabled" => false)
    assert schedule.valid?
  end

  test "valid? returns false when start_hour out of range" do
    schedule = WorkSchedule.new("work_hours_enabled" => true, "work_start_hour" => 25)
    assert_not schedule.valid?
    assert_includes schedule.errors, "Work start hour must be between 0 and 24"
  end

  test "valid? returns false when end_hour out of range" do
    schedule = WorkSchedule.new("work_hours_enabled" => true, "work_end_hour" => 25)
    assert_not schedule.valid?
    assert_includes schedule.errors, "Work end hour must be between 0 and 24"
  end

  test "valid? returns false when start_hour >= end_hour" do
    schedule = WorkSchedule.new("work_hours_enabled" => true, "work_start_hour" => 17, "work_end_hour" => 9)
    assert_not schedule.valid?
    assert_includes schedule.errors, "Work end hour must be after start hour"
  end

  test "valid? returns false when work_days contains invalid day numbers" do
    schedule = WorkSchedule.new("work_hours_enabled" => true, "work_days" => [ 7 ])
    assert_not schedule.valid?
    assert_includes schedule.errors, "Work days must be valid day numbers (0-6)"
  end
end
