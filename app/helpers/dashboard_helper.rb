module DashboardHelper
  def format_hour(hour)
    return nil unless hour
    h = hour.to_i
    period = h >= 12 ? "pm" : "am"
    display_hour = h == 0 ? 12 : (h > 12 ? h - 12 : h)
    display_hour = 12 if h == 12
    "#{display_hour}#{period}"
  end

  def format_hours(hours)
    hours = hours.to_f
    if hours == hours.to_i
      "#{hours.to_i}h"
    else
      "#{hours}h"
    end
  end
end
