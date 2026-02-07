class DashboardController < ApplicationController
  def index
    @date = parse_date_param
    @tag_filter = params[:tag]
    @day = DaySummary.new(current_user, @date, tag_filter: @tag_filter)
    @user_tags = current_user.tags.by_popularity.limit(10)
  end

  def clear_day
    date = parse_date_param
    current_user.clear_habit_logs_for_date(date)
    @day = DaySummary.new(current_user, date)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace("flash", partial: "shared/flash", locals: { notice: "Day cleared!" }),
          turbo_stream.replace("dashboard_header", partial: "dashboard/header", locals: { day: @day }),
          turbo_stream.replace("timeline", partial: "dashboard/timeline", locals: { day: @day })
        ]
      end
      format.html do
          redirect_params = date == current_date ? {} : { date: date.to_s }
          redirect_to dashboard_path(**redirect_params), notice: "Day cleared!"
        end
    end
  end

  private

  def parse_date_param
    if params[:date].present?
      Date.parse(params[:date])
    else
      current_date
    end
  rescue Date::Error
    current_date
  end
end
