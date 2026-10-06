require "test_helper"

class TagAndScoreTest < ActiveSupport::TestCase
  test "aliases collapse to one tag" do
    assert_equal "react", TagNormalizer.normalize("ReactJS")
    assert_equal "postgresql", TagNormalizer.normalize("postgres")
    assert_equal "rust", TagNormalizer.normalize("Rust-lang")
  end

  test "finds technologies in text, including C# and C++" do
    found = TagNormalizer.extract("Interop between C++ and C# is hard")
    assert_includes found, "c++"
    assert_includes found, "c#"
    assert_includes TagNormalizer.extract("Postgres tips"), "postgresql"
    assert_includes TagNormalizer.extract("Why AI agents are local"), "artificial intelligence"
  end

  test "everyday words are not mistaken for technologies" do
    assert_empty TagNormalizer.extract("Let's go to the market, what's next, a solid argument, a node in a graph")
    assert_empty TagNormalizer.extract("He said it with ai-ready clarity")
  end

  test "generic tags are dropped" do
    assert_equal ["rust"], TagNormalizer.tags_for(%w[webdev programming Rust], "")
  end

  test "a technology on several platforms outranks a repeat on one platform" do
    items = [
      { id: "1", title: "a", description: "", source: "GitHub", tags: ["Rust"], url: "https://x/1" },
      { id: "2", title: "b", description: "", source: "Dev.to", tags: ["rust"], url: "https://x/2" },
      { id: "3", title: "c", description: "", source: "GitHub", tags: ["Python"], url: "https://x/3" },
      { id: "4", title: "d", description: "", source: "GitHub", tags: ["Python"], url: "https://x/4" }
    ]
    topics = TrendAggregator.call(items)
    assert_equal "Rust", topics.first[:name]
    assert_equal 4.1, topics.first[:score]   # (1.5 + 0.8) * (1 + log2(2) * 0.8)
    assert_equal 3.0, topics.last[:score]    # 1.5 + 1.5, single source
    assert_equal ["Systems"], topics.first[:ecosystems]
    assert_equal ["rust"], items.first[:topics]
  end

  test "engagement counts within each source: the most engaged item weighs 1.5, none weighs 0.5" do
    gh = ->(id, tag, engagement) { { id: id, title: id, description: "", source: "GitHub", tags: [tag], url: "https://x/#{id}", engagement: engagement } }
    hn = ->(id, tag, engagement) { { id: id, title: id, description: "", source: "HackerNews", tags: [tag], url: "https://x/#{id}", engagement: engagement } }
    topics = TrendAggregator.call([gh.("a", "Rust", 12_000), gh.("b", "Python", 6_000), gh.("c", "Go", 0),
                                   hn.("d", "Zig", 40), hn.("e", "Elixir", 0)]).to_h { |t| [t[:tag], t[:score]] }

    assert_in_delta 2.25, topics["rust"], 0.06     # 1.5 * (0.5 + 12000/12000)
    assert_in_delta 1.5,  topics["python"], 0.06   # 1.5 * (0.5 + 6000/12000)
    assert_in_delta 0.75, topics["go"], 0.06       # 1.5 * 0.5
    assert_in_delta 1.8,  topics["zig"], 0.06      # 1.2 * 1.5: scaled within Hacker News, not against GitHub
    assert_in_delta 0.6,  topics["elixir"], 0.06
  end

  test "items without engagement numbers are weighed neutrally" do
    items = [{ id: "1", title: "a", description: "", source: "GitHub", tags: ["Rust"], url: "https://x/1" },
             { id: "2", title: "b", description: "", source: "GitHub", tags: ["Rust"], url: "https://x/2", engagement: 0 }]
    assert_in_delta 3.0, TrendAggregator.call(items).first[:score], 0.05   # 1.5 + 1.5
  end

  test "article sanitizer trims fields and only accepts http(s) links" do
    assert ArticleSanitizer.safe_url?("https://example.com/a?b=1")
    assert_not ArticleSanitizer.safe_url?("javascript:alert(1)")
    assert_not ArticleSanitizer.safe_url?("data:text/html,hi")
    assert_not ArticleSanitizer.safe_url?("https://e.com/" + "a" * 2000)

    cleaned = ArticleSanitizer.clean(title: "  Hi  ", url: " https://e.com ", description: "d" * 5000, tags: ["a", "", "b"])
    assert_equal "Hi", cleaned["title"]
    assert_equal "https://e.com", cleaned["url"]
    assert_equal 1000, cleaned["description"].length
    assert_equal %w[a b], cleaned["tags"]
    assert_nil cleaned["author"]
  end
end
