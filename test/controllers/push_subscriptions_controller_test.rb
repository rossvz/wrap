require "test_helper"

class PushSubscriptionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test "should create push subscription" do
    assert_difference("PushSubscription.count") do
      post push_subscriptions_url, params: {
        push_subscription: {
          endpoint: "https://push.example.com/new-endpoint",
          p256dh_key: "new_p256dh_key_value",
          auth_key: "new_auth_key_value"
        }
      }, as: :json
    end

    assert_response :created
    subscription = PushSubscription.last
    assert_equal @user, subscription.user
    assert_equal "https://push.example.com/new-endpoint", subscription.endpoint
  end

  test "should update existing subscription with same endpoint" do
    existing = @user.push_subscriptions.create!(
      endpoint: "https://push.example.com/existing",
      p256dh_key: "old_key",
      auth_key: "old_auth"
    )

    assert_no_difference("PushSubscription.count") do
      post push_subscriptions_url, params: {
        push_subscription: {
          endpoint: "https://push.example.com/existing",
          p256dh_key: "new_p256dh_key_value",
          auth_key: "new_auth_key_value"
        }
      }, as: :json
    end

    assert_response :created
    existing.reload
    assert_equal "new_p256dh_key_value", existing.p256dh_key
  end

  test "should destroy push subscription" do
    subscription = @user.push_subscriptions.create!(
      endpoint: "https://push.example.com/to-delete",
      p256dh_key: "test_key",
      auth_key: "test_auth"
    )

    assert_difference("PushSubscription.count", -1) do
      delete push_subscription_url(subscription), params: {
        endpoint: subscription.endpoint
      }, as: :json
    end

    assert_response :ok
  end

  test "should require authentication" do
    sign_out

    post push_subscriptions_url, params: {
      push_subscription: {
        endpoint: "https://push.example.com/test",
        p256dh_key: "test_key",
        auth_key: "test_auth"
      }
    }, as: :json

    assert_redirected_to new_session_url
  end
end
