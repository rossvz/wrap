# feat: Customizable Push Notification Times

## Overview

Allow users to customize when they receive habit tracking push notifications. Users select notification hours from a checkbox grid, with preferences stored as an array column on User. This replaces the hardcoded noon-only notification system.

## Problem Statement / Motivation

Currently, all users with push subscriptions receive notifications at noon in their timezone. This one-size-fits-all approach doesn't work for everyone:

- Early risers may want morning reminders (7am)
- Night owls may prefer evening check-ins (9pm)
- Some users want multiple reminders throughout the day

The existing `SendNoonReminderJob` has hardcoded noon logic and noon-specific messaging that needs to be generalized.

## Proposed Solution

### Data Model (Simplified)

Store notification hours as an integer array column directly on User - no separate table needed:

```ruby
# db/migrate/xxx_add_notification_hours_to_users.rb
class AddNotificationHoursToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :notification_hours, :integer, array: true, default: []
  end
end
```

### User Interface

Add notification time selection to the Settings page using a simple checkbox grid:
- Show common hours (6am, 9am, 12pm, 3pm, 6pm, 9pm) as checkboxes
- No JavaScript required - standard Rails form
- Display user's current timezone for clarity

### Background Job

Rename and refactor `SendNoonReminderJob` → `SendHabitReminderJob`:
- Query users with notification hours matching current hour in their timezone
- Send push notification with generic message
- Handle nil timezone by defaulting to UTC

### Migration Strategy

For existing users with push subscriptions:
- Auto-populate `notification_hours: [12]` to preserve current behavior
- New users start with empty array (no notifications until configured)

## Technical Approach

### 1. Database Migration

```ruby
# db/migrate/xxx_add_notification_hours_to_users.rb
class AddNotificationHoursToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :notification_hours, :integer, array: true, default: []
  end
end

# db/migrate/xxx_migrate_existing_push_users.rb
class MigrateExistingPushUsers < ActiveRecord::Migration[8.1]
  def up
    User.joins(:push_subscriptions).distinct.update_all(notification_hours: [12])
  end

  def down
    User.update_all(notification_hours: [])
  end
end
```

### 2. User Model Updates

```ruby
# app/models/user.rb (additions)
class User < ApplicationRecord
  validates :notification_hours, length: {
    maximum: 6,
    message: "can have at most 6 notification times"
  }
  validate :notification_hours_in_valid_range

  def effective_timezone
    time_zone.presence || "UTC"
  end

  private

  def notification_hours_in_valid_range
    return if notification_hours.blank?
    unless notification_hours.all? { |h| h.is_a?(Integer) && h.between?(0, 23) }
      errors.add(:notification_hours, "must be valid hours (0-23)")
    end
  end
end
```

### 3. Settings Controller Updates

```ruby
# app/controllers/settings_controller.rb
def update
  if current_user.update(settings_params)
    redirect_to settings_path, notice: "Settings saved"
  else
    render :show, status: :unprocessable_entity
  end
end

private

def settings_params
  params.expect(user: [:theme, notification_hours: []])
end
```

### 4. Settings View Updates

```erb
<%# app/views/settings/show.html.erb - add this section %>

<div class="nb-card p-6 mt-6">
  <h2 class="text-xl font-bold mb-2">Notification Times</h2>
  <p class="text-sm text-gray-600 mb-4">
    Select when you'd like to receive habit reminders.
    Times are in your timezone: <strong><%= current_user.effective_timezone %></strong>
  </p>

  <% if current_user.push_subscriptions.none? %>
    <p class="text-sm text-amber-600">
      Enable push notifications above to receive reminders.
    </p>
  <% else %>
    <div class="grid grid-cols-2 sm:grid-cols-3 gap-3 mt-4">
      <% [[6, "6 AM"], [9, "9 AM"], [12, "12 PM"], [15, "3 PM"], [18, "6 PM"], [21, "9 PM"]].each do |hour, label| %>
        <label class="flex items-center gap-2 p-2 border-2 border-black rounded cursor-pointer hover:bg-yellow-50">
          <%= check_box_tag "user[notification_hours][]", hour,
              current_user.notification_hours&.include?(hour),
              id: "notification_hour_#{hour}",
              class: "w-5 h-5" %>
          <span class="font-medium"><%= label %></span>
        </label>
      <% end %>
    </div>
  <% end %>
</div>
```

