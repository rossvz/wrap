# frozen_string_literal: true

class PushSubscriptionsController < ApplicationController
  def create
    subscription = current_user.push_subscriptions.find_or_initialize_by(
      endpoint: subscription_params[:endpoint]
    )

    subscription.p256dh_key = subscription_params[:p256dh_key]
    subscription.auth_key = subscription_params[:auth_key]

    if subscription.save
      head :created
    else
      head :unprocessable_entity
    end
  end

  def destroy
    subscription = current_user.push_subscriptions.find_by(
      endpoint: params[:endpoint]
    )

    subscription&.destroy
    head :ok
  end

  def test
    count = current_user.push_subscriptions.count
    Rails.logger.info "Sending test push to #{count} subscription(s)"

    current_user.push_subscriptions.find_each do |subscription|
      Rails.logger.info "Pushing to endpoint: #{subscription.endpoint[0..50]}..."
      subscription.push_message(
        title: "Test notification",
        body: "Push notifications are working!",
        path: "/"
      )
    end
    head :ok
  end

  private

  def subscription_params
    params.expect(push_subscription: [ :endpoint, :p256dh_key, :auth_key ])
  end
end
