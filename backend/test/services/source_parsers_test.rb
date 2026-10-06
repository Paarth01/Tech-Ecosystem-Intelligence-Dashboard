require "test_helper"

# The external sites are replaced with sample responses shaped like the real ones, so these tests
# check our parsing and error handling without touching the network.
class SourceParsersTest < ActiveSupport::TestCase
  def json_stub(routes)
    lambda do |url, **_|
      key = routes.keys.find { |k| url.include?(k) } or raise HttpClient::Error, "unexpected #{url}"
      routes[key]
    end
  end

  test "hacker news" do
    routes = {
      "topstories" => [1, 2],
      "item/1.json" => { "id" => 1, "title" => "Show HN: A Rust database", "url" => "https://db.example", "by" => "ann",
                         "score" => 120, "descendants" => 45, "time" => 1_700_000_000 },
      "item/2.json" => { "id" => 2, "title" => "Ask HN: Hiring?", "by" => "bob", "score" => 5, "descendants" => 2, "time" => 1_700_000_100 }
    }
    stub_singleton(HttpClient, :get_json, json_stub(routes)) do
      items = TrendFetcher.fetch_hackernews
      assert_equal ["Show HN: A Rust database", "Ask HN: Hiring?"], items.map { |i| i[:title] }
      assert_equal "120 points", items.first[:meta]
      assert_equal 120, items.first[:engagement]
      assert_equal "https://news.ycombinator.com/item?id=2", items.last[:url]   # text posts link to the thread
      assert_equal "HackerNews", items.first[:source]
    end
  end

  test "dev.to" do
    payload = [{ "id" => 9, "title" => "Learn Rust", "description" => "Intro", "url" => "https://dev.to/a/learn-rust",
                 "tag_list" => %w[rust beginners], "positive_reactions_count" => 77, "readable_publish_date" => "Oct 1",
                 "user" => { "name" => "Cy" } }]
    stub_singleton(HttpClient, :get_json, json_stub("articles?top=7" => payload)) do
      item = TrendFetcher.fetch_devto.first
      assert_equal %w[rust beginners], item[:tags]
      assert_equal "♥ 77", item[:meta]
      assert_equal 77, item[:engagement]
      assert_equal "Cy", item[:author]
    end
  end

  test "lobsters, with the submitter as an object or a plain name" do
    payload = [{ "short_id" => "a1", "title" => "T1", "url" => "", "comments_url" => "https://lobste.rs/s/a1", "score" => 10,
                 "comment_count" => 3, "tags" => ["rust"], "submitter_user" => { "username" => "dee" }, "created_at" => "2026-10-01T10:00:00.000-05:00" },
               { "short_id" => "b2", "title" => "T2", "url" => "https://e.com/2", "score" => 4, "comment_count" => 0,
                 "tags" => [], "submitter_user" => "eve", "created_at" => "2026-10-02T10:00:00.000-05:00" }]
    stub_singleton(HttpClient, :get_json, json_stub("hottest.json" => payload)) do
      items = TrendFetcher.fetch_lobsters
      assert_equal "https://lobste.rs/s/a1", items.first[:url]   # self posts fall back to the discussion page
      assert_equal "dee", items.first[:author]
      assert_equal 10, items.first[:engagement]
      assert_equal "eve", items.last[:author]
    end
  end

  test "stack overflow decodes html entities" do
    payload = { "items" => [{ "question_id" => 5, "title" => "Why doesn&#39;t &amp; work?", "link" => "https://so.example/q/5",
                              "score" => 12, "answer_count" => 2, "view_count" => 900, "tags" => %w[ruby rails], "creation_date" => 1_700_000_000,
                              "owner" => { "display_name" => "Fay &amp; Co" } }] }
    stub_singleton(HttpClient, :get_json, json_stub("questions?order=desc" => payload)) do
      item = TrendFetcher.fetch_stackoverflow.first
      assert_equal "Why doesn't & work?", item[:title]
      assert_equal "Fay & Co", item[:author]
      assert_equal %w[ruby rails], item[:tags]
      assert_equal 12, item[:engagement]
    end
  end

  test "github trending page" do
    html = <<~HTML
      <article class="Box-row"><h2 class="h3"><a href="/acme/widget">acme / widget</a></h2>
        <p class="col-9">A tidy widget</p><span itemprop="programmingLanguage">Ruby</span>
        <span class="d-inline-block float-sm-right">1,234 stars this week</span></article>
      <article class="Box-row"><h2><a href="/acme/other">acme / other</a></h2></article>
    HTML
    stub_singleton(HttpClient, :get, ->(_url, **_) { html }) do
      items = TrendFetcher.fetch_github
      assert_equal "acme/widget", items.first[:title]
      assert_equal "https://github.com/acme/widget", items.first[:url]
      assert_equal "+1,234 stars this week", items.first[:meta]
      assert_equal 1234, items.first[:engagement]
      assert_equal 0, items.last[:engagement]
      assert_equal ["Ruby"], items.first[:tags]
      assert_equal "No description", items.last[:description]
    end
  end

  test "reddit and github search" do
    reddit = { "data" => { "children" => [{ "data" => { "id" => "r1", "title" => "Best &amp; worst", "permalink" => "/r/rails/comments/r1/x/",
                                                       "subreddit_name_prefixed" => "r/rails", "selftext" => "body", "score" => 50, "num_comments" => 9, "author" => "gus" } }] } }
    github = { "items" => [{ "id" => 1, "full_name" => "a/b", "html_url" => "https://github.com/a/b", "description" => nil,
                             "stargazers_count" => 1234, "forks_count" => 5, "language" => "Ruby", "owner" => { "login" => "a" } }] }
    stub_singleton(HttpClient, :get_json, json_stub("reddit.com" => reddit, "api.github.com" => github)) do
      assert_equal "https://www.reddit.com/r/rails/comments/r1/x/", IdeaSearcher.reddit("rails").first[:url]
      assert_equal "Best & worst", IdeaSearcher.reddit("rails").first[:title]
      assert_equal "★ 1,234 · 5 forks", IdeaSearcher.github("rails").first[:meta]
    end
  end
end
