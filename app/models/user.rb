class User < ApplicationRecord
  THEMES = %w[default monochrome].freeze

  has_many :sessions, dependent: :destroy
  has_many :magic_links, dependent: :destroy
  has_many :habits, dependent: :destroy
  has_many :push_subscriptions, dependent: :destroy

  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :theme, inclusion: { in: THEMES }

  normalizes :email_address, with: ->(email) { email.strip.downcase }

  def send_magic_link
    magic_links.create!.tap do |magic_link|
      MagicLinkMailer.sign_in_code(magic_link).deliver_later
    end
  end

  def theme_name
    case theme
    when "default" then "Bold & Colorful"
    when "monochrome" then "Monochrome Magic"
    else "Bold & Colorful"
    end
  end

  def clear_habit_logs_for_date(date)
    HabitLog.joins(:habit).where(habits: { user_id: id }, logged_on: date).destroy_all
  end
end
