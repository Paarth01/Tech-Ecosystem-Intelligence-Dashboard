require "test_helper"

class ThrottleWindowsTest < ActiveSupport::TestCase
  test "counts are not lost when threads hit the same key at once" do
    30.times.map { Thread.new { 20.times { Throttle.hit("busy", within: 1.hour) } } }.each(&:join)
    assert_equal 600, Throttle.count("busy")
  end

  test "a fixed window is not extended by later hits, a sliding one is" do
    travel_to Time.zone.local(2026, 1, 1, 12, 0, 0) do
      Throttle.hit("fixed", within: 100.seconds, sliding: false)
      Throttle.hit("sliding", within: 100.seconds)
      travel 60.seconds
      Throttle.hit("fixed", within: 100.seconds, sliding: false)
      Throttle.hit("sliding", within: 100.seconds)
      travel 41.seconds   # 101 seconds after the first hit
      assert_equal 0, Throttle.count("fixed")
      assert_equal 2, Throttle.count("sliding")
    end
  end

  test "counters written in the old plain-number format still work" do
    Rails.cache.write("legacy", 7, expires_in: 1.hour)
    assert_equal 7, Throttle.count("legacy")
    assert_equal 8, Throttle.hit("legacy", within: 1.hour)
  end
end
