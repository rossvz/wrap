class DashboardController < ApplicationController
  def index
    @date = Date.current

    @habits = Habit.where(active: true).order(created_at: :asc)

    logs = HabitLog.where(habit_id: @habits.select(:id))

    week_range = @date.beginning_of_week..@date.end_of_week
    month_range = @date.beginning_of_month..@date.end_of_month

    @totals = {
      today: logs.where(logged_on: @date).sum(:duration_minutes),
      week: logs.where(logged_on: week_range).sum(:duration_minutes),
      month: logs.where(logged_on: month_range).sum(:duration_minutes),
      all_time: logs.sum(:duration_minutes)
    }

    @minutes_by_habit = {
      today: logs.where(logged_on: @date).group(:habit_id).sum(:duration_minutes),
      week: logs.where(logged_on: week_range).group(:habit_id).sum(:duration_minutes),
      month: logs.where(logged_on: month_range).group(:habit_id).sum(:duration_minutes),
      all_time: logs.group(:habit_id).sum(:duration_minutes)
    }
  end
end
