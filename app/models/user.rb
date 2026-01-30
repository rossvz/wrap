class User < ApplicationRecord
  THEMES = %w[default monochrome catppuccin].freeze

  has_many :sessions, dependent: :destroy
  has_many :magic_links, dependent: :destroy
  has_many :api_tokens, dependent: :destroy
  has_many :habits, dependent: :destroy, inverse_of: :user
  has_many :push_subscriptions, dependent: :destroy
  has_many :tags, dependent: :destroy, inverse_of: :user

  serialize :notification_hours, coder: JSON
  serialize :work_schedule, coder: JSON

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

  def work_schedule_object
    @work_schedule_object ||= WorkSchedule.new(work_schedule)
  end

  def work_hours_enabled?
    work_schedule_object.enabled?
  end

  def work_hours_enabled=(value)
    work_schedule_object.enabled = value
    sync_work_schedule_from_object
  end

  def work_start_hour
    work_schedule_object.start_hour
  end

  def work_start_hour=(value)
    work_schedule_object.start_hour = value
    sync_work_schedule_from_object
  end

  def work_end_hour
    work_schedule_object.end_hour
  end

  def work_end_hour=(value)
    work_schedule_object.end_hour = value
    sync_work_schedule_from_object
  end

  def work_days
    work_schedule_object.work_days
  end

  def work_days=(value)
    work_schedule_object.work_days = value
    sync_work_schedule_from_object
  end

  def work_day?(date)
    work_schedule_object.work_day?(date)
  end

  private

  def sync_work_schedule_from_object
    self.work_schedule = work_schedule_object.to_h
    @work_schedule_object = nil
  end

  def notification_hours_in_valid_range
    return if notification_hours.blank?
    unless notification_hours.all? { |h| h.is_a?(Integer) && h.between?(0, 23) }
      errors.add(:notification_hours, "must be valid hours (0-23)")
    end
  end

  def work_schedule_valid
    work_schedule_object.errors.each do |error|
      errors.add(:base, error)
    end
  end

  def sanitize_work_schedule
    return if work_schedule.blank?
    self.work_schedule = work_schedule.slice(*WorkSchedule::ALLOWED_KEYS)
  end
end
