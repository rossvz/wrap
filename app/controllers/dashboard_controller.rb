class DashboardController < ApplicationController
  def index
    @day = DaySummary.new(current_user)
  end

  def clear_day
    current_user.clear_habit_logs_for_date(Date.current)
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
