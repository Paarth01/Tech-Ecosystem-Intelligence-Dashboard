require "test_helper"

class TrendHistoryTest < ActiveSupport::TestCase
  def topics(pairs)
    pairs.map { |tag, score| { tag: tag, score: score } }
  end

  def seed(captured_at, pairs)
    TrendSnapshot.insert_all(pairs.map { |tag, score| { tag: tag, score: score, captured_at: captured_at } })
  end

  test "a snapshot is taken at most once an hour" do
    TrendSnapshot.capture_if_due(topics("rust" => 4.0, "go" => 2.0))
    TrendSnapshot.capture_if_due(topics("rust" => 5.0))
    assert_equal 2, TrendSnapshot.count

    TrendSnapshot.update_all(captured_at: 2.hours.ago)
    TrendSnapshot.capture_if_due(topics("rust" => 5.0))
    assert_equal 3, TrendSnapshot.count
  end

  test "snapshots older than 30 days are removed" do
    seed(31.days.ago, "old" => 1.0)
    TrendSnapshot.capture_if_due(topics("rust" => 4.0))
    assert_equal ["rust"], TrendSnapshot.pluck(:tag)
  end

  test "there are no trends until a day of history exists" do
    assert_equal({}, TrendSnapshot.trends_for(topics("rust" => 4.0)))
    seed(5.hours.ago, "rust" => 3.0)
    assert_equal({}, TrendSnapshot.trends_for(topics("rust" => 4.0)))
  end

  test "compares with the newest snapshot that is at least a day old" do
    seed(3.days.ago, "rust" => 1.0)                 # ignored: a newer day-old snapshot exists
    seed(25.hours.ago, "rust" => 10.0, "python" => 10.0, "zig" => 10.0, "java" => 10.0)
    seed(2.hours.ago, "rust" => 99.0)                # ignored: too recent

    trends = TrendSnapshot.trends_for(topics("rust" => 12.4, "python" => 10.5, "zig" => 5.0, "java" => 10.0, "go" => 3.0))
    assert_equal({ label: "up", percent: 24 }, trends["rust"])
    assert_equal({ label: "flat", percent: 5 }, trends["python"])
    assert_equal({ label: "down", percent: -50 }, trends["zig"])
    assert_equal({ label: "flat", percent: 0 }, trends["java"])
    assert_equal({ label: "new" }, trends["go"])     # wasn't in yesterday's snapshot
  end

  test "the dashboard records snapshots and reports each topic's trend" do
    item = { id: "1", title: "Rust DB", url: "https://e.com/1", source: "GitHub", description: "d", meta: "m", tags: ["Rust"], engagement: 10 }
    seed(25.hours.ago, "rust" => 1.0)

    with_sources("github" => -> { [item.dup] }) do
      data = TrendFetcher.dashboard
      assert_equal "up", data[:topics].first.dig(:trend, :label)
      TrendFetcher.dashboard(force: true)
    end
    assert_equal 1, TrendSnapshot.where("captured_at > ?", 1.hour.ago).count   # twice in an hour: one snapshot
  end

  test "the dashboard still works if snapshots fail" do
    item = { id: "1", title: "Rust DB", url: "https://e.com/1", source: "GitHub", description: "d", meta: "m", tags: ["Rust"] }
    with_sources("github" => -> { [item.dup] }) do
      stub_singleton(TrendSnapshot, :capture_if_due, ->(_topics) { raise ActiveRecord::StatementInvalid, "database is locked" }) do
        data = TrendFetcher.dashboard
        assert_equal "Rust", data[:topics].first[:name]
        assert_nil data[:topics].first[:trend]
      end
    end
  end

  def with_sources(overrides)
    stubs = TrendFetcher::SOURCES.to_h { |s| [s, -> { [] }] }.merge(overrides)
    runner = stubs.reduce(-> { yield }) { |inner, (source, impl)| -> { stub_singleton(TrendFetcher, :"fetch_#{source}", impl) { inner.call } } }
    runner.call
  end
end
