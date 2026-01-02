class SettingsController < ApplicationController
  def show
  end

  def update
    if current_user.update(settings_params)
      redirect_to settings_path, notice: "Settings updated successfully."
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def settings_params
    params.expect(user: [ :theme, notification_hours: [] ])
  end
end
