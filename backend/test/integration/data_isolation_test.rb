require "test_helper"

# The most important tests in the project: user A must never see or change user B's data.
class DataIsolationTest < ActionDispatch::IntegrationTest
  setup do
    @alice = signed_in("Alice")
    @bob = signed_in("Bob")
  end

  test "saved articles are private to their owner" do
    @alice.post "/api/saved_articles", { article: article(1) }
    assert_equal 201, @alice.status
    id = @alice.json["id"]

    @alice.get "/api/saved_articles"
    assert_equal 1, @alice.json.size
    @bob.get "/api/saved_articles"
    assert_equal [], @bob.json

    @bob.delete "/api/saved_articles/#{id}"
    assert_equal 404, @bob.status
    assert_equal 1, SavedArticle.count

    @alice.delete "/api/saved_articles/#{id}"
    assert_equal 204, @alice.status
    assert_equal 0, SavedArticle.count
  end

  test "two users can save the same url independently, and the same user twice does not duplicate" do
    @alice.post "/api/saved_articles", { article: article(1) }
    @alice.post "/api/saved_articles", { article: article(1) }
    @bob.post "/api/saved_articles", { article: article(1) }
    assert_equal 201, @bob.status
    assert_equal 2, SavedArticle.count
  end

  test "only http and https links can be saved" do
    @alice.post "/api/saved_articles", { article: article(1).merge(url: "javascript:alert(1)") }
    assert_equal 422, @alice.status
  end

  test "comparisons are private to their owner" do
    @alice.post "/api/comparisons", { items: [article(1), article(2)], result: "| a | b |" }
    assert_equal 201, @alice.status
    id = @alice.json["id"]

    @bob.get "/api/comparisons"
    assert_equal [], @bob.json
    @bob.get "/api/comparisons/#{id}"
    assert_equal 404, @bob.status
    @bob.delete "/api/comparisons/#{id}"
    assert_equal 404, @bob.status
    assert_equal 1, Comparison.count

    @alice.get "/api/comparisons/#{id}"
    assert_equal 2, @alice.json["items"].size
    @alice.delete "/api/comparisons/#{id}"
    assert_equal 204, @alice.status
  end

  test "generate needs 2 to 4 articles and falls back to a plain table without an API key" do
    @alice.post "/api/comparisons/generate", { items: [article(1)] }
    assert_equal 422, @alice.status
    @alice.post "/api/comparisons/generate", { items: (1..5).map { |n| article(n) } }
    assert_equal 422, @alice.status

    with_env("GEMINI_API_KEY" => nil) do
      @alice.post "/api/comparisons/generate", { items: [article(1), article(2)] }
    end
    assert_equal 200, @alice.status
    assert_equal false, @alice.json["ai"]
    assert_includes @alice.json["markdown"], "Article 1"
    assert @alice.json["note"].present?
  end

  test "deleting a user removes their data only" do
    @alice.post "/api/saved_articles", { article: article(1) }
    @bob.post "/api/saved_articles", { article: article(2) }
    User.find_by(email: "alice@example.com").destroy
    assert_equal 1, SavedArticle.count
    assert_equal 1, Session.count
  end
end
