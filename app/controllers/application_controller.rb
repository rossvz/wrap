class ApplicationController < ActionController::Base
  include Authentication

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :set_time_zone
  after_action :reset_time_zone
  after_action :persist_time_zone_from_cookie

  helper_method :current_date

  private

  def current_date
    Time.zone.today
  end

  def set_time_zone
    @previous_time_zone = Time.zone
    zone_name = resolved_time_zone
    Time.zone = zone_name if zone_name
  end

  def reset_time_zone
    Time.zone = @previous_time_zone if defined?(@previous_time_zone)
  end

  def persist_time_zone_from_cookie
    zone_name = normalize_time_zone(cookies[:timezone])
    return unless zone_name && Current.session

    Current.session.update_column(:time_zone, zone_name) if Current.session.time_zone != zone_name

    user = Current.session.user
    user.update_column(:time_zone, zone_name) if user && user.time_zone != zone_name
  end

  def resolved_time_zone
    normalize_time_zone(cookies[:timezone]) || normalize_time_zone(Current.session&.time_zone)
  end

  def normalize_time_zone(zone)
    return if zone.blank?

    ActiveSupport::TimeZone[zone]&.name
  end
end
