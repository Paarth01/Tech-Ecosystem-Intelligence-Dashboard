module Api
  class SavedArticlesController < ApplicationController
    def index
      render json: current_user.saved_articles.order(created_at: :desc).map(&:as_item)
    end

    # Saving the same URL twice is harmless: the existing record is returned.
    def create
      raw = params[:article]
      unless raw.is_a?(ActionController::Parameters)
        return render json: { error: "Missing parameter: article" }, status: :bad_request
      end

      attrs = ArticleSanitizer.clean(
        raw.permit(:title, :url, :source, :description, :meta, :author, :date, tags: [])
      )
      article = current_user.saved_articles.find_or_initialize_by(url: attrs["url"])
      return render json: article.as_item if article.persisted?

      article.assign_attributes(attrs.except("url"))
      if article.save
        render json: article.as_item, status: :created
      else
        render_errors(article)
      end
    rescue ActiveRecord::RecordNotUnique
      # Another request saved the same URL a moment ago: saving twice is harmless, so return it.
      render json: current_user.saved_articles.find_by!(url: attrs["url"]).as_item
    end

    def destroy
      current_user.saved_articles.find(params[:id]).destroy
      head :no_content
    end
  end
end
