class Tag < ApplicationRecord
  belongs_to :user
  has_many :taggings, dependent: :destroy
  has_many :habits, through: :taggings

  validates :name, presence: true,
                   length: { maximum: 30 },
                   format: { with: /\A[a-z0-9\s\-_]+\z/,
                             message: "only allows letters, numbers, spaces, hyphens, underscores" },
                   uniqueness: { scope: :user_id, case_sensitive: false }

  normalizes :name, with: ->(name) { name.to_s.strip.downcase }

  scope :alphabetically, -> { order(name: :asc) }
  scope :by_popularity, -> { order(taggings_count: :desc) }
  scope :matching, ->(query) {
    return none if query.blank?
    sanitized = query.to_s.first(50).downcase.gsub(/[%_\\]/) { |c| "\\#{c}" }
    where("name LIKE ?", "#{sanitized}%")
  }
end
