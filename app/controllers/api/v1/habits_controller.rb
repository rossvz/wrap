module Api
  module V1
    class HabitsController < BaseController
      def index
        habits = Current.user.habits.order(active: :desc, name: :asc)
        render json: habits.map { |h| habit_json(h) }
      end

      private

      def habit_json(habit)
        {
          id: habit.id,
          name: habit.name,
          description: habit.description,
          color_token: habit.color_token,
          active: habit.active
        }
      end
    end
  end
end
