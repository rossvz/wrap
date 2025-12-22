class HabitLogsController < ApplicationController
  before_action :set_habit, only: %i[index edit update destroy]
  before_action :set_habit_log, only: %i[edit update destroy]

  # GET /habits/:habit_id/logs
  def index
    @habit_logs = @habit.habit_logs.most_recent_first
    @habit_log = @habit.habit_logs.new(logged_on: Date.current, start_hour: 9, end_hour: 10)
  end

  # GET /habits/:habit_id/logs/:id/edit
  def edit
    @habits = current_user.habits.where(active: true).order(:name)
  end

  # POST /habit_logs (standalone route for timeline)
  # POST /habits/:habit_id/logs (nested route)
  def create
    habit = find_or_create_habit

    unless habit
      redirect_to dashboard_path, alert: "Could not find or create habit."
      return
    end

    @habit_log = habit.habit_logs.new(habit_log_params)

    if @habit_log.save
      respond_to do |format|
        format.turbo_stream { render_dashboard_update(notice: "Time block logged.") }
        format.html { redirect_to dashboard_path, notice: "Time block logged." }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("flash", partial: "shared/flash", locals: { alert: @habit_log.errors.full_messages.to_sentence }), status: :unprocessable_entity }
        format.html { redirect_to dashboard_path, alert: @habit_log.errors.full_messages.to_sentence }
      end
    end
  end

  # PATCH/PUT /habits/:habit_id/logs/:id
  def update
    # Handle habit reassignment if habit_id changed
    new_habit_id = params.dig(:habit_log, :habit_id)
    if new_habit_id.present? && new_habit_id.to_s != @habit_log.habit_id.to_s
      new_habit = current_user.habits.find_by(id: new_habit_id)
      @habit_log.habit = new_habit if new_habit
    end

    if @habit_log.update(habit_log_params)
      respond_to do |format|
        format.turbo_stream { render_after_edit }
        format.html { redirect_to redirect_destination, notice: "Updated." }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          @habits = current_user.habits.where(active: true).order(:name)
          render turbo_stream: turbo_stream.replace("edit_modal", partial: "habit_logs/edit_form", locals: { habit: @habit, habit_log: @habit_log, habits: @habits })
        end
        format.html { redirect_to redirect_destination, alert: @habit_log.errors.full_messages.to_sentence }
      end
    end
  end

  # DELETE /habits/:habit_id/logs/:id
  def destroy
    @habit_log.destroy!

    respond_to do |format|
      format.turbo_stream { render_after_edit(notice: "Time block deleted.") }
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

  def find_or_create_habit
    # If habit_id is provided directly in params (from nested route or form)
    if params[:habit_id].present?
      return current_user.habits.find_by(id: params[:habit_id])
    end

    # If habit_id is in habit_log params
    if params[:habit_log][:habit_id].present?
      return current_user.habits.find_by(id: params[:habit_log][:habit_id])
    end

    # If new_habit_name is provided, create a new habit
    if params[:habit_log][:new_habit_name].present?
      name = params[:habit_log][:new_habit_name].strip
      return current_user.habits.create(name: name)
    end

    nil
  end

  def render_after_edit(notice: "Updated.")
    day = DaySummary.new(current_user, Date.current)

    render turbo_stream: [
      turbo_stream.replace("flash", partial: "shared/flash", locals: { notice: notice }),
      turbo_stream.replace("timeline", partial: "dashboard/timeline", locals: { day: day }),
      turbo_stream.replace("edit_modal", "<turbo-frame id=\"edit_modal\"></turbo-frame>")
    ]
  end

  def redirect_destination
    if request.referer&.include?("/dashboard") || request.referer == root_url
      dashboard_path
    else
      habit_path(@habit)
    end
  end

  def render_update_streams(notice:)
    fresh_form_log = @habit.habit_logs.find_by(logged_on: Date.current) || @habit.habit_logs.new(logged_on: Date.current, start_hour: 9, end_hour: 10)

    render turbo_stream: [
      turbo_stream.replace("flash", partial: "shared/flash", locals: { notice: notice }),
      turbo_stream.replace("habit_log_form", partial: "habit_logs/form", locals: { habit: @habit, habit_log: fresh_form_log }),
      turbo_stream.replace("habit_logs", partial: "habit_logs/list", locals: { habit: @habit, habit_logs: @habit.habit_logs.most_recent_first.limit(30) })
    ]
  end
end
