class DashboardController < ApplicationController
  def index
    @day = DaySummary.new(current_user)
  end

  def clear_day
    HabitLog.joins(:habit).where(habits: { user_id: current_user.id }, logged_on: Date.current).destroy_all
    @day = DaySummary.new(current_user)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace("flash", partial: "shared/flash", locals: { notice: "Day cleared!" }),
          turbo_stream.replace("dashboard_header", partial: "dashboard/header", locals: { day: @day }),
          turbo_stream.replace("timeline", partial: "dashboard/timeline", locals: { day: @day })
        ]
      end
      format.html { redirect_to dashboard_path, notice: "Day cleared!" }
    end
  end
end
