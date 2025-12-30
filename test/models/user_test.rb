require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "themes list includes catppuccin" do
    assert_includes User::THEMES, "catppuccin"
  end

  test "theme_name returns friendly label for catppuccin" do
    user = users(:one)
    user.theme = "catppuccin"

    assert_equal "Catppuccin Dark", user.theme_name
  end
end
