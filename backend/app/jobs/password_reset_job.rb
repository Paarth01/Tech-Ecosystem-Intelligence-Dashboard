# Looks the user up and sends the reset email in the background, so the "forgot password"
# request does the same work (and takes the same time) whether or not the address is registered.
class PasswordResetJob < ActiveJob::Base
  self.log_arguments = false   # the argument is an email address

  def perform(email)
    User.find_by(email: email)&.send_password_reset_email
  end
end
