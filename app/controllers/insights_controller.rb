class InsightsController < ApplicationController
  def show
    @week_start = week_start_param
    @week_end = @week_start.end_of_week(:monday)
    @date_range = @week_start..@week_end

    logs = current_user.habits.joins(:habit_logs)
                       .where(habit_logs: { logged_on: @date_range })

    @total_hours = logs.sum("habit_logs.end_hour - habit_logs.start_hour").round(1)

    @hours_by_day = HabitLog.joins(:habit)
                            .where(habits: { user_id: current_user.id })
                            .where(logged_on: @date_range)
                            .group(:logged_on)
                            .sum("end_hour - start_hour")
  end

  private

  def week_start_param
    if params[:week].present?
      Date.parse(params[:week]).beginning_of_week(:monday)
    else
      Date.current.beginning_of_week(:monday)
    end
  rescue Date::Error
    Date.current.beginning_of_week(:monday)
  end
end
