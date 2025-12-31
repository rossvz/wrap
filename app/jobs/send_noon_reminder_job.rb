# frozen_string_literal: true

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
