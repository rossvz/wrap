class DashboardController < ApplicationController
  def index
    @tag_filter = params[:tag]
    @day = DaySummary.new(current_user, current_date, tag_filter: @tag_filter)
    @user_tags = current_user.tags.by_popularity.limit(10)
  end

  def clear_day
    current_user.clear_habit_logs_for_date(current_date)
    @day = DaySummary.new(current_user, current_date)

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
