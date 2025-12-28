module DashboardHelper
  def time_block_height(block, pixels_per_hour: 60)
    (block.duration_hours * pixels_per_hour).to_i
  end

  def hour_options_for_select(start_hour, end_hour, include_half: false)
    options = []
    (start_hour..end_hour).each do |h|
      label = h == 24 ? "12am" : format_hour(h)
      options << [ label, h.to_f ]
      if include_half && h < end_hour
        options << [ "#{format_hour(h)}:30", h + 0.5 ]
      end
    end
    options
  end
end
