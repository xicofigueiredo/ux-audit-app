class SettingsController < ApplicationController
  before_action :authenticate_user!

  def index
    @user = current_user
  end

  def update_knowledge_preference
    category = KnowledgeBaseCategory.find_by!(slug: params[:category_slug])
    enabled = ActiveModel::Type::Boolean.new.cast(params[:enabled])

    current_user.toggle_knowledge_category(params[:category_slug], enabled)

    respond_to do |format|
      format.json {
        render json: {
          success: true,
          message: "#{category.name} #{enabled ? 'enabled' : 'disabled'}"
        }
      }
      format.html {
        redirect_to settings_path,
        notice: "Knowledge base preferences updated"
      }
    end
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.json { render json: { success: false, error: "Category not found" }, status: :not_found }
      format.html { redirect_to settings_path, alert: "Category not found" }
    end
  rescue => e
    respond_to do |format|
      format.json { render json: { success: false, error: e.message }, status: :unprocessable_entity }
      format.html { redirect_to settings_path, alert: "Failed to update preferences" }
    end
  end

  def reset_knowledge_preferences
    current_user.user_knowledge_preferences.destroy_all
    current_user.send(:initialize_default_knowledge_preferences)

    redirect_to settings_path, notice: "Preferences reset to defaults"
  rescue => e
    redirect_to settings_path, alert: "Failed to reset preferences: #{e.message}"
  end
end
