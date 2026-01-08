class User < ApplicationRecord
  THEMES = %w[default monochrome catppuccin].freeze

  has_many :sessions, dependent: :destroy
  has_many :magic_links, dependent: :destroy
  has_many :habits, dependent: :destroy, inverse_of: :user
  has_many :push_subscriptions, dependent: :destroy
  has_many :tags, dependent: :destroy, inverse_of: :user

  serialize :notification_hours, coder: JSON
  serialize :work_schedule, coder: JSON

  ALLOWED_WORK_SCHEDULE_KEYS = %w[work_hours_enabled work_start_hour work_end_hour work_days].freeze

  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :theme, inclusion: { in: THEMES }
  validates :notification_hours, length: { maximum: 6, message: "can have at most 6 notification times" }
  validate :notification_hours_in_valid_range
  validate :work_schedule_valid

  before_save :sanitize_work_schedule

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

  def work_hours_enabled?
    ActiveModel::Type::Boolean.new.cast(work_schedule&.dig("work_hours_enabled"))
  end

  def work_start_hour
    (work_schedule&.dig("work_start_hour") || 9.0).to_d
  end

  def work_end_hour
    (work_schedule&.dig("work_end_hour") || 17.0).to_d
  end

  def work_days
    work_schedule&.dig("work_days") || [ 1, 2, 3, 4, 5 ]
  end

  def work_day?(date)
    work_days.include?(date.wday)
  end

  def work_hours_enabled=(value)
    self.work_schedule = (work_schedule || {}).merge("work_hours_enabled" => value)
  end

  def work_start_hour=(value)
    self.work_schedule = (work_schedule || {}).merge("work_start_hour" => value.to_d)
  end

  def work_end_hour=(value)
    self.work_schedule = (work_schedule || {}).merge("work_end_hour" => value.to_d)
  end

  def work_days=(value)
    days = Array(value).reject(&:blank?).map(&:to_i)
    self.work_schedule = (work_schedule || {}).merge("work_days" => days)
  end

  private

  def notification_hours_in_valid_range
    return if notification_hours.blank?
    unless notification_hours.all? { |h| h.is_a?(Integer) && h.between?(0, 23) }
      errors.add(:notification_hours, "must be valid hours (0-23)")
    end
  end

  def work_schedule_valid
    return unless work_hours_enabled?

    unless work_start_hour.between?(0, 24)
      errors.add(:base, "Work start hour must be between 0 and 24")
    end

    unless work_end_hour.between?(0, 24)
      errors.add(:base, "Work end hour must be between 0 and 24")
    end

    if work_start_hour >= work_end_hour
      errors.add(:base, "Work end hour must be after start hour")
    end

    if work_days.present?
      unless work_days.is_a?(Array) && work_days.all? { |d| d.is_a?(Integer) && d.between?(0, 6) }
        errors.add(:base, "Work days must be valid day numbers (0-6)")
      end
    end
  end

  def sanitize_work_schedule
    return if work_schedule.blank?
    self.work_schedule = work_schedule.slice(*ALLOWED_WORK_SCHEDULE_KEYS)
  end
end
