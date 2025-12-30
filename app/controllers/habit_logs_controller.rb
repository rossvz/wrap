class HabitLogsController < ApplicationController
  before_action :set_habit, only: %i[index edit update destroy]
  before_action :set_habit_log, only: %i[edit update destroy]

  # GET /habits/:habit_id/logs
  def index
    @habit_logs = @habit.habit_logs.most_recent_first
    @habit_log = @habit.habit_logs.new(logged_on: current_date, start_hour: 9, end_hour: 10)
  end

  # GET /habits/:habit_id/logs/:id/edit
  def edit
    @habits = current_user.habits.where(active: true).order(:name)
  end

  # POST /habit_logs (standalone route for timeline)
  # POST /habits/:habit_id/logs (nested route)
  def create
    habit = Habit.find_or_create_for_user(
      current_user,
      habit_id: params[:habit_id] || params.dig(:habit_log, :habit_id),
      new_habit_name: params.dig(:habit_log, :new_habit_name)
    )

    unless habit
      redirect_to dashboard_path, alert: "Could not find or create habit."
      return
    end

    @habit_log = habit.habit_logs.create!(habit_log_params)
    @day = DaySummary.new(current_user, current_date)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to dashboard_path, notice: "Time block logged." }
    end
  end

  # PATCH/PUT /habits/:habit_id/logs/:id
  def update
    new_habit_id = params.dig(:habit_log, :habit_id)
    if new_habit_id.present? && new_habit_id.to_s != @habit_log.habit_id.to_s
      new_habit = current_user.habits.find_by(id: new_habit_id)
      @habit_log.habit = new_habit if new_habit
    end

     @habit_log.update!(habit_log_params)

     @day = DaySummary.new(current_user, current_date)

     respond_to do |format|
        format.turbo_stream
        format.html { redirect_to redirect_destination, notice: "Updated." }
      end
  end

  # DELETE /habits/:habit_id/logs/:id
  def destroy
    @habit_log.destroy!
    @day = DaySummary.new(current_user, current_date)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to redirect_destination, notice: "Time block deleted." }
    end
  end

  private

  def set_habit
    @habit = current_user.habits.find(params.expect(:habit_id))
  end

  def set_habit_log
    @habit_log = @habit.habit_logs.find(params.expect(:id))
  end

  def habit_log_params
    params.expect(habit_log: %i[logged_on start_hour end_hour notes habit_id])
  end

  def redirect_destination
    if request.referer&.include?("/dashboard") || request.referer == root_url
      dashboard_path
    else
      habit_path(@habit)
    end
  end
end
