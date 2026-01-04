require "test_helper"

class TagTest < ActiveSupport::TestCase
  test "validates presence of name" do
    tag = Tag.new(user: users(:one))
    assert_not tag.valid?
    assert_includes tag.errors[:name], "can't be blank"
  end

  test "validates length of name" do
    tag = Tag.new(user: users(:one), name: "a" * 31)
    assert_not tag.valid?
    assert_includes tag.errors[:name], "is too long (maximum is 30 characters)"
  end

  test "validates format of name" do
    tag = Tag.new(user: users(:one), name: "test<script>")
    assert_not tag.valid?
    assert_includes tag.errors[:name], "only allows letters, numbers, spaces, hyphens, underscores"
  end

  test "validates uniqueness of name per user" do
    user = users(:one)
    Tag.create!(user: user, name: "duplicate")

    duplicate_tag = Tag.new(user: user, name: "duplicate")
    assert_not duplicate_tag.valid?
    assert_includes duplicate_tag.errors[:name], "has already been taken"
  end

  test "allows same name for different users" do
    tag1 = Tag.create!(user: users(:one), name: "shared")
    tag2 = Tag.new(user: users(:two), name: "shared")
    assert tag2.valid?
  end

  test "normalizes name to lowercase and strips whitespace" do
    tag = Tag.create!(user: users(:one), name: "  My Tag  ")
    assert_equal "my tag", tag.name
  end

  test "alphabetically scope orders by name" do
    user = users(:one)
    z_tag = Tag.create!(user: user, name: "zebra")
    a_tag = Tag.create!(user: user, name: "alpha")

    tags = user.tags.alphabetically
    assert_equal a_tag.id, tags.first.id
  end

  test "by_popularity scope orders by taggings_count descending" do
    user = users(:one)
    tags = user.tags.by_popularity
    assert tags.first.taggings_count >= tags.last.taggings_count
  end

  test "matching scope finds tags starting with query" do
    user = users(:one)
    Tag.create!(user: user, name: "workout")
    Tag.create!(user: user, name: "work")
    Tag.create!(user: user, name: "reading")

    matches = user.tags.matching("wor")
    assert_equal 2, matches.count
    matches.each { |t| assert t.name.start_with?("wor") }
  end

  test "matching scope handles blank query" do
    user = users(:one)
    assert_empty user.tags.matching("")
    assert_empty user.tags.matching(nil)
  end

  test "matching scope escapes SQL wildcards" do
    user = users(:one)
    Tag.create!(user: user, name: "test-underscore")
    Tag.create!(user: user, name: "testing")

    matches = user.tags.matching("test_")
    assert_empty matches
  end
end
