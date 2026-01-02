class User < ApplicationRecord
  THEMES = %w[default monochrome catppuccin].freeze

  has_many :sessions, dependent: :destroy
  has_many :magic_links, dependent: :destroy
  has_many :habits, dependent: :destroy
  has_many :push_subscriptions, dependent: :destroy

  serialize :notification_hours, coder: JSON

  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :theme, inclusion: { in: THEMES }
  validates :notification_hours, length: { maximum: 6, message: "can have at most 6 notification times" }
  validate :notification_hours_in_valid_range

  normalizes :email_address, with: ->(email) { email.strip.downcase }
  normalizes :notification_hours, with: ->(hours) { Array(hours).map(&:to_i) }

  def send_magic_link
    magic_links.create!.tap do |magic_link|
      MagicLinkMailer.sign_in_code(magic_link).deliver_later
    end
  end

  def theme_name
    case theme
    when "default" then "Bold & Colorful"
    when "monochrome" then "Monochrome Magic"
    when "catppuccin" then "Catppuccin Dark"
    else "Bold & Colorful"
    end
  end

  def clear_habit_logs_for_date(date)
    HabitLog.joins(:habit).where(habits: { user_id: id }, logged_on: date).destroy_all
  end

  def effective_timezone
    time_zone.presence || "UTC"
  end

  private

  def notification_hours_in_valid_range
    return if notification_hours.blank?
    unless notification_hours.all? { |h| h.is_a?(Integer) && h.between?(0, 23) }
      errors.add(:notification_hours, "must be valid hours (0-23)")
    end
  end
end
