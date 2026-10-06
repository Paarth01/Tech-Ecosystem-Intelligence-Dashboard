# Every email goes through MailDeliveryJob: failed deliveries are retried and job arguments
# (which include password-reset tokens) are kept out of the logs.
Rails.application.config.to_prepare do
  ActionMailer::Base.delivery_job = MailDeliveryJob
end
