class ApplicationController < ActionController::Base
  include Authentication

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  around_action :use_time_zone

  private

  def use_time_zone(&block)
    time_zone = cookies[:timezone]
    if time_zone.present? && ActiveSupport::TimeZone[time_zone]
      Time.use_zone(time_zone, &block)
    else
      yield
    end
  end
end
