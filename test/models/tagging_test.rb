require "test_helper"

class TaggingTest < ActiveSupport::TestCase
  test "validates uniqueness of tag per habit" do
    tag = tags(:health)
    habit = habits(:one)

    duplicate = Tagging.new(tag: tag, habit: habit)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:tag_id], "has already been taken"
  end

  test "increments tag counter on create" do
    tag = tags(:productivity)
    habit = habits(:two)
    initial_count = tag.taggings_count

    Tagging.create!(tag: tag, habit: habit)
    tag.reload

    assert_equal initial_count + 1, tag.taggings_count
  end

  test "decrements tag counter on destroy" do
    tagging = taggings(:reading_health)
    tag = tagging.tag
    initial_count = tag.taggings_count

    tagging.destroy
    tag.reload

    assert_equal initial_count - 1, tag.taggings_count
  end
end
