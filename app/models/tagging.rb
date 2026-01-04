class Tagging < ApplicationRecord
  belongs_to :tag
  belongs_to :habit

  validates :tag_id, uniqueness: { scope: :habit_id }

  after_create :increment_tag_counter
  after_destroy :decrement_tag_counter

  private

  def increment_tag_counter
    Tag.where(id: tag_id).update_all("taggings_count = taggings_count + 1")
  end

  def decrement_tag_counter
    Tag.where(id: tag_id).update_all("taggings_count = CASE WHEN taggings_count > 0 THEN taggings_count - 1 ELSE 0 END")
  end
end
