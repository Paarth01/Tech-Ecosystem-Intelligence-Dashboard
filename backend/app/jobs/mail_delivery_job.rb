require "net/smtp"

# Used for every email (see config/initializers/mail_delivery.rb). Two differences from the default:
#  - delivery is retried when the failure is temporary (network trouble, a busy mail server);
#    permanent failures (a rejected address, a broken template) are not retried;
#  - job arguments are kept out of the logs, because they include password-reset tokens.
class MailDeliveryJob < ActionMailer::MailDeliveryJob
  self.log_arguments = false

  TEMPORARY_ERRORS = [Timeout::Error, SystemCallError, SocketError, IOError,
                      Net::SMTPServerBusy, Net::SMTPUnknownError].freeze

  retry_on(*TEMPORARY_ERRORS, wait: :polynomially_longer, attempts: 5)
  discard_on ActiveRecord::RecordNotFound   # the account was deleted before the email went out
end
