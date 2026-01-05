# frozen_string_literal: true

class SendHabitReminderJob < ApplicationJob
  queue_as :default

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

  private

  def should_notify?(user)
    user_time = Time.current.in_time_zone(user.effective_timezone)
    current_hour = user_time.hour

    return false unless user.notification_hours&.include?(current_hour)

    # Skip notification if user has already logged time in the current reminder block
    !has_logged_in_current_block?(user, user_time, current_hour)
  end

  # Determines if user has logged any habit time in the current reminder block.
  # The reminder block is defined by the user's configured notification hours.
  # For example, if hours are [6, 9, 12, 15, 18, 21] and current hour is 9,
  # the block is 6:00-9:00 (i.e., from previous notification hour to current).
  def has_logged_in_current_block?(user, user_time, current_hour)
    block_start = previous_notification_hour(user.notification_hours, current_hour)
    today = user_time.to_date

    HabitLog.joins(:habit)
            .where(habits: { user_id: user.id })
            .where(logged_on: today)
            .where("end_hour > ? AND start_hour < ?", block_start, current_hour)
            .exists?
  end

  # Find the previous notification hour before the current one.
  # If current hour is the first/smallest, wrap around to the largest (previous day's last reminder).
  def previous_notification_hour(notification_hours, current_hour)
    sorted_hours = notification_hours.sort

    # Find hours that come before current_hour
    earlier_hours = sorted_hours.select { |h| h < current_hour }

    if earlier_hours.any?
      earlier_hours.last
    else
      # Wrap around: previous block started at yesterday's last notification hour
      # Treat this as hour 0 (midnight) for today's first block
      0
    end
  end

  def send_reminder(user)
    user.push_subscriptions.each do |subscription|
      subscription.push_message(
        title: "Habit Reminder",
        body: "Time to log your habits!",
        path: "/"
      )
    rescue WebPush::Error, Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED, KeyError => e
      Rails.logger.error "Push failed for subscription #{subscription.id}: #{e.message}"
    end
  end
end
