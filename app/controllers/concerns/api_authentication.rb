module ApiAuthentication
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_api_token!
  end

  private

  def authenticate_api_token!
    token = extract_bearer_token
    return render_unauthorized unless token

    api_token = ApiToken.find_by(token: token)
    return render_unauthorized unless api_token

    api_token.touch_usage!(request.remote_ip)
    Current.user = api_token.user
  end

  def extract_bearer_token
    auth_header = request.headers["Authorization"]
    return nil unless auth_header&.start_with?("Bearer ")
    auth_header.split(" ").last
  end

  def render_unauthorized
    render json: { error: "Unauthorized" }, status: :unauthorized
  end
end
