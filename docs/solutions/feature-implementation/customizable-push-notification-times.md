---
title: "Implementing Customizable Push Notification Times with SQLite JSON Storage"
date: 2026-01-02
category: feature-implementation
tags:
  - push-notifications
  - sqlite
  - json-serialization
  - background-jobs
  - timezone-handling
  - form-handling
  - rails-8
components:
  - User model
  - SendHabitReminderJob
  - SettingsController
  - Settings view
symptoms:
  - Hardcoded noon-only push notifications not flexible for users
  - SQLite migration failures when using PostgreSQL array syntax
  - Form 422 errors when saving checkbox selections
  - Complex nested loop structure in background job
root_cause: "Initial implementation attempted PostgreSQL-specific features (array columns) on SQLite, combined with form parameter type mismatches (strings vs integers) and overly complex job iteration logic"
---

# Customizable Push Notification Times

## Problem Statement

The application had a hardcoded noon-only notification system where all users received push notifications at 12 PM in their timezone. This one-size-fits-all approach did not accommodate:

- Early risers who want morning reminders (e.g., 7 AM)
- Night owls who prefer evening check-ins (e.g., 9 PM)
- Users who want multiple reminders throughout the day

## Solution Overview

Allow users to select notification hours from a checkbox grid (6am, 9am, 12pm, 3pm, 6pm, 9pm) on the Settings page. Store preferences as a JSON array on the User model. Background job runs hourly and checks each user's current hour in their timezone.

## Bugs Encountered and Fixes

### 1. SQLite Array Column Limitation

**Symptom**: Migration failed with PostgreSQL array syntax.

**Root Cause**: SQLite does not support native array columns. The `array: true` syntax is PostgreSQL-specific.

**Solution**: Use a TEXT column with JSON serialization.

```ruby
# Migration
add_column :users, :notification_hours, :text, default: "[]", null: false

# Model
serialize :notification_hours, coder: JSON
```

### 2. Form Submits Strings Instead of Integers

**Symptom**: 422 Unprocessable Entity when saving notification times. Validation failed because `"12".is_a?(Integer)` returns false.

**Root Cause**: HTML form checkbox values are always transmitted as strings.

**Solution**: Add a normalizer to convert string values to integers.

```ruby
normalizes :notification_hours, with: ->(hours) { Array(hours).map(&:to_i) }
```

### 3. params.expect Required All Fields

**Symptom**: 422 error when submitting notification times form (which doesn't include theme).

**Root Cause**: `params.expect` enforces that all specified keys must be present.

**Solution**: Use `params.permit` for optional parameters.

```ruby
def settings_params
  params.require(:user).permit(:theme, notification_hours: [])
end
```

### 4. Complex Job Loop Logic

**Symptom**: Overly complex code with multiple nested loops and PostgreSQL-specific queries.

**Root Cause**: Original approach looped hours -> timezones -> users, requiring `ANY()` array syntax that doesn't work with SQLite/JSON.

**Solution**: Invert the logic - iterate users once and check `should_notify?` for each.

```ruby
def perform
  User.joins(:push_subscriptions)
      .includes(:push_subscriptions)
      .where.not(notification_hours: "[]")
      .distinct
      .each do |user|
    next unless should_notify?(user)
    send_reminder(user)
  end
end

def should_notify?(user)
  current_hour = Time.current.in_time_zone(user.effective_timezone).hour
  user.notification_hours&.include?(current_hour)
end
```

### 5. Bare Rescue Catching All Exceptions

**Symptom**: RuboCop warnings; potential for masking programming errors.

**Root Cause**: `rescue => e` catches everything including `SystemExit`, `NoMemoryError`, etc.

**Solution**: Specify exact exception types.

```ruby
rescue WebPush::Error, Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED, KeyError => e
  Rails.logger.error "Push failed for subscription #{subscription.id}: #{e.message}"
end
```

### 6. Test SQLite Files Committed

**Symptom**: Binary files in git diff, merge conflicts.

**Root Cause**: `.gitignore` pattern `*.sqlite3-*` didn't match `*.sqlite3_*` (hyphen vs underscore).

**Solution**: Add underscore pattern to `.gitignore`.

```gitignore
/storage/*.sqlite3_*
```

## Key Files

| File | Purpose |
|------|---------|
| `db/migrate/*_add_notification_hours_to_users.rb` | Add TEXT column for JSON storage |
| `db/migrate/*_migrate_existing_push_users_to_noon_notification.rb` | Set existing push users to noon |
| `app/models/user.rb` | Serialization, normalizer, validation |
| `app/controllers/settings_controller.rb` | Strong params with permit |
| `app/views/settings/show.html.erb` | Checkbox grid UI |
| `app/jobs/send_habit_reminder_job.rb` | Simplified hourly job |

## Model Implementation

```ruby
class User < ApplicationRecord
  serialize :notification_hours, coder: JSON

  validates :notification_hours, length: { maximum: 6, message: "can have at most 6 notification times" }
  validate :notification_hours_in_valid_range

  normalizes :notification_hours, with: ->(hours) { Array(hours).map(&:to_i) }

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

## Prevention Strategies

### SQLite vs PostgreSQL
- Develop with the same database as production
- Avoid database-specific features or abstract them
- Use ActiveRecord methods over raw SQL

### Form Checkbox Values
- Always normalize string inputs in the model
- Test with actual form-submitted values (strings)

### Strong Parameters
- Use `params.expect` for required params
- Use `params.permit` for optional/partial updates

### Background Jobs
- Push filtering to the database when possible
- Use `find_each` for large datasets
- Single responsibility per job

### Exception Handling
- Always specify the exception class
- Log errors before handling
- Consider re-raising in development

## Related Documentation

- `docs/solutions/logic-errors/timezone-handling-client-server-sync.md` - Timezone handling patterns
- `plans/customizable-push-notification-times.md` - Original feature plan

## PR Reference

- PR #22: feat(notifications): Add customizable push notification times
