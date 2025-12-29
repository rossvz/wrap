# frozen_string_literal: true

# Web Push configuration for push notifications
# VAPID keys can be generated with: WebPush.generate_key
#
# Store these in your environment:
#   VAPID_PUBLIC_KEY  - shared with browser for subscription
#   VAPID_PRIVATE_KEY - kept secret on server for signing
Rails.application.config.to_prepare do
  WebPush.configure do |config|
    config.vapid_public_key = ENV.fetch("VAPID_PUBLIC_KEY", nil)
    config.vapid_private_key = ENV.fetch("VAPID_PRIVATE_KEY", nil)
  end
end
