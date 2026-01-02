json.period_type @period_type
json.period_label @summary.period_label

json.date_range do
  json.start @summary.date_range.begin
  json.end @summary.date_range.end
end

json.stats do
  json.total_hours @summary.total_hours
  json.daily_average @summary.daily_average
  json.active_days_count @summary.active_days_count
  json.current_streak @summary.current_streak
  json.longest_streak @summary.longest_streak
end

json.hours_by_habit @summary.hours_by_habit
json.chart_data @summary.chart_data
json.doughnut_chart_data @summary.doughnut_chart_data

json._links do
  json.previous insights_url(period: @period_type, date: @summary.previous_period_date, format: :json)
  if @summary.can_navigate_next?
    json.next insights_url(period: @period_type, date: @summary.next_period_date, format: :json)
  end
end
