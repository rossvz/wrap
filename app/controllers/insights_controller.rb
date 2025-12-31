class InsightsController < ApplicationController
  def show
    @week = WeekSummary.new(current_user, parsed_week_param)
  end

  private

  def parsed_week_param
    Date.parse(params[:week]) if params[:week].present?
  rescue Date::Error
    nil
  end
end
