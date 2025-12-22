class DashboardController < ApplicationController
  def index
    @date = Date.current
    @habits = current_user.habits.where(active: true).order(created_at: :asc)

    # Load all time blocks for today
    @time_blocks = HabitLog.includes(:habit)
                          .where(logged_on: @date)
                          .where(habit_id: @habits.select(:id))
                          .order(:start_hour)

    # Calculate total hours logged today
    @total_hours = @time_blocks.sum(&:duration_hours).round(1)

    # Aggregate hours by habit for the activity visualization
    # Returns array of { habit: Habit, hours: Float } sorted by most hours
    @activity_breakdown = @time_blocks.group_by(&:habit).map do |habit, logs|
      { habit: habit, hours: logs.sum(&:duration_hours) }
    end.sort_by { |entry| -entry[:hours] }

    # Total available hours in the day view (6am to midnight = 18 hours)
    @total_day_hours = 18.0
  end
end
