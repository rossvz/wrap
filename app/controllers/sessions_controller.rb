class SessionsController < ApplicationController
  allow_unauthenticated_access
  before_action :redirect_authenticated_user, only: [ :new, :create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Too many login attempts. Please try again later." }

  layout "public"

  def new
  end

  def create
    user = User.find_or_create_by!(email_address: params[:email_address])
    magic_link = user.send_magic_link
    set_pending_authentication_email(user.email_address)

    # In development, show the code in flash for easier testing
    if Rails.env.development?
      redirect_to session_magic_link_path, notice: "Check your email for the code. (Dev code: #{magic_link.code})"
    else
      redirect_to session_magic_link_path, notice: "Check your email for a sign-in code."
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path, notice: "You have been signed out."
  end

  private

  def redirect_authenticated_user
    redirect_to root_path if authenticated?
  end
end
