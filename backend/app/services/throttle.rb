# Counters in the cache, used for rate limits and login lockouts.
#
# Updates are guarded by a mutex so two threads can't both read the same number and write the
# same total. The mutex is per process: the app runs one Puma process (threads only). If you ever
# run several processes or servers, move these counters to a shared store with atomic increments.
module Throttle
  LOCK = Mutex.new

  def self.count(key)
    value = Rails.cache.read(key)
    value.is_a?(Hash) ? value[:n].to_i : value.to_i
  end

  # Adds one to the counter and returns the new count.
  # sliding: true  - every hit restarts the expiry (the counter only expires after quiet time).
  # sliding: false - the window is fixed by the first hit, so repeated attempts can't extend it.
  def self.hit(key, within:, sliding: true)
    LOCK.synchronize do
      now = Time.current.to_f
      current = Rails.cache.read(key)
      total = (current.is_a?(Hash) ? current[:n].to_i : current.to_i) + 1
      ends_at = if !sliding && current.is_a?(Hash) && current[:ends_at].to_f > now
        current[:ends_at].to_f
      else
        now + within.to_f
      end
      Rails.cache.write(key, { n: total, ends_at: ends_at }, expires_in: [ends_at - now, 1].max)
      total
    end
  end

  def self.clear(key)
    Rails.cache.delete(key)
  end

  # Cache keys shouldn't contain raw email addresses.
  def self.fingerprint(value)
    Digest::SHA256.hexdigest(value.to_s.downcase)[0, 24]
  end
end
