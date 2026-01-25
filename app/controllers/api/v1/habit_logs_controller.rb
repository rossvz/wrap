module Api
  module V1
    class HabitLogsController < BaseController
      before_action :set_habit

      def create
        log = @habit.habit_logs.build(habit_log_params)

        if log.save
          render json: habit_log_json(log), status: :created
        else
          render_validation_errors(log)
        end
      end

      private

      def set_habit
        @habit = Current.user.habits.find(params[:habit_id])
      end

      def habit_log_params
        params.permit(:logged_on, :start_hour, :end_hour, :notes)
      end

      def habit_log_json(log)
        {
          id: log.id,
          habit: { id: log.habit.id, name: log.habit.name },
          logged_on: log.logged_on.iso8601,
          start_hour: log.start_hour,
          end_hour: log.end_hour,
          duration_hours: log.end_hour - log.start_hour,
          notes: log.notes,
          created_at: log.created_at.iso8601
        }
      end
    end
  end
end
