module SettingsHelper
  def work_hour_options
    hour_options_for_select(6, 24, include_half: true)
  end

  def day_toggle_options
    %w[Sun Mon Tue Wed Thu Fri Sat].each_with_index.map { |name, i| [ name, i ] }
  end
end
