class HabitLogsController < ApplicationController
  before_action :set_habit
  before_action :set_habit_log, only: %i[update destroy]

  # GET /habits/:habit_id/logs
  def index
    @habit_logs = @habit.habit_logs.most_recent_first
    @habit_log = @habit.habit_logs.new(logged_on: Date.current)
  end

  # POST /habits/:habit_id/logs
  def create
    @habit_log = @habit.habit_logs.find_or_initialize_by(logged_on: habit_log_params[:logged_on] || Date.current)

    if @habit_log.update(habit_log_params)
      respond_to do |format|
        format.turbo_stream { render_update_streams(notice: "Logged.") }
        format.html { redirect_to habit_path(@habit), notice: "Logged." }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("habit_log_form", partial: "habit_logs/form", locals: { habit: @habit, habit_log: @habit_log }), status: :unprocessable_entity }
        format.html { redirect_to habit_path(@habit), alert: @habit_log.errors.full_messages.to_sentence }
      end
    end
  end

  # PATCH/PUT /habits/:habit_id/logs/:id
  def update
    if @habit_log.update(habit_log_params)
      respond_to do |format|
        format.turbo_stream { render_update_streams(notice: "Updated.") }
        format.html { redirect_to habit_path(@habit), notice: "Updated." }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace(helpers.dom_id(@habit_log), partial: "habit_logs/log", locals: { habit: @habit, habit_log: @habit_log }), status: :unprocessable_entity }
        format.html { redirect_to habit_path(@habit), alert: @habit_log.errors.full_messages.to_sentence }
      end
    end
  end

  # DELETE /habits/:habit_id/logs/:id
  def destroy
    @habit_log.destroy!

    respond_to do |format|
      format.turbo_stream { render_update_streams(notice: "Deleted.") }
      format.html { redirect_to habit_path(@habit), notice: "Deleted." }
    end
  end

  private
    def set_habit
      @habit = Habit.find(params.expect(:habit_id))
    end

    def set_habit_log
      @habit_log = @habit.habit_logs.find(params.expect(:id))
    end

    def habit_log_params
      params.expect(habit_log: %i[logged_on duration_minutes notes])
    end

    def render_update_streams(notice:)
      fresh_form_log = @habit.habit_logs.find_by(logged_on: Date.current) || @habit.habit_logs.new(logged_on: Date.current)

      render turbo_stream: [
        turbo_stream.replace("flash", partial: "shared/flash", locals: { notice: notice }),
        turbo_stream.replace("habit_log_form", partial: "habit_logs/form", locals: { habit: @habit, habit_log: fresh_form_log }),
        turbo_stream.replace("habit_logs", partial: "habit_logs/list", locals: { habit: @habit, habit_logs: @habit.habit_logs.most_recent_first.limit(30) })
      ]
    end
end
