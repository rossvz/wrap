class ApiTokensController < ApplicationController
  def index
    @api_tokens = current_user.api_tokens.order(created_at: :desc)
  end

  def create
    @api_token = current_user.api_tokens.create!(name: params[:name])
    @show_token = @api_token.token

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to api_tokens_path, notice: "Token created" }
    end
  end

  def destroy
    token = current_user.api_tokens.find(params[:id])
    token.destroy

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove(token) }
      format.html { redirect_to api_tokens_path, notice: "Token revoked" }
    end
  end
end
