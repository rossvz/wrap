# frozen_string_literal: true

# Web Push configuration for push notifications
# VAPID keys can be generated with: WebPush.generate_key
#
# Store these in your environment:
#   VAPID_PUBLIC_KEY  - shared with browser for subscription
#   VAPID_PRIVATE_KEY - kept secret on server for signing

# No global configuration needed for web-push 3.x
# VAPID keys are passed directly to WebPush.payload_send
