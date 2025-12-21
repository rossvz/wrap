class Sessions::MagicLinksController < ApplicationController
  allow_unauthenticated_access
  before_action :ensure_pending_authentication_email
  rate_limit to: 10, within: 15.minutes, only: :create, with: -> { redirect_to session_magic_link_path, alert: "Too many attempts. Please try again in 15 minutes." }

  layout "public"

  def show
  end

  def create
    if magic_link = MagicLink.consume(params[:code])
      authenticate(magic_link)
    else
      redirect_to session_magic_link_path, alert: "Invalid or expired code. Please try again."
    end
  end

  private

  def ensure_pending_authentication_email
    unless pending_authentication_email.present?
      redirect_to new_session_path, alert: "Please enter your email address first."
    end
  end

  def authenticate(magic_link)
    if pending_authentication_email == magic_link.user.email_address
      sign_in(magic_link.user)
    else
      clear_pending_authentication_email
      redirect_to new_session_path, alert: "Something went wrong. Please try again."
    end
  end

  def sign_in(user)
    clear_pending_authentication_email
    start_new_session_for(user)
    redirect_to after_authentication_url, notice: "Welcome back!"
  end
end

