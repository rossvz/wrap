class Habit < ApplicationRecord
  # Available color tokens (1-8)
  COLOR_TOKENS = (1..8).to_a.freeze

  belongs_to :user, optional: true
  has_many :habit_logs, dependent: :destroy
  has_many :taggings, dependent: :destroy
  has_many :tags, through: :taggings

  validates :name, presence: true
  validates :color_token, presence: true, inclusion: { in: COLOR_TOKENS }

  scope :with_tag, ->(tag_name) {
    joins(:tags).where(tags: { name: tag_name.downcase }).distinct
  }

  scope :with_any_tags, ->(tag_names) {
    joins(:tags).where(tags: { name: tag_names.map(&:downcase) }).distinct
  }

  # Use before_validation so user association is set when we check for unused tokens
  before_validation :set_defaults, on: :create

  # Find an existing habit or create a new one for the user
  # Returns nil if no habit_id or new_habit_name provided
  def self.find_or_create_for_user(user, habit_id:, new_habit_name: nil)
    return user.habits.find_by(id: habit_id) if habit_id.present?

    if new_habit_name.present?
      return user.habits.create(name: new_habit_name.strip)
    end

    nil
  end

  # Find next unused color token for a given scope (e.g., user's habits)
  def self.next_unused_token(scope = all)
    used_tokens = scope.pluck(:color_token)
    available_tokens = COLOR_TOKENS - used_tokens
    available_tokens = COLOR_TOKENS if available_tokens.empty?
    # Return in order (1, 2, 3...) rather than random for predictability
    available_tokens.min
  end

  def set_defaults
    self.active = true if self.active.nil?
    # Always assign next available color if not explicitly set via form
    # We track this with an instance variable since DB default makes color_token non-nil
    self.color_token = next_available_color_token unless @color_token_was_set
  end

  def color_token=(value)
    @color_token_was_set = true
    super
  end

  def next_available_color_token
    scope = user ? user.habits : Habit.all
    Habit.next_unused_token(scope)
  end

  # Returns CSS variable reference for use in style attributes
  def color_css_var
    "var(--habit-color-#{color_token})"
  end

  # Returns CSS class for habit background
  def color_class
    "habit-bg-#{color_token}"
  end

  def logs_for(date)
    habit_logs.for_date(date).ordered_by_time
  end

  def hours_for(date)
    logs_for(date).sum(&:duration_hours)
  end

  def total_hours
    habit_logs.sum(&:duration_hours)
  end
end
