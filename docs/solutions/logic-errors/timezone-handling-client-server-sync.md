# Timezone Handling for Date Display and Scheduled Notifications

---
title: "Timezone Handling for Date Display and Scheduled Notifications"
problem_type: timezone_mismatch
category: logic-errors
components:
  - app/controllers/application_controller.rb
  - app/javascript/controllers/timezone_controller.js
  - app/jobs/send_noon_reminder_job.rb
  - app/views/layouts/application.html.erb
  - config/recurring.yml
symptoms:
  - Dashboard displays wrong date for user's local time
  - "Today" calculations show UTC date instead of local date
  - Push notifications arrive at wrong local time
  - Noon reminders sent at midnight or early morning for some users
  - All users receive scheduled notifications simultaneously regardless of location
keywords:
  - timezone
  - time zone
  - UTC
  - stale date
  - wrong date
  - push notification timing
  - noon reminder
  - Intl.DateTimeFormat
  - browser timezone
  - timezone cookie
  - Time.zone
  - Time.use_zone
  - scheduled job timezone
  - per-user timezone
  - ActiveSupport::TimeZone
related_commits:
  - c2f7677
  - 220237b
  - 2bf343e
solved_date: 2025-12-31
---

## Problem Summary

Two related timezone issues caused incorrect behavior for users outside the server's timezone:

1. **Stale Date Display**: The dashboard showed the wrong date based on UTC server time instead of the user's local timezone
2. **Noon Reminder Wrong Time**: Push notifications fired at 12pm UTC for all users instead of 12pm in each user's local time

## Symptoms

### Issue 1: Wrong Date Display
- A user in Los Angeles (PST, UTC-8) accessing the app at 1:00 AM UTC on December 30 would see "December 30, 2025" instead of "December 29, 2025" (their actual local date)
- Habit logs could be associated with the wrong calendar day
- Analytics showed data for the wrong day

### Issue 2: Wrong Notification Time
- Users received "It's noon" push notifications at the wrong time
- A user in Los Angeles (UTC-8) would receive the noon reminder at 4:00 AM local time
- All users globally received notifications simultaneously

## Root Cause Analysis

### Issue 1: No Client Timezone Detection
- The Rails server used UTC for `Time.zone` operations
- No mechanism existed to detect or use the browser's actual timezone
- When calculating "today" for the dashboard, the server had no knowledge of user location

### Issue 2: Server-Centric Job Scheduling
- `SendNoonReminderJob` was scheduled with `at 12pm every day` (server timezone)
- The job sent notifications to ALL users without checking their timezones
- User timezone was stored in session but not on the User model, making it inaccessible to background jobs

## Solution

### Part 1: Client-Side Timezone Detection

Created a Stimulus controller to detect and persist browser timezone:

**app/javascript/controllers/timezone_controller.js**
```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.ensureTimezoneCookie()
  }

  ensureTimezoneCookie() {
    if (!this.supportsTimeZones()) return

    const browserTimeZone = Intl.DateTimeFormat().resolvedOptions().timeZone
    if (!browserTimeZone) return

    const cookieTimeZone = this.readCookie("timezone")
    if (cookieTimeZone === browserTimeZone) return

    this.writeCookie(browserTimeZone)

    if (this.readCookie("timezone") === browserTimeZone) {
      window.location.reload()
    }
  }

  supportsTimeZones() {
    return typeof Intl !== "undefined" &&
      typeof Intl.DateTimeFormat === "function" &&
      typeof Intl.DateTimeFormat().resolvedOptions === "function"
  }

  readCookie(name) {
    const match = document.cookie.match(new RegExp("(?:^|; )" + name + "=([^;]*)"))
    return match ? decodeURIComponent(match[1]) : null
  }

  writeCookie(value) {
    const encoded = encodeURIComponent(value)
    document.cookie = `timezone=${encoded};path=/;max-age=${60 * 60 * 24 * 365}`
  }
}
```

Attached to body in layout:
```erb
<body data-controller="timezone">
```

### Part 2: Server-Side Timezone Application

Modified ApplicationController to use the timezone cookie per-request:

**app/controllers/application_controller.rb**
```ruby
before_action :set_time_zone
after_action :reset_time_zone
after_action :persist_time_zone_from_cookie

private

def set_time_zone
  @previous_time_zone = Time.zone
  zone_name = resolved_time_zone
  Time.zone = zone_name if zone_name
end

def reset_time_zone
  Time.zone = @previous_time_zone if defined?(@previous_time_zone)
end

def persist_time_zone_from_cookie
  zone_name = normalize_time_zone(cookies[:timezone])
  return unless zone_name && Current.session

  Current.session.update_column(:time_zone, zone_name) if Current.session.time_zone != zone_name

  user = Current.session.user
  user.update_column(:time_zone, zone_name) if user && user.time_zone != zone_name
end

def resolved_time_zone
  normalize_time_zone(cookies[:timezone]) || normalize_time_zone(Current.session&.time_zone)
end

def normalize_time_zone(zone)
  return if zone.blank?
  ActiveSupport::TimeZone[zone]&.name
end
```

