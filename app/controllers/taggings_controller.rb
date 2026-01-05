class TaggingsController < ApplicationController
  before_action :set_habit

  def create
    tag = find_or_create_tag
    return render json: { error: "Invalid tag" }, status: :unprocessable_entity unless tag

    tagging = @habit.taggings.find_or_create_by(tag: tag)

    render json: { tag: { id: tag.id, name: tag.name } }, status: :created
  end

  def destroy
    tagging = @habit.taggings.find_by(tag_id: params[:id])
    tagging&.destroy

    head :no_content
  end

  private

  def set_habit
    @habit = current_user.habits.find(params[:habit_id])
  end

  def find_or_create_tag
    if params[:tag_id].present?
      current_user.tags.find_by(id: params[:tag_id])
    elsif params[:tag_name].present?
      name = params[:tag_name].to_s.strip.downcase
      return nil if name.blank? || name.length > 30

      current_user.tags.find_or_create_by(name: name)
    end
  end
end
