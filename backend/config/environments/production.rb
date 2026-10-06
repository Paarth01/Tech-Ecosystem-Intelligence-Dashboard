Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true
  config.cache_store = :file_store, Rails.root.join("tmp/cache")
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")
  config.logger = ActiveSupport::TaggedLogging.logger($stdout)

  # Links in emails point at the public address of the app. Without it every reset link would
  # point at localhost, so the app refuses to start rather than send broken links.
  # (FORCE_SSL=false is the "try production mode on my own machine" switch and allows the default.)
  local_trial = ENV["FORCE_SSL"] == "false"
  config.x.app_url = ENV["APP_URL"].presence || (local_trial ? "http://localhost:3000" : raise("APP_URL is required in production, e.g. APP_URL=https://news.example.com"))

  # Password reset and verification emails need a mail server (SMTP_ADDRESS and friends). Without
  # one those emails would silently never arrive, so the app refuses to start unless you
  # explicitly accept that with ALLOW_NO_EMAIL=true.
  if ENV["SMTP_ADDRESS"].present?
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.smtp_settings = {
      address: ENV["SMTP_ADDRESS"], port: ENV.fetch("SMTP_PORT", "587").to_i,
      user_name: ENV["SMTP_USERNAME"], password: ENV["SMTP_PASSWORD"], enable_starttls_auto: true,
      open_timeout: 5, read_timeout: 10
    }
  elsif ENV["ALLOW_NO_EMAIL"] == "true" || local_trial
    config.action_mailer.perform_deliveries = false
    warn "SMTP_ADDRESS is not set: password reset and verification emails will not be delivered."
  else
    raise "SMTP_ADDRESS is required in production (or set ALLOW_NO_EMAIL=true to run without email)"
  end

  # Jobs (emails) run inside the web process. Failed emails are retried by MailDeliveryJob; anything
  # still waiting when the server restarts is lost, so restart gracefully. For stronger guarantees
  # move to a database-backed queue such as Solid Queue.
  config.active_job.queue_adapter = :async

  # Cookies are marked Secure and http is redirected to https. Set FORCE_SSL=false only
  # to try production mode on your own machine over plain http.
  config.force_ssl = ENV["FORCE_SSL"] != "false"
  config.assume_ssl = config.force_ssl
  # Rate limits use the visitor's IP address. Behind a CDN or load balancer, list its address ranges
  # (comma separated, e.g. TRUSTED_PROXIES=173.245.48.0/20,103.21.244.0/22) so Rails reads the real
  # visitor address from X-Forwarded-For instead of seeing every visitor as the proxy.
  if ENV["TRUSTED_PROXIES"].present?
    extra = ENV["TRUSTED_PROXIES"].split(",").map { |range| IPAddr.new(range.strip) }
    config.action_dispatch.trusted_proxies = ActionDispatch::RemoteIp::TRUSTED_PROXIES + extra
  end

  # The health check (/up) must answer over plain http and without a matching Host header.
  config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # Only answer requests for your own domain: APP_HOST (comma separated), or else the host of APP_URL.
  allowed_hosts = ENV["APP_HOST"].presence ? ENV["APP_HOST"].split(",").map(&:strip) : [URI(config.x.app_url).host]
  config.hosts = allowed_hosts unless local_trial
  config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
end
