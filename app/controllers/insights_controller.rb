class InsightsController < ApplicationController
  ALLOWED_PERIODS = %w[week month year].freeze

  def show
    @period_type = validated_period_type
    @summary = build_summary

    respond_to do |format|
      format.html
      format.json
    end
  end

  private

  def validated_period_type
    ALLOWED_PERIODS.include?(params[:period]) ? params[:period] : "week"
  end

  def parsed_date
    Date.parse(params[:date])
  rescue ArgumentError, TypeError
    nil
  end

  def build_summary
    case @period_type
    when "week" then WeekSummary.new(current_user, parsed_date)
    when "month" then MonthSummary.new(current_user, parsed_date)
    when "year" then YearSummary.new(current_user, parsed_date)
    end
  end
end
