require "test_helper"

# Regression tests for the fixes that followed the security audit.
class HardeningTest < ActionDispatch::IntegrationTest
  PASSWORD = "password123"

  # ---- logs (S-01)
  test "tokens, the invite code and emails are filtered from logs" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    filtered = filter.filter("token" => "abc", "invite_code" => "letmein", "email" => "a@b.c", "password" => "x", "name" => "Ada")
    assert_equal "[FILTERED]", filtered["token"]
    assert_equal "[FILTERED]", filtered["invite_code"]
    assert_equal "[FILTERED]", filtered["email"]
    assert_equal "[FILTERED]", filtered["password"]
    assert_equal "Ada", filtered["name"]
  end

  # ---- lockout (S-02)
  test "a stranger guessing from another address cannot lock the owner out" do
    signed_in("Ada")
    attacker = new_client
    10.times { attacker.post "/api/auth/login", { email: "ada@example.com", password: "wrong" } }
    attacker.post "/api/auth/login", { email: "ada@example.com", password: PASSWORD }
    assert_equal 429, attacker.status                      # this address is locked out of Ada's account

    owner = new_client
    owner.post "/api/auth/login", { email: "ada@example.com", password: PASSWORD },
               env: { "REMOTE_ADDR" => "203.0.113.9" }  # Ada, from a different address
    assert_equal 200, owner.status
  end

  test "guessing spread over many addresses is still stopped by the per-email limit" do
    signed_in("Ada")
    40.times do |n|
      new_client.post "/api/auth/login", { email: "ada@example.com", password: "wrong" },
                      env: { "REMOTE_ADDR" => "198.51.100.#{n + 1}" }
    end
    owner = new_client
    owner.post "/api/auth/login", { email: "ada@example.com", password: PASSWORD }, env: { "REMOTE_ADDR" => "203.0.113.50" }
    assert_equal 429, owner.status
  end

  # ---- forgot password (S-06)
  test "the reset email is sent by a background job, for registered addresses only" do
    signed_in("Ada")
    clear_mails
    assert_nothing_raised { PasswordResetJob.perform_now("nobody@example.com") }
    assert_empty mails("Reset your password")
    PasswordResetJob.perform_now("ada@example.com")
    assert_equal 1, mails("Reset your password").size
  end

  # ---- names and emails (S-09)
  test "control characters are stripped from names and very long emails are rejected" do
    client = new_client
    client.post "/api/auth/register", { name: "Ada\r\nClick here: http://evil.example", email: "ada@example.com", password: PASSWORD }
    assert_equal 201, client.status
    assert_no_match(/[\r\n]/, User.last.name)

    long = new_client
    long.post "/api/auth/register", { name: "Bob", email: "#{'a' * 250}@example.com", password: PASSWORD }
    assert_equal 422, long.status
  end

  # ---- session cookie (S-10)
  test "the cookie is re-issued when the session slides forward" do
    ada = signed_in("Ada")
    Session.update_all(last_used_at: 2.days.ago)
    ada.get "/api/me"
    assert_equal 200, ada.status
    assert_match(/techintel_session=/, ada.set_cookie)
    assert_match(/expires=/i, ada.set_cookie)

    ada.get "/api/me"                                      # used again straight away: nothing to renew
    assert_no_match(/techintel_session=/, ada.set_cookie)
  end

  # ---- wrong-type and racing requests (B-02, B-03)
  test "a saved article sent as plain text is a 400, not a crash" do
    ada = signed_in("Ada")
    ada.post "/api/saved_articles", { article: "just text" }
    assert_equal 400, ada.status
  end

  test "saving the same URL twice at the same moment returns the saved article" do
    ada = signed_in("Ada")
    user = User.first
    original = SavedArticle.instance_method(:save)
    # Simulate losing the race: a competing request inserts the row just before this one saves.
    SavedArticle.define_method(:save) do |*_args, **_opts|
      now = Time.current
      SavedArticle.insert_all([{ user_id: user_id, title: title, url: url, created_at: now, updated_at: now }])
      raise ActiveRecord::RecordNotUnique, "race"
    end
    begin
      ada.post "/api/saved_articles", { article: article(1) }
    ensure
      SavedArticle.define_method(:save, original)
    end
    assert_equal 200, ada.status
    assert_equal "Article 1", ada.json["title"]
    assert_equal 1, SavedArticle.where(user: user).count
  end

  test "a name that is not text is rejected instead of crashing" do
    ada = signed_in("Ada")
    ada.patch "/api/me", { name: { a: 1 } }
    assert_equal 422, ada.status
  end

  # ---- refresh must not be a GET (S-13)
  test "the dashboard refresh is a POST and a plain GET never skips the cache" do
    ada = signed_in("Ada")
    seen = []
    stub_singleton(TrendFetcher, :dashboard, ->(force: false) { seen << force; { feeds: {}, topics: [] } }) do
      ada.get "/api/dashboard", { refresh: "1" }
      ada.post "/api/dashboard/refresh"
    end
    assert_equal [false, true], seen
  end

  # ---- request size (S-04) and health check (R-06)
  test "oversized request bodies are refused before they are parsed" do
    client = new_client
    client.post "/api/auth/login", { email: "a@b.co", password: "x" * 300_000 }
    assert_equal 413, client.status
  end

  test "the health check answers without signing in" do
    get "/up"
    assert_response :success
  end

  # ---- comparison list (B-07)
  test "the comparison list does not carry the saved text" do
    ada = signed_in("Ada")
    ada.post "/api/comparisons", { items: [article(1), article(2)], result: "| a |\n|---|\n| b |" }
    assert_equal 201, ada.status
    ada.get "/api/comparisons"
    assert_equal 1, ada.json.size
    assert_not ada.json.first.key?("result")
  end

  # ---- static files (S-12)
  test "files served from public carry the extra security headers" do
    headers = Rails.application.config.public_file_server.headers
    assert_equal "nosniff", headers["X-Content-Type-Options"]
    assert headers["Content-Security-Policy"].present?
  end

  # ---- email-first sign-up (S-05)
  test "with EMAIL_FIRST_SIGNUP, sign-up answers the same for new and existing addresses and signs nobody in" do
    with_env("EMAIL_FIRST_SIGNUP" => "true") do
      first = new_client
      first.post "/api/auth/register", { name: "Ada", email: "ada@example.com", password: PASSWORD }
      new_result = [first.status, first.json]
      assert_equal 202, first.status
      assert_nil first.cookie_value
      assert_equal 1, mails("Confirm your email address").size

      second = new_client
      second.post "/api/auth/register", { name: "Someone else", email: "ADA@example.com", password: "another-pass1" }
      assert_equal new_result, [second.status, second.json]          # nothing tells the two cases apart
      assert_nil second.cookie_value
      assert_equal 1, User.count
      assert_equal 1, mails("You already have an account").size
      assert_equal "ada@example.com", mails("You already have an account").first.to.first
    end
  end

  test "with EMAIL_FIRST_SIGNUP, real mistakes are still reported, and mail to one address is limited" do
    with_env("EMAIL_FIRST_SIGNUP" => "true") do
      client = new_client
      client.post "/api/auth/register", { name: "Ada", email: "ada@example.com", password: "short" }
      assert_equal 422, client.status
      assert_equal 0, User.count

      3.times { client.post "/api/auth/register", { name: "Ada", email: "ada@example.com", password: PASSWORD } }
      assert_equal 2, mails.size                                      # the third request sent nothing
    end
  end

  test "with EMAIL_FIRST_SIGNUP, an unconfirmed account cannot sign in until the link is used" do
    with_env("EMAIL_FIRST_SIGNUP" => "true") do
      new_client.post "/api/auth/register", { name: "Ada", email: "ada@example.com", password: PASSWORD }
      client = new_client
      client.post "/api/auth/login", { email: "ada@example.com", password: PASSWORD }
      assert_equal 403, client.status

      new_client.post "/api/auth/verify_email", { token: token_from_mail("Confirm your email address") }
      client.post "/api/auth/login", { email: "ada@example.com", password: PASSWORD }
      assert_equal 200, client.status
    end
  end

  # ---- size limit for chunked bodies (N-01)
  test "the size limit also covers bodies sent without a Content-Length" do
    app = RequestSizeLimit.new(->(env) { [200, {}, [env["rack.input"].read]] }, limit: 10)
    chunked = { "HTTP_TRANSFER_ENCODING" => "chunked", "rack.input" => StringIO.new("x" * 11) }
    assert_equal 413, app.call(chunked)[0]

    small = { "HTTP_TRANSFER_ENCODING" => "chunked", "rack.input" => StringIO.new("hello") }
    status, _headers, body = app.call(small)
    assert_equal [200, "hello"], [status, body.first]                   # the app still gets the whole body
  end
end
