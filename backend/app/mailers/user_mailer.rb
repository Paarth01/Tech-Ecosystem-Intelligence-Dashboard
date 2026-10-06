class UserMailer < ApplicationMailer
  # Mailers receive plain values (an id and a token), never the user object.
  def password_reset(user_id, token)
    @user = User.find(user_id)
    @link = "#{Rails.configuration.x.app_url}/reset-password?token=#{token}"
    mail to: @user.email, subject: "Reset your password"
  end

  def email_verification(user_id, token)
    @user = User.find(user_id)
    @link = "#{Rails.configuration.x.app_url}/verify-email?token=#{token}"
    mail to: @user.email, subject: "Confirm your email address"
  end

  # Sent instead of a confirmation link when someone signs up with an address that already has an account.
  def account_exists(user_id)
    @user = User.find(user_id)
    @link = "#{Rails.configuration.x.app_url}/login"
    mail to: @user.email, subject: "You already have an account"
  end
end
