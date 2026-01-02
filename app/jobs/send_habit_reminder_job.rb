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
    current_hour = Time.current.in_time_zone(user.effective_timezone).hour
    user.notification_hours&.include?(current_hour)
  end

  def send_reminder(user)
    user.push_subscriptions.each do |subscription|
      subscription.push_message(
        title: "Habit Reminder",
        body: "Time to log your habits!",
        path: "/"
      )
    rescue WebPush::Error, Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED => e
      Rails.logger.error "Push failed for subscription #{subscription.id}: #{e.message}"
    end
  end
end
