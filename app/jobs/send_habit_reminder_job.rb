# frozen_string_literal: true

class SendHabitReminderJob < ApplicationJob
  queue_as :default

  def perform
    configured_hours.each do |hour|
      send_reminders_for_hour(hour)
    end
  end

  private

  def configured_hours
    User.where.not(notification_hours: "[]")
        .pluck(:notification_hours)
        .flat_map { |hours| hours.is_a?(Array) ? hours : [] }
        .uniq
  end

  def send_reminders_for_hour(hour)
    timezone_names = timezones_at_hour(hour)
    return if timezone_names.empty?

    users_to_notify(hour, timezone_names).each do |user|
      send_reminder(user)
    end
  end

  def timezones_at_hour(hour)
    ActiveSupport::TimeZone.all
      .select { |tz| Time.current.in_time_zone(tz).hour == hour }
      .map(&:name)
  end

  def users_to_notify(hour, timezone_names)
    # Build timezone conditions including nil/empty as UTC
    tz_conditions = timezone_names.dup
    if timezone_names.include?("UTC")
      tz_conditions << nil
      tz_conditions << ""
    end

    users = User.joins(:push_subscriptions)
                .includes(:push_subscriptions)
                .where(time_zone: tz_conditions)
                .distinct

    # Filter in Ruby for SQLite compatibility (JSON array check)
    users.select { |user| user.notification_hours&.include?(hour) }
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
