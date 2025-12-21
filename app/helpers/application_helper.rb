module ApplicationHelper
  def format_duration(minutes)
    minutes = minutes.to_i
    hours = minutes / 60
    mins = minutes % 60

    if hours.positive?
      "#{hours}h #{mins}m"
    else
      "#{mins}m"
    end
  end
end
