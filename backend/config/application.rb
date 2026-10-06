require_relative "boot"

require "rails"
require "active_record/railtie"
require "action_controller/railtie"
require "action_mailer/railtie"
require "active_job/railtie"

Bundler.require(*Rails.groups)

require_relative "../lib/middleware/request_size_limit"

module TechIntel
  class Application < Rails::Application
    config.load_defaults 8.1
    config.api_only = true

    # Refuse oversized request bodies before anything parses them.
    config.middleware.insert_before 0, RequestSizeLimit

    # The login cookie is the only cookie the app uses.
    config.middleware.use ActionDispatch::Cookies

    # Where links in emails point (the address of the React app).
    config.x.app_url = ENV.fetch("APP_URL", "http://localhost:5173")

    # In production the built React app (backend/public) is served by Rails itself.
    config.public_file_server.enabled = true
  end
end
