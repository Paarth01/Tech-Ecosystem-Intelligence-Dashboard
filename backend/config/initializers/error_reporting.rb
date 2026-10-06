Rails.application.config.after_initialize do
  Rails.error.subscribe(ErrorWebhook.new) if ENV["ERROR_WEBHOOK_URL"].present?
end