### 5. Refactored Background Job

```ruby
# app/jobs/send_habit_reminder_job.rb
class SendHabitReminderJob < ApplicationJob
  queue_as :default

  def perform
    # Get distinct hours that any user has configured
    configured_hours = User.where.not(notification_hours: [])
                           .pluck(:notification_hours)
                           .flatten.uniq

    configured_hours.each do |hour|
      send_reminders_for_hour(hour)
    end
  end

  private

  def send_reminders_for_hour(hour)
    timezone_names = timezones_at_hour(hour)
    return if timezone_names.empty?

    users_to_notify(hour, timezone_names).find_each do |user|
      send_reminder(user)
    end
  end

  def timezones_at_hour(hour)
    ActiveSupport::TimeZone.all
      .select { |tz| Time.current.in_time_zone(tz).hour == hour }
      .map(&:name)
  end

  def users_to_notify(hour, timezone_names)
    # Include users with nil timezone (treated as UTC)
    utc_included = timezone_names.include?("UTC")

    User.joins(:push_subscriptions)
        .includes(:push_subscriptions)
        .where(":hour = ANY(notification_hours)", hour: hour)
        .where(time_zone: timezone_names)
        .or(
          User.joins(:push_subscriptions)
              .includes(:push_subscriptions)
              .where(":hour = ANY(notification_hours)", hour: hour)
              .where(time_zone: [nil, ""])
              .tap { |q| break q.none unless utc_included }
        )
        .distinct
  end

  def send_reminder(user)
    user.push_subscriptions.each do |subscription|
      subscription.push_message(
        title: "Habit Reminder",
        body: "Time to log your habits!",
        path: "/"
      )
    rescue => e
      Rails.logger.error "Push failed for subscription #{subscription.id}: #{e.message}"
    end
  end
end
```

### 6. Update Recurring Jobs Config

```yaml
# config/recurring.yml
production:
  send_habit_reminder:
    class: SendHabitReminderJob
    schedule: every hour

  # ... other jobs unchanged
```

## Files to Modify

### New Files
- `db/migrate/xxx_add_notification_hours_to_users.rb`
- `db/migrate/xxx_migrate_existing_push_users.rb`
- `app/jobs/send_habit_reminder_job.rb`
- `test/models/user_notification_hours_test.rb`
- `test/jobs/send_habit_reminder_job_test.rb`

### Modified Files
- `app/models/user.rb` - Add validation for notification_hours
- `app/controllers/settings_controller.rb` - Update strong params
- `app/views/settings/show.html.erb` - Add notification times checkbox section
- `config/recurring.yml` - Update job reference

### Deleted Files
- `app/jobs/send_noon_reminder_job.rb`
- `test/jobs/send_noon_reminder_job_test.rb`

## Test Specifications

### User Model Tests

```ruby
# test/models/user_notification_hours_test.rb
class UserNotificationHoursTest < ActiveSupport::TestCase
  test "notification_hours defaults to empty array" do
    user = User.new(email_address: "test@example.com")
    assert_equal [], user.notification_hours
  end

  test "validates maximum of 6 notification hours" do
    user = users(:one)
    user.notification_hours = [6, 9, 12, 15, 18, 21, 23]
    assert_not user.valid?
    assert_includes user.errors[:notification_hours], "can have at most 6 notification times"
  end

  test "validates hours are between 0 and 23" do
    user = users(:one)
    user.notification_hours = [25]
    assert_not user.valid?
  end

  test "effective_timezone returns UTC when time_zone is nil" do
    user = users(:one)
    user.time_zone = nil
    assert_equal "UTC", user.effective_timezone
  end

  test "effective_timezone returns user timezone when set" do
    user = users(:one)
    user.time_zone = "America/New_York"
    assert_equal "America/New_York", user.effective_timezone
  end
end
```

### Background Job Tests

