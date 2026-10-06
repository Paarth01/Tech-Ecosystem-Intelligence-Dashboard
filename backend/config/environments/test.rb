Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = false
  config.consider_all_requests_local = true
  config.action_mailer.delivery_method = :test
  config.active_job.queue_adapter = :inline   # send mail immediately so tests can read it
  config.cache_store = :memory_store   # rate limiting needs a working cache; tests clear it between runs
  config.action_dispatch.show_exceptions = :rescuable
end
