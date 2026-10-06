require "test_helper"

class TrendFetcherTest < ActiveSupport::TestCase
  GOOD = { id: "1", title: "Rust DB", url: "https://e.com/1", source: "GitHub", description: "d", meta: "m", tags: ["Rust"] }.freeze

  # Stubs all five sources; `overrides` replaces individual ones.
  def stub_sources(overrides = {})
    defaults = TrendFetcher::SOURCES.to_h { |s| [s, -> { [] }] }
    stubs = defaults.merge(overrides.transform_keys(&:to_s))
    runner = stubs.reduce(-> { yield }) do |inner, (source, impl)|
      -> { stub_singleton(TrendFetcher, :"fetch_#{source}", impl) { inner.call } }
    end
    runner.call
  end

  test "builds feeds and topics, and names the sources that returned nothing" do
    stub_sources("github" => -> { [GOOD.dup] }) do
      data = TrendFetcher.dashboard
      assert_equal 1, data[:feeds]["github"].size
      assert_equal "Rust", data[:topics].first[:name]
      assert_includes data[:unavailable], "hackernews"
      assert_not_includes data[:unavailable], "github"
      assert data[:updated_at].present?
    end
  end

  test "links that are not http(s) are dropped" do
    bad = GOOD.merge(id: "2", url: "javascript:alert(1)", title: "Evil")
    stub_sources("github" => -> { [GOOD.dup, bad] }) do
      assert_equal ["Rust DB"], TrendFetcher.dashboard[:feeds]["github"].map { |i| i[:title] }
    end
  end

  test "a failing source is remembered briefly so it isn't retried on every request" do
    calls = 0
    stub_sources("lobsters" => -> { calls += 1; raise HttpClient::Error, "boom" }) do
      3.times { TrendFetcher.dashboard }
      assert_equal 1, calls
    end
  end

  test "good data is cached, refresh bypasses the cache, and a failed refresh keeps the old data" do
    calls = 0
    results = [[GOOD.dup], [GOOD.merge(title: "Newer")]]
    impl = -> { calls += 1; results.shift || raise(HttpClient::Error, "down") }
    stub_sources("github" => impl) do
      assert_equal "Rust DB", TrendFetcher.dashboard[:feeds]["github"].first[:title]
      TrendFetcher.dashboard
      assert_equal 1, calls                                    # second call came from the cache

      assert_equal "Newer", TrendFetcher.dashboard(force: true)[:feeds]["github"].first[:title]
      assert_equal 2, calls

      data = TrendFetcher.dashboard(force: true)               # the source is now failing
      assert_equal "Newer", data[:feeds]["github"].first[:title]
      assert_not_includes data[:unavailable], "github"
    end
  end
end

class IdeaSearcherTest < ActiveSupport::TestCase
  test "a source that failed is skipped for a minute, and incomplete answers are not cached" do
    calls = 0
    ok = ->(_q) { [{ id: "1", title: "T", url: "https://e.com", source: "X" }] }
    stubs = { github: ok, devto: ok, stackoverflow: ok, reddit: ->(_q) { calls += 1; raise HttpClient::Error, "blocked" } }

    stub_singleton(IdeaSearcher, :github, stubs[:github]) do
      stub_singleton(IdeaSearcher, :devto, stubs[:devto]) do
        stub_singleton(IdeaSearcher, :stackoverflow, stubs[:stackoverflow]) do
          stub_singleton(IdeaSearcher, :reddit, stubs[:reddit]) do
            first = IdeaSearcher.call("rails")
            reddit = first[:sections].find { |s| s[:key] == "discussions" }
            assert reddit[:error]
            assert_equal 1, first[:sections].find { |s| s[:key] == "code" }[:items].size

            IdeaSearcher.call("rails")
            IdeaSearcher.call("another query")
            assert_equal 1, calls
          end
        end
      end
    end
  end

  test "no snapshot is saved while a source is down, so topics don't look like they fell" do
    stub_sources("github" => -> { [GOOD.dup] }) do      # the other four sources return nothing
      TrendFetcher.dashboard
    end
    assert_equal 0, TrendSnapshot.count

    all_up = TrendFetcher::SOURCES.to_h { |s| [s, -> { [GOOD.merge(id: s, url: "https://e.com/#{s}")] }] }
    stub_sources(all_up) { TrendFetcher.dashboard(force: true) }
    assert TrendSnapshot.count.positive?
  end
end
