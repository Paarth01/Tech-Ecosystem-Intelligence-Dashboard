Rails.application.configure do
  config.enable_reloading = true
  config.eager_load = false
  config.consider_all_requests_local = true
  config.cache_store = :file_store, Rails.root.join("tmp/cache")

  # Emails are written to backend/tmp/mails (and the log) instead of being sent.
  config.action_mailer.delivery_method = :file
  config.action_mailer.file_settings = { location: Rails.root.join("tmp/mails") }
  config.active_record.migration_error = :page_load
end
