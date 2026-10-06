class ApplicationMailer < ActionMailer::Base
  default from: -> { ENV.fetch("MAIL_FROM", "Tech Ecosystem <no-reply@localhost>") }
  layout false
end
