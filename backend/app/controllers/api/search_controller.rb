module Api
  class SearchController < ApplicationController
    before_action { throttle!("search", limit: 30, within: 1.hour) }

    def show
      q = params[:q].to_s.squish
      return render json: { error: "Enter at least 2 characters" }, status: :bad_request if q.length < 2
      render json: IdeaSearcher.call(q.first(100))
    end
  end
end
