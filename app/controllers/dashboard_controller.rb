class DashboardController < ApplicationController
  def index
    @day = DaySummary.new(current_user)
  end
end
