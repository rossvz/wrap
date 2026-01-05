class Tagging < ApplicationRecord
  belongs_to :tag, counter_cache: true, inverse_of: :taggings
  belongs_to :habit, inverse_of: :taggings

  validates :tag_id, uniqueness: { scope: :habit_id }
end
