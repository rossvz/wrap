# frozen_string_literal: true

class SendNoonReminderJob < ApplicationJob
  queue_as :default

  def perform
    PushSubscription.includes(:user).find_each do |subscription|
      subscription.push_message(
        title: "Time to log your habits!",
        body: "It's noon - take a moment to track what you've been up to today.",
        path: "/"
      )
    rescue => e
      Rails.logger.error "Failed to send push to subscription #{subscription.id}: #{e.message}"
    end
  end
end
