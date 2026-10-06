require "test_helper"

class LimitsTest < ActionDispatch::IntegrationTest
  setup { @ada = signed_in("Ada") }

  test "oversized fields are trimmed before saving" do
    @ada.post "/api/saved_articles", { article: article(1).merge(description: "x" * 50_000, title: "t" * 5_000,
                                                                 tags: (1..30).map { |n| "tag#{n}" }) }
    assert_equal 201, @ada.status
    saved = SavedArticle.last
    assert_equal 1000, saved.description.length
    assert_equal 300, saved.title.length
    assert_equal 8, saved.tags.size
  end

  test "a user can save at most 500 articles" do
    now = Time.current
    SavedArticle.insert_all((1..SavedArticle::MAX_PER_USER).map do |n|
      { user_id: User.first.id, title: "T#{n}", url: "https://e.com/#{n}", created_at: now, updated_at: now }
    end)
    @ada.post "/api/saved_articles", { article: article(9999) }
    assert_equal 422, @ada.status
    assert_match(/up to 500/, @ada.json["error"])
  end

  test "a comparison result is capped at 20,000 characters" do
    @ada.post "/api/comparisons", { items: [article(1), article(2)], result: "x" * 20_001 }
    assert_equal 422, @ada.status
    @ada.post "/api/comparisons", { items: [article(1), article(2)], result: "x" * 20_000 }
    assert_equal 201, @ada.status
  end

  test "generate is limited to 10 per hour per user" do
    bob = signed_in("Bob")
    stub_singleton(ComparisonGenerator, :call, ->(_items, **_) { { markdown: "ok", ai: false, note: nil } }) do
      10.times do
        @ada.post "/api/comparisons/generate", { items: [article(1), article(2)] }
        assert_equal 200, @ada.status
      end
      @ada.post "/api/comparisons/generate", { items: [article(1), article(2)] }
      assert_equal 429, @ada.status
      assert @ada.header("Retry-After").to_i.positive?

      bob.post "/api/comparisons/generate", { items: [article(1), article(2)] }   # other users are unaffected
      assert_equal 200, bob.status
    end
  end

  test "search is limited to 30 per hour and the dashboard refresh to 3 per 10 minutes" do
    stub_singleton(IdeaSearcher, :call, ->(_q) { { query: "x", sections: [] } }) do
      30.times { @ada.get "/api/search", { q: "rails" } }
      assert_equal 200, @ada.status
      @ada.get "/api/search", { q: "rails" }
      assert_equal 429, @ada.status
    end

    stub_singleton(TrendFetcher, :dashboard, ->(force: false) { { feeds: {}, topics: [] } }) do
      3.times { @ada.post "/api/dashboard/refresh" }
      assert_equal 200, @ada.status
      @ada.post "/api/dashboard/refresh"
      assert_equal 429, @ada.status
      @ada.get "/api/dashboard"          # a normal load is never limited
      assert_equal 200, @ada.status
    end
  end
end
