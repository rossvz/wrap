class DaySummary
  START_HOUR = 6
  END_HOUR = 24

  TIME_SECTIONS = {
    6 => { name: "Your Morning", bg: "bg-morning" },
    12 => { name: "Your Afternoon", bg: "bg-afternoon" },
    18 => { name: "Your Evening", bg: "bg-evening" }
  }.freeze

  attr_reader :user, :date, :tag_filter

  def initialize(user, date = Time.zone.today, tag_filter: nil)
    @user = user
    @date = date
    @tag_filter = tag_filter
  end

  def habits
    @habits ||= begin
      scope = user.habits.where(active: true)
      scope = scope.with_tag(@tag_filter) if @tag_filter.present?
      scope.order(created_at: :asc)
    end
  end

  def time_blocks
    @time_blocks ||= HabitLog.includes(:habit)
                             .where(logged_on: date, habit_id: habits.select(:id))
                             .order(:start_hour)
  end

  def total_hours
    @total_hours ||= time_blocks.sum(&:duration_hours).round(1)
  end

  # Returns array of { habit: Habit, hours: Float } sorted by most hours
  def activity_breakdown
    @activity_breakdown ||= time_blocks.group_by(&:habit).map do |habit, logs|
      { habit: habit, hours: logs.sum(&:duration_hours) }
    end.sort_by { |entry| -entry[:hours] }
  end

  # Total hours in the day view (6am to midnight)
  def total_day_hours
    END_HOUR - START_HOUR
  end


  def empty?
    time_blocks.empty?
  end

  def time_blocks_for_hour(hour)
    time_blocks.select { |b| b.start_hour.to_i == hour }
  end

  def section_for_hour(hour)
    TIME_SECTIONS[hour]
  end

  def sections_with_hours
    TIME_SECTIONS.map do |start_hour, section|
      next_section_hour = TIME_SECTIONS.keys.select { |h| h > start_hour }.min || END_HOUR
      {
        name: section[:name],
        bg: section[:bg],
        start_hour: start_hour,
        end_hour: next_section_hour,
        hours: (start_hour...next_section_hour).to_a
      }
    end
  end

  def section_background_for_hour(hour)
    TIME_SECTIONS.select { |h, _| h <= hour }.max_by { |h, _| h }&.last&.dig(:bg) || "bg-white"
  end

  def work_hour?(hour)
    return false unless work_hours_visible?
    hour >= user.work_start_hour && hour < user.work_end_hour
  end

  def first_work_hour?(hour)
    return false unless work_hours_visible?
    hour == user.work_start_hour.to_i
  end

  def work_block_hours
    return 0 unless work_hours_visible?
    user.work_end_hour - user.work_start_hour
  end

  def work_hours_visible?
    return @work_hours_visible if defined?(@work_hours_visible)
    @work_hours_visible = user.work_hours_enabled? && user.work_day?(date)
  end
end
