module Api
  class DashboardController < ApplicationController
    # Refreshing skips the one-hour cache and costs outbound requests, so it is a POST (a link on
    # another site can't trigger it) and it is limited.
    before_action(only: :refresh) { throttle!("refresh", limit: 3, within: 10.minutes) }

    def show
      render json: TrendFetcher.dashboard
    end

    def refresh
      render json: TrendFetcher.dashboard(force: true)
    end
  end
end
