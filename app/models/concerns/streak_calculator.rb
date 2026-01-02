module StreakCalculator
  extend ActiveSupport::Concern

  def current_streak
    dates = logged_dates_set
    return 0 if dates.empty?

    start = dates.include?(Date.current) ? Date.current : Date.current - 1.day
    return 0 unless dates.include?(start)

    streak = 0
    current = start
    while dates.include?(current)
      streak += 1
      current -= 1.day
      break if streak > 365
    end
    streak
  end

  def longest_streak
    dates = logged_dates.to_a.sort
    return 0 if dates.empty?

    max_streak = 1
    current = 1

    dates.each_cons(2) do |prev, curr|
      if curr == prev + 1.day
        current += 1
        max_streak = [ max_streak, current ].max
      else
        current = 1
      end
    end

    max_streak
  end

  private

  def logged_dates_set
    @logged_dates_set ||= logged_dates.to_set
  end

  def logged_dates
    HabitLog.joins(:habit)
            .where(habits: { user_id: user.id })
            .where(logged_on: (Date.current - 365.days)..Date.current)
            .distinct
            .pluck(:logged_on)
  end
end