### Part 3: Timezone-Aware Background Job

Rewrote the noon reminder job to check each user's timezone:

**app/jobs/send_noon_reminder_job.rb**
```ruby
class SendNoonReminderJob < ApplicationJob
  queue_as :default

  def perform
    noon_time_zones = time_zones_where_noon
    return if noon_time_zones.empty?

    PushSubscription.includes(:user).where(users: { time_zone: noon_time_zones }).find_each do |subscription|
      subscription.push_message(
        title: "Time to log your habits!",
        body: "It's noon - take a moment to track what you've been up to today.",
        path: "/"
      )
    rescue => e
      Rails.logger.error "Failed to send push to subscription #{subscription.id}: #{e.message}"
    end
  end

  private

  def time_zones_where_noon
    ActiveSupport::TimeZone.all.select do |tz|
      Time.current.in_time_zone(tz).hour == 12
    end.map(&:name)
  end
end
```

Changed schedule from daily to hourly:

**config/recurring.yml**
```yaml
production:
  send_noon_reminder:
    class: SendNoonReminderJob
    schedule: every hour
```

### Part 4: Database Schema Changes

Added `time_zone` column to users table with migration that backfills from session data:

**db/migrate/20251231135225_add_time_zone_to_users.rb**
```ruby
class AddTimeZoneToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :time_zone, :string

    reversible do |dir|
      dir.up do
        execute <<~SQL
          UPDATE users
          SET time_zone = (
            SELECT sessions.time_zone
            FROM sessions
            WHERE sessions.user_id = users.id
              AND sessions.time_zone IS NOT NULL
            ORDER BY sessions.updated_at DESC
            LIMIT 1
          )
        SQL
      end
    end
  end
end
```

## How It Works

The solution uses a two-layer approach:

1. **Request-scoped timezone** (for display): JavaScript detects the browser timezone, stores it in a cookie, and the server uses that cookie to set `Time.zone` for each request. This ensures dates/times display correctly.

2. **Persistent user timezone** (for background jobs): The timezone is also persisted to the user model, enabling background jobs to query users by their stored timezone and send notifications at the right local time.

## Testing

**test/controllers/dashboard_controller_test.rb**
```ruby
test "dashboard respects timezone cookie" do
  travel_to Time.utc(2025, 12, 30, 1, 0, 0) do  # 1am UTC = Dec 29 5pm PST
    cookies[:timezone] = "America/Los_Angeles"
    get dashboard_url

    assert_response :success
    assert_includes @response.body, "December 29, 2025"
  end
end
```

**test/jobs/send_noon_reminder_job_test.rb**
```ruby
test "sends notification only to users in noon timezone" do
  travel_to Time.utc(2025, 1, 15, 17, 0, 0) do  # 12pm EST
    user = users(:one)
    user.update!(time_zone: "America/New_York")

    # Assert notification sent to EST user
    # Assert no notification to PST user (9am there)
  end
end
```

## Prevention Strategies

### Avoid These Dangerous Methods

| Avoid | Use Instead | Reason |
|-------|-------------|--------|
| `Time.now` | `Time.current` | Uses system timezone |
| `Date.today` | `Time.zone.today` | Uses system timezone |
| `Time.parse("...")` | `Time.zone.parse("...")` | Parses in system timezone |

### Checklist for Timezone-Related Features

- [ ] Use `Time.zone.today` instead of `Date.today`
- [ ] Use `Time.current` instead of `Time.now`
- [ ] Store user timezone in database for background job access
- [ ] For time-of-day triggers, schedule jobs hourly and filter by timezone
- [ ] Test with `travel_to Time.utc(...)` to simulate different times
- [ ] Test date boundaries where UTC and local dates differ

### Background Job Guidelines

- Store timezone on user record (not just session)
- Load timezone from database at job execution time
- For user-local-time-sensitive jobs, iterate through `ActiveSupport::TimeZone.all`
- Handle DST transitions gracefully

## Related Files

| File | Purpose |
|------|---------|
| `app/javascript/controllers/timezone_controller.js` | Client-side timezone detection |
| `app/controllers/application_controller.rb` | Per-request timezone application |
| `app/jobs/send_noon_reminder_job.rb` | Timezone-aware background job |
| `app/models/day_summary.rb` | Uses `Time.zone.today` for date calculations |
| `app/models/week_summary.rb` | Uses `Date.current` for week boundaries |

## Cross-References

- Related commits: c2f7677, 220237b, 2bf343e
- Test files: `test/controllers/dashboard_controller_test.rb`, `test/jobs/send_noon_reminder_job_test.rb`
