# frozen_string_literal: true

class PushSubscription < ApplicationRecord
  belongs_to :user

  validates :endpoint, presence: true, uniqueness: true
  validates :p256dh_key, presence: true
  validates :auth_key, presence: true

  def push_message(title:, body:, path: "/")
    WebPush.payload_send(
      message: JSON.generate(
        title: title,
        options: {
          body: body,
          icon: "/icon.png",
          badge: "/icon.png",
          data: { path: path }
        }
      ),
      endpoint: endpoint,
      p256dh: p256dh_key,
      auth: auth_key,
      vapid: {
        public_key: ENV.fetch("VAPID_PUBLIC_KEY"),
        private_key: ENV.fetch("VAPID_PRIVATE_KEY")
      }
    )
  rescue WebPush::ExpiredSubscription, WebPush::InvalidSubscription
    destroy
  end
end
