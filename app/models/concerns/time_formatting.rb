module TimeFormatting
  extend ActiveSupport::Concern

  def format_hour(hour)
    return nil unless hour
    h = hour.to_i
    m = ((hour % 1) * 60).to_i
    period = h >= 12 ? "pm" : "am"
    display_hour = case h
    when 0 then 12
    when 1..12 then h
    else h - 12
    end
    m.zero? ? "#{display_hour}#{period}" : "#{display_hour}:#{m.to_s.rjust(2, '0')}#{period}"
  end
end
