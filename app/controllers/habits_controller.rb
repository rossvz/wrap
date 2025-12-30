class HabitsController < ApplicationController
  before_action :set_habit, only: %i[ show edit update destroy ]

  # GET /habits or /habits.json
  def index
    @habits = current_user.habits.order(active: :desc, created_at: :asc)
  end

  # GET /habits/1 or /habits/1.json
  def show
    @today_log = @habit.habit_logs.find_by(logged_on: current_date) ||
                 @habit.habit_logs.new(logged_on: current_date, start_hour: 9, end_hour: 10)
    @recent_logs = @habit.habit_logs.most_recent_first.limit(30)
  end

  # GET /habits/new
  def new
    @habit = current_user.habits.new
  end

  # GET /habits/1/edit
  def edit
  end

  # POST /habits or /habits.json
  def create
    @habit = current_user.habits.new(habit_params)

    respond_to do |format|
      if @habit.save
        format.html { redirect_to @habit, notice: "Habit was successfully created." }
        format.json { render :show, status: :created, location: @habit }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @habit.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /habits/1 or /habits/1.json
  def update
    respond_to do |format|
      if @habit.update(habit_params)
        format.html { redirect_to @habit, notice: "Habit was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @habit }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @habit.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /habits/1 or /habits/1.json
  def destroy
    @habit.destroy!

    respond_to do |format|
      format.html { redirect_to habits_path, notice: "Habit was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_habit
      @habit = current_user.habits.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def habit_params
      params.expect(habit: [ :name, :description, :color_token, :active ])
    end
end
