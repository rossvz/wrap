class Tag < ApplicationRecord
  MAX_NAME_LENGTH = 30

  belongs_to :user, inverse_of: :tags
  has_many :taggings, dependent: :destroy, inverse_of: :tag
  has_many :habits, through: :taggings

  validates :name, presence: true,
                   length: { maximum: MAX_NAME_LENGTH },
                   format: { with: /\A[a-z0-9\s\-_]+\z/,
                             message: "only allows letters, numbers, spaces, hyphens, underscores" },
                   uniqueness: { scope: :user_id, case_sensitive: false }

  normalizes :name, with: ->(name) { name.to_s.strip.downcase }

  def self.sanitize_name(name)
    sanitized = name.to_s.strip.downcase
    return nil if sanitized.blank? || sanitized.length > MAX_NAME_LENGTH
    sanitized
  end

  scope :alphabetically, -> { order(name: :asc) }
  scope :by_popularity, -> { order(taggings_count: :desc) }
end
