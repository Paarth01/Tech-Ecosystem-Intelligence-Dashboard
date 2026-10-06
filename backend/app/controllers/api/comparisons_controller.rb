module Api
  class ComparisonsController < ApplicationController
    # Each generate may call a paid AI API, so it is limited per user.
    before_action(only: :generate) { throttle!("generate", limit: 10, within: 1.hour) }

    def index
      # The saved text (up to 20 KB each) isn't needed for the list, so it isn't loaded.
      render json: current_user.comparisons.select(:id, :title, :ai_generated, :created_at, :items)
                               .order(created_at: :desc).map(&:summary_json)
    end

    def show
      render json: current_user.comparisons.find(params[:id]).full_json
    end

    # Builds a comparison without saving it, so the user can review it first.
    def generate
      items = item_params
      return render_item_count_error unless items.size.between?(2, 4)
      render json: ComparisonGenerator.call(items, ai: ai_allowed?)
    end

    def create
      items = item_params
      comparison = current_user.comparisons.new(
        items: items,
        result: params[:result].to_s,
        ai_generated: params[:ai_generated] == true,
        title: params[:title].to_s.first(300).presence || items.map { |i| i["title"].to_s.first(30) }.join(" vs ")
      )
      if comparison.save
        render json: comparison.full_json, status: :created
      else
        render_errors(comparison)
      end
    end

    def destroy
      current_user.comparisons.find(params[:id]).destroy
      head :no_content
    end

    private

    # At most 5 are read, so an oversized list is rejected instead of processed.
    def item_params
      permitted = params.permit(items: [:title, :url, :source, :description, :meta, :author, :date, { tags: [] }])
      Array(permitted[:items]).first(5).map { |raw| ArticleSanitizer.clean(raw) }
                             .select { |item| ArticleSanitizer.safe_url?(item["url"]) && item["title"].present? }
    end

    # AI comparisons cost money, so in production they are only for users who confirmed their email.
    # Set REQUIRE_VERIFIED_EMAIL=false to allow everyone (or =true to require it in other environments).
    def ai_allowed?
      default = Rails.env.production? ? "true" : "false"
      ENV.fetch("REQUIRE_VERIFIED_EMAIL", default) != "true" || current_user.email_verified?
    end

    def render_item_count_error
      render json: { error: "Choose 2 to 4 articles to compare" }, status: :unprocessable_entity
    end
  end
end
