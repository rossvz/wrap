class DashboardController < ApplicationController
  def index
    @date = Date.current
    @habits = Habit.where(active: true).order(created_at: :asc)

    # Load all time blocks for today
    @time_blocks = HabitLog.includes(:habit)
                          .where(logged_on: @date)
                          .where(habit_id: @habits.select(:id))
                          .order(:start_hour)

    # Calculate total hours logged today
    @total_hours = @time_blocks.sum(&:duration_hours).round(1)

    # Calculate totals for stats
    week_range = @date.beginning_of_week..@date.end_of_week
    all_logs = HabitLog.where(habit_id: @habits.select(:id))

    @totals = {
      today: @total_hours,
      week: calculate_total_hours(all_logs.where(logged_on: week_range)),
      all_time: calculate_total_hours(all_logs)
    }
  end

  private

  def calculate_total_hours(logs)
    # Sum duration for each log (end_hour - start_hour)
    logs.sum("end_hour - start_hour").to_f.round(1)
  end
end
