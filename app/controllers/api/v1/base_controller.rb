module Api
  module V1
    class BaseController < ActionController::API
      include ApiAuthentication

      rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

      private

      def render_not_found
        render json: { error: "Not found" }, status: :not_found
      end

      def render_validation_errors(record)
        render json: { errors: record.errors.as_json }, status: :unprocessable_entity
      end
    end
  end
end
