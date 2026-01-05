class TagsController < ApplicationController
  def index
    @tags = current_user.tags.alphabetically
  end

  def create
    @tag = current_user.tags.find_or_create_by(name: tag_params[:name])

    respond_to do |format|
      if @tag.persisted?
        format.json { render json: { id: @tag.id, name: @tag.name }, status: :created }
      else
        format.json { render json: @tag.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @tag = current_user.tags.find(params[:id])
    @tag.destroy

    respond_to do |format|
      format.json { head :no_content }
    end
  end

  private

  def tag_params
    params.expect(tag: [ :name ])
  end
end
