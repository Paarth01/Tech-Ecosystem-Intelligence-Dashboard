require "test_helper"

class AccountTest < ActionDispatch::IntegrationTest
  PASSWORD = "password123".freeze

  def register(client, name, email = "#{name.downcase}@example.com", extra = {})
    client.post "/api/auth/register", { name: name, email: email, password: PASSWORD }.merge(extra)
  end

  # ---- sign-up protection

  test "the sign-up form can ask whether an invite code is needed" do
    client = new_client
    with_env("SIGNUP_CODE" => nil) { client.get "/api/auth/options" }
    assert_equal false, client.json["invite_required"]
    with_env("SIGNUP_CODE" => "letmein") { client.get "/api/auth/options" }
    assert_equal true, client.json["invite_required"]
  end

  test "with SIGNUP_CODE set, registering needs the right invite code" do
    with_env("SIGNUP_CODE" => "letmein") do
      client = new_client
      register(client, "Ada")
      assert_equal 422, client.status
      register(client, "Ada", "ada@example.com", invite_code: "wrong")
      assert_equal 422, client.status
      assert_equal 0, User.count

      register(client, "Ada", "ada@example.com", invite_code: "letmein")
      assert_equal 201, client.status
    end
  end

  test "registrations are limited to 10 per hour per address" do
    10.times { |n| register(new_client, "User#{n}") ; }
    assert_equal 10, User.count
    blocked = new_client
    register(blocked, "Eleventh")
    assert_equal 429, blocked.status
    assert_equal 10, User.count
  end

  # ---- login lockout

  test "10 wrong passwords lock an email address, even for the right password; other emails are fine" do
    signed_in("Ada")
    signed_in("Bob")
    attacker = new_client
    10.times do
      attacker.post "/api/auth/login", { email: "ada@example.com", password: "wrong" }
      assert_equal 401, attacker.status
    end

    attacker.post "/api/auth/login", { email: "ada@example.com", password: PASSWORD }
    assert_equal 429, attacker.status
    assert attacker.header("Retry-After").to_i.positive?

    attacker.post "/api/auth/login", { email: "bob@example.com", password: PASSWORD }
    assert_equal 200, attacker.status
  end

  test "a successful login resets the failed-attempt count" do
    signed_in("Ada")
    client = new_client
    9.times { client.post "/api/auth/login", { email: "ada@example.com", password: "wrong" } }
    client.post "/api/auth/login", { email: "ada@example.com", password: PASSWORD }
    assert_equal 200, client.status
    9.times do
      client.post "/api/auth/login", { email: "ada@example.com", password: "wrong" }
      assert_equal 401, client.status
    end
  end

  test "30 failed logins from one address lock that address out" do
    signed_in("Ada")
    attacker = new_client
    30.times { |n| attacker.post "/api/auth/login", { email: "nobody#{n}@example.com", password: "x" } }
    attacker.post "/api/auth/login", { email: "ada@example.com", password: PASSWORD }
    assert_equal 429, attacker.status
  end

  # ---- password reset

  test "forgot password answers the same for unknown emails and sends nothing" do
    signed_in("Ada")
    clear_mails
    client = new_client

    client.post "/api/auth/forgot_password", { email: "nobody@example.com" }
    unknown = [client.status, client.json]
    assert_empty mails("Reset your password")

    client.post "/api/auth/forgot_password", { email: "ADA@example.com" }
    assert_equal unknown, [client.status, client.json]
    assert_equal 1, mails("Reset your password").size
    mail = mails("Reset your password").first
    assert_equal ["ada@example.com"], mail.to
    assert_includes mail.body.to_s, "#{Rails.configuration.x.app_url}/reset-password?token="
    assert_includes mail.body.to_s, "within the next hour"
  end

  test "at most 3 reset emails per address per hour, and 5 requests per IP" do
    signed_in("Ada")
    client = new_client
    4.times { client.post "/api/auth/forgot_password", { email: "ada@example.com" } }
    assert_equal 200, client.status
    assert_equal 3, mails("Reset your password").size

    client.post "/api/auth/forgot_password", { email: "other@example.com" }   # 5th request from this address
    client.post "/api/auth/forgot_password", { email: "other@example.com" }
    assert_equal 429, client.status
  end

  test "a reset link sets a new password once, signs out every device and expires" do
    laptop = signed_in("Ada")
    phone = new_client
    phone.post "/api/auth/login", { email: "ada@example.com", password: PASSWORD }
    new_client.post "/api/auth/forgot_password", { email: "ada@example.com" }
    token = token_from_mail("Reset your password")

    stranger = new_client
    stranger.post "/api/auth/reset_password", { token: "not-a-token", password: "newpassword1" }
    assert_equal 422, stranger.status
    stranger.post "/api/auth/reset_password", { token: token, password: "short" }
    assert_equal 422, stranger.status                              # weak password: the link still works

    stranger.post "/api/auth/reset_password", { token: token, password: "newpassword1" }
    assert_equal 200, stranger.status
    stranger.post "/api/auth/reset_password", { token: token, password: "anotherpass1" }
    assert_equal 422, stranger.status                              # single use

    [laptop, phone].each do |client|
      client.get "/api/me"
      assert_equal 401, client.status
    end
    fresh = new_client
    fresh.post "/api/auth/login", { email: "ada@example.com", password: PASSWORD }
    assert_equal 401, fresh.status
    fresh.post "/api/auth/login", { email: "ada@example.com", password: "newpassword1" }
    assert_equal 200, fresh.status
    assert_equal true, fresh.json.dig("user", "email_verified")    # the email proved they own the address
  end

  test "an expired reset link is refused" do
    signed_in("Ada")
    new_client.post "/api/auth/forgot_password", { email: "ada@example.com" }
    token = token_from_mail("Reset your password")
    EmailToken.update_all(expires_at: 1.minute.ago)

    client = new_client
    client.post "/api/auth/reset_password", { token: token, password: "newpassword1" }
    assert_equal 422, client.status
  end

  test "asking for a new reset link cancels the previous one" do
    signed_in("Ada")
    client = new_client
    client.post "/api/auth/forgot_password", { email: "ada@example.com" }
    first = token_from_mail("Reset your password")
    client.post "/api/auth/forgot_password", { email: "ada@example.com" }

    client.post "/api/auth/reset_password", { token: first, password: "newpassword1" }
    assert_equal 422, client.status
    client.post "/api/auth/reset_password", { token: token_from_mail("Reset your password"), password: "newpassword1" }
    assert_equal 200, client.status
  end

  test "tokens are stored only as hashes" do
    signed_in("Ada")
    new_client.post "/api/auth/forgot_password", { email: "ada@example.com" }
    raw = token_from_mail("Reset your password")
    stored = EmailToken.where(purpose: "password_reset").first.token_digest
    assert_not_equal raw, stored
    assert_equal EmailToken.digest(raw), stored
  end

  # ---- email verification

  test "registering sends a verification email, and the link confirms the address once" do
    ada = signed_in("Ada")
    assert_equal 1, mails("Confirm your email address").size
    assert_equal ["ada@example.com"], mails("Confirm your email address").first.to

    ada.get "/api/me"
    assert_equal false, ada.json.dig("user", "email_verified")

    token = token_from_mail("Confirm your email address")
    anon = new_client
    anon.post "/api/auth/verify_email", { token: token }
    assert_equal 200, anon.status
    ada.get "/api/me"
    assert_equal true, ada.json.dig("user", "email_verified")

    anon.post "/api/auth/verify_email", { token: token }
    assert_equal 422, anon.status
    anon.post "/api/auth/verify_email", { token: "nope" }
    assert_equal 422, anon.status
  end

  test "resending the verification email is limited to 3 per hour and skipped once verified" do
    ada = signed_in("Ada")
    clear_mails
    3.times { ada.post "/api/me/verification" }
    assert_equal 200, ada.status
    assert_equal 3, mails("Confirm your email address").size
    ada.post "/api/me/verification"
    assert_equal 429, ada.status

    bob = signed_in("Bob")
    new_client.post "/api/auth/verify_email", { token: token_from_mail("Confirm your email address") }
    clear_mails
    bob.post "/api/me/verification"
    assert_equal 200, bob.status
    assert_empty mails
  end

  # ---- deleting an account

  test "deleting an account needs the password and removes only that user's data" do
    ada = signed_in("Ada")
    bob = signed_in("Bob")
    ada.post "/api/saved_articles", { article: article(1) }
    ada.post "/api/comparisons", { items: [article(1), article(2)], result: "| a |" }
    bob.post "/api/saved_articles", { article: article(3) }

    ada.delete "/api/me", { current_password: "wrong" }
    assert_equal 422, ada.status
    assert_equal 2, User.count

    ada.delete "/api/me", { current_password: PASSWORD }
    assert_equal 204, ada.status
    ada.get "/api/me"
    assert_equal 401, ada.status

    assert_equal ["bob@example.com"], User.pluck(:email)
    assert_equal [3], SavedArticle.pluck(:url).map { |u| u[/\d+\z/].to_i }
    assert_equal 0, Comparison.count
    assert_equal 0, EmailToken.where(user_id: nil).count
    login = new_client
    login.post "/api/auth/login", { email: "ada@example.com", password: PASSWORD }
    assert_equal 401, login.status
  end

  test "password checks on a signed-in session are limited" do
    ada = signed_in("Ada")
    10.times { ada.delete "/api/me", { current_password: "wrong" } }
    assert_equal 422, ada.status
    ada.delete "/api/me", { current_password: PASSWORD }
    assert_equal 429, ada.status
    assert_equal 1, User.count
  end

  # ---- AI cost controls

  def generate_with_fake_gemini(client, calls)
    reply = { "candidates" => [{ "content" => { "parts" => [{ "text" => "| A | B |\n|---|---|\n| 1 | 2 |" }] } }] }
    stub_singleton(HttpClient, :post_json, ->(*_a, **_k) { calls << 1; reply }) do
      client.post "/api/comparisons/generate", { items: [article(1), article(2)] }
    end
  end

  test "with REQUIRE_VERIFIED_EMAIL, only verified users get AI comparisons" do
    ada = signed_in("Ada")
    calls = []
    with_env("GEMINI_API_KEY" => "k", "REQUIRE_VERIFIED_EMAIL" => "true") do
      generate_with_fake_gemini(ada, calls)
      assert_equal false, ada.json["ai"]
      assert_includes ada.json["note"], "Confirm your email"
      assert_empty calls

      new_client.post "/api/auth/verify_email", { token: token_from_mail("Confirm your email address") }
      generate_with_fake_gemini(ada, calls)
      assert_equal true, ada.json["ai"]
      assert_equal 1, calls.size
    end
  end

  test "a daily limit for the whole app stops AI calls" do
    ada = signed_in("Ada")
    bob = signed_in("Bob")
    calls = []
    with_env("GEMINI_API_KEY" => "k", "GEMINI_DAILY_LIMIT" => "2", "REQUIRE_VERIFIED_EMAIL" => nil) do
      generate_with_fake_gemini(ada, calls)
      generate_with_fake_gemini(bob, calls)
      assert_equal 2, calls.size

      generate_with_fake_gemini(ada, calls)                 # the limit is shared by everyone
      assert_equal false, ada.json["ai"]
      assert_includes ada.json["note"], "daily limit"
      assert_equal 2, calls.size
    end
  end
end
