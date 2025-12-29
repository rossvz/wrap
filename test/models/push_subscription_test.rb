require "test_helper"

class PushSubscriptionTest < ActiveSupport::TestCase
  test "requires user" do
    subscription = PushSubscription.new(
      endpoint: "https://example.com/push",
      p256dh_key: "test_key",
      auth_key: "test_auth"
    )
    assert_not subscription.valid?
    assert_includes subscription.errors[:user], "must exist"
  end

  test "requires endpoint" do
    user = users(:one)
    subscription = user.push_subscriptions.build(
      p256dh_key: "test_key",
      auth_key: "test_auth"
    )
    assert_not subscription.valid?
    assert_includes subscription.errors[:endpoint], "can't be blank"
  end

  test "requires p256dh_key" do
    user = users(:one)
    subscription = user.push_subscriptions.build(
      endpoint: "https://example.com/push",
      auth_key: "test_auth"
    )
    assert_not subscription.valid?
    assert_includes subscription.errors[:p256dh_key], "can't be blank"
  end

  test "requires auth_key" do
    user = users(:one)
    subscription = user.push_subscriptions.build(
      endpoint: "https://example.com/push",
      p256dh_key: "test_key"
    )
    assert_not subscription.valid?
    assert_includes subscription.errors[:auth_key], "can't be blank"
  end

  test "endpoint must be unique" do
    existing = push_subscriptions(:one)
    user = users(:two)
    subscription = user.push_subscriptions.build(
      endpoint: existing.endpoint,
      p256dh_key: "test_key",
      auth_key: "test_auth"
    )
    assert_not subscription.valid?
    assert_includes subscription.errors[:endpoint], "has already been taken"
  end

  test "belongs to user" do
    subscription = push_subscriptions(:one)
    assert_equal users(:one), subscription.user
  end
end
