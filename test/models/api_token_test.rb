require "test_helper"

class ApiTokenTest < ActiveSupport::TestCase
  test "belongs to user" do
    token = api_tokens(:one)
    assert_equal users(:one), token.user
  end

  test "generates secure token on create" do
    user = users(:one)
    token = user.api_tokens.create!(name: "New Token")

    assert token.token.present?
    assert token.token.length >= 24
  end

  test "validates name length" do
    user = users(:one)
    token = user.api_tokens.build(name: "a" * 101)

    assert_not token.valid?
    assert_includes token.errors[:name], "is too long (maximum is 100 characters)"
  end

  test "touch_usage! updates last_used_at and last_used_ip" do
    token = api_tokens(:one)
    original_time = token.last_used_at

    freeze_time do
      token.touch_usage!("10.0.0.1")

      assert_equal Time.current, token.last_used_at
      assert_equal "10.0.0.1", token.last_used_ip
    end
  end

  test "token uniqueness enforced by database" do
    existing = api_tokens(:one)
    user = users(:one)

    duplicate = user.api_tokens.build(name: "Duplicate")
    duplicate.token = existing.token

    assert_raises(ActiveRecord::RecordNotUnique) do
      duplicate.save(validate: false)
    end
  end
end