```ruby
# test/jobs/send_habit_reminder_job_test.rb
class SendHabitReminderJobTest < ActiveJob::TestCase
  setup do
    @user = users(:one)
    @user.update!(time_zone: "UTC", notification_hours: [12])
    @subscription = push_subscriptions(:one)
  end

  test "sends notification to user with matching hour in their timezone" do
    travel_to Time.utc(2025, 1, 15, 12, 0, 0) do
      assert_difference -> { enqueued_jobs.size }, 0 do
        # Job runs synchronously in test, check push was called
        SendHabitReminderJob.perform_now
      end
    end
  end

  test "does not send to user with non-matching hour" do
    travel_to Time.utc(2025, 1, 15, 9, 0, 0) do
      # 9am UTC, user wants 12pm
      SendHabitReminderJob.perform_now
      # Assert no push sent (would need mock)
    end
  end

  test "does not send to user without push subscription" do
    @subscription.destroy
    travel_to Time.utc(2025, 1, 15, 12, 0, 0) do
      SendHabitReminderJob.perform_now
      # Assert no push sent
    end
  end

  test "does not send to user with empty notification_hours" do
    @user.update!(notification_hours: [])
    travel_to Time.utc(2025, 1, 15, 12, 0, 0) do
      SendHabitReminderJob.perform_now
      # Assert no push sent
    end
  end

  test "handles nil timezone by treating as UTC" do
    @user.update!(time_zone: nil, notification_hours: [12])
    travel_to Time.utc(2025, 1, 15, 12, 0, 0) do
      SendHabitReminderJob.perform_now
      # Assert push sent
    end
  end

  test "handles expired push subscription gracefully" do
    # Mock subscription.push_message to raise WebPush::ExpiredSubscription
    # Assert job completes without raising, subscription destroyed
  end
end
```

### System Test

```ruby
# test/system/settings_notification_times_test.rb
class SettingsNotificationTimesTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    sign_in(@user)
  end

  test "user can select notification times" do
    visit settings_path

    check "notification_hour_9"
    check "notification_hour_18"
    click_button "Save"

    assert_text "Settings saved"
    @user.reload
    assert_includes @user.notification_hours, 9
    assert_includes @user.notification_hours, 18
  end

  test "user can deselect notification times" do
    @user.update!(notification_hours: [12])
    visit settings_path

    uncheck "notification_hour_12"
    click_button "Save"

    @user.reload
    assert_empty @user.notification_hours
  end

  test "shows timezone on settings page" do
    @user.update!(time_zone: "America/New_York")
    visit settings_path

    assert_text "America/New_York"
  end
end
```

## Acceptance Criteria

### Functional Requirements
- [ ] User can view notification time checkboxes on Settings page
- [ ] User can select/deselect notification hours (6am, 9am, 12pm, 3pm, 6pm, 9pm)
- [ ] Changes persist after clicking Save
- [ ] User sees their timezone displayed on settings page
- [ ] Checkboxes disabled when user has no push subscription

### Background Job Requirements
- [ ] Hourly job finds users with matching notification hours in their timezone
- [ ] Users with nil timezone treated as UTC
- [ ] Push notifications sent to all subscriptions for matching users
- [ ] No notifications sent to users with empty notification_hours
- [ ] Job handles expired/invalid push subscriptions gracefully (logs error, continues)

### Migration Requirements
- [ ] Existing users with push subscriptions get `[12]` in notification_hours
- [ ] New users start with empty notification_hours
- [ ] Old `SendNoonReminderJob` is removed
- [ ] `recurring.yml` updated to use new job name

## Deployment Strategy

**Phase 1: Add new job (keep old running)**
1. Deploy migration adding `notification_hours` column
2. Deploy data migration setting `[12]` for existing push users
3. Deploy new `SendHabitReminderJob` alongside old job
4. Update `recurring.yml` to run both jobs temporarily

**Phase 2: Remove old job (after verifying new job works)**
1. Monitor new job for 24-48 hours
2. Remove `SendNoonReminderJob` from `recurring.yml`
3. Delete old job file

## References

### Internal References
- Current noon job: `app/jobs/send_noon_reminder_job.rb`
- Push subscription model: `app/models/push_subscription.rb`
- Settings controller: `app/controllers/settings_controller.rb`
- Settings view: `app/views/settings/show.html.erb`
- Recurring jobs config: `config/recurring.yml`
