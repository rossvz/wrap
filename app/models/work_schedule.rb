class WorkSchedule
  ALLOWED_KEYS = %w[work_hours_enabled work_start_hour work_end_hour work_days].freeze
  DEFAULT_START_HOUR = 9.0
  DEFAULT_END_HOUR = 17.0
  DEFAULT_WORK_DAYS = [1, 2, 3, 4, 5].freeze

  attr_reader :data

  def initialize(data = {})
    @data = (data || {}).stringify_keys
  end

  def enabled?
    ActiveModel::Type::Boolean.new.cast(data["work_hours_enabled"])
  end

  def enabled=(value)
    data["work_hours_enabled"] = value
  end

  def start_hour
    (data["work_start_hour"] || DEFAULT_START_HOUR).to_d
  end

  def start_hour=(value)
    data["work_start_hour"] = value.to_d
  end

  def end_hour
    (data["work_end_hour"] || DEFAULT_END_HOUR).to_d
  end

  def end_hour=(value)
    data["work_end_hour"] = value.to_d
  end

  def work_days
    data["work_days"] || DEFAULT_WORK_DAYS.dup
  end

  def work_days=(value)
    data["work_days"] = Array(value).reject(&:blank?).map(&:to_i)
  end

  def work_day?(date)
    work_days.include?(date.wday)
  end

  def to_h
    data.slice(*ALLOWED_KEYS)
  end

  def valid?
    errors.empty?
  end

  def errors
    @errors ||= [].tap do |errs|
      next unless enabled?

      unless start_hour.between?(0, 24)
        errs << "Work start hour must be between 0 and 24"
      end

      unless end_hour.between?(0, 24)
        errs << "Work end hour must be between 0 and 24"
      end

      if start_hour >= end_hour
        errs << "Work end hour must be after start hour"
      end

      if work_days.present?
        unless work_days.is_a?(Array) && work_days.all? { |d| d.is_a?(Integer) && d.between?(0, 6) }
          errs << "Work days must be valid day numbers (0-6)"
        end
      end
    end
  end
end
