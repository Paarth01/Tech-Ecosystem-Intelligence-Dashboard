require "test_helper"

class AuthTest < ActionDispatch::IntegrationTest
  test "register, read account, logout" do
    ada = signed_in("Ada")

    ada.get "/api/me"
    assert_equal 200, ada.status
    assert_equal "ada@example.com", ada.json.dig("user", "email")

    ada.delete "/api/auth/logout"
    assert_equal 204, ada.status

    ada.get "/api/me"
    assert_equal 401, ada.status
  end

  test "login accepts the right password only" do
    signed_in("Ada")

    other = new_client
    other.post "/api/auth/login", { email: "ADA@example.com", password: "wrong" }
    assert_equal 401, other.status
    other.post "/api/auth/login", { email: "nobody@example.com", password: "password123" }
    assert_equal 401, other.status
    assert_equal "Invalid email or password", other.json["error"]

    other.post "/api/auth/login", { email: "ADA@example.com", password: "password123" }
    assert_equal 200, other.status
  end

  test "register validates email, password and uniqueness" do
    signed_in("Ada")
    client = new_client

    client.post "/api/auth/register", { name: "Ada 2", email: "ada@example.com", password: "password123" }
    assert_equal 422, client.status
    client.post "/api/auth/register", { name: "Bob", email: "bob@example.com", password: "short" }
    assert_equal 422, client.status
  end

  test "every data endpoint requires a signed-in user" do
    anon = new_client
    [[:get, "/api/me"], [:get, "/api/dashboard"], [:get, "/api/search?q=rails"],
     [:get, "/api/saved_articles"], [:post, "/api/saved_articles", {}],
     [:get, "/api/comparisons"], [:post, "/api/comparisons/generate", {}]].each do |verb, path, body|
      anon.public_send(verb, path, *body)
      assert_equal 401, anon.status, "#{verb} #{path} should require sign in"
    end
  end

  test "writes without the X-Requested-With header are refused (CSRF defence)" do
    client = new_client
    post "/api/auth/register", params: { name: "Eve", email: "eve@example.com", password: "password123" }, as: :json
    assert_response :forbidden
    assert_equal 0, User.count

    client.post "/api/auth/register", { name: "Eve", email: "eve@example.com", password: "password123" }
    assert_equal 201, client.status
  end

  test "the login cookie is HttpOnly and SameSite, and only a hash is stored" do
    ada = signed_in("Ada")
    assert_match(/httponly/i, ada.set_cookie)
    assert_match(/samesite=lax/i, ada.set_cookie)
    assert_not_includes ada.json.to_s, ada.cookie_value.to_s   # the token is never in a response body

    stored = Session.first.token_digest
    assert_equal 64, stored.length
    assert_not_equal ada.cookie_value, stored
    assert_equal Session.digest(ada.cookie_value), stored
  end

  test "each device has its own session; logging out one keeps the others" do
    laptop = signed_in("Ada")
    phone = new_client
    phone.post "/api/auth/login", { email: "ada@example.com", password: "password123" }
    assert_equal 2, Session.count

    laptop.delete "/api/auth/logout"
    phone.get "/api/me"
    assert_equal 200, phone.status
    assert_equal 1, Session.count
  end

  test "sessions expire after 30 days of no use" do
    ada = signed_in("Ada")
    Session.update_all(last_used_at: 31.days.ago)

    ada.get "/api/me"
    assert_equal 401, ada.status
  end

  test "changing the password signs out other devices but not this one" do
    laptop = signed_in("Ada")
    phone = new_client
    phone.post "/api/auth/login", { email: "ada@example.com", password: "password123" }

    laptop.patch "/api/me", { password: "newpassword1", current_password: "nope" }
    assert_equal 422, laptop.status

    laptop.patch "/api/me", { password: "newpassword1", current_password: "password123" }
    assert_equal 200, laptop.status

    laptop.get "/api/me"
    assert_equal 200, laptop.status
    phone.get "/api/me"
    assert_equal 401, phone.status
  end

  test "sign_in returns the user or nil without raising" do
    user = User.create!(name: "Ada", email: "ada@example.com", password: "password123")
    assert_equal user, User.sign_in("ADA@example.com", "password123")
    assert_nil User.sign_in("ada@example.com", "wrong")
    assert_nil User.sign_in("nobody@example.com", "password123")
    assert_nil User.sign_in(nil, nil)
  end
end
