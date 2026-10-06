require "test_helper"

class UserMailerTest < ActionMailer::TestCase
  setup { @user = User.create!(name: "Ada", email: "ada@example.com", password: "password123") }

  test "password reset email" do
    mail = UserMailer.password_reset(@user.id, "tok123")
    assert_equal "Reset your password", mail.subject
    assert_equal ["ada@example.com"], mail.to
    assert_includes mail.body.to_s, "Hi Ada"
    assert_includes mail.body.to_s, "#{Rails.configuration.x.app_url}/reset-password?token=tok123"
  end

  test "verification email" do
    mail = UserMailer.email_verification(@user.id, "tok456")
    assert_equal "Confirm your email address", mail.subject
    assert_includes mail.body.to_s, "/verify-email?token=tok456"
    assert_includes mail.from.first, "no-reply"
  end
end
