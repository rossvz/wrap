class Tag < ApplicationRecord
  belongs_to :user, inverse_of: :tags
  has_many :taggings, dependent: :destroy, inverse_of: :tag
  has_many :habits, through: :taggings

  validates :name, presence: true,
                   length: { maximum: 30 },
                   format: { with: /\A[a-z0-9\s\-_]+\z/,
                             message: "only allows letters, numbers, spaces, hyphens, underscores" },
                   uniqueness: { scope: :user_id, case_sensitive: false }

  normalizes :name, with: ->(name) { name.to_s.strip.downcase }

  scope :alphabetically, -> { order(name: :asc) }
  scope :by_popularity, -> { order(taggings_count: :desc) }
end
