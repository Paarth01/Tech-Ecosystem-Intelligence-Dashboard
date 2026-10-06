# Hourly record of topic scores, so the dashboard can say what is rising or falling.
class TrendSnapshot < ApplicationRecord
  KEEP_DAYS = 30
  MIN_AGE = 20.hours   # compare against a snapshot at least this old

  # Records the current top topics, at most once an hour.
  def self.capture_if_due(topics)
    return if topics.empty? || where("captured_at > ?", 1.hour.ago).exists?

    now = Time.current
    insert_all(topics.first(50).map { |t| { tag: t[:tag], score: t[:score], captured_at: now } })
    where("captured_at < ?", KEEP_DAYS.days.ago).delete_all
  end

  # { "rust" => { label: "up", percent: 24 }, ... } compared with the newest snapshot that is at
  # least a day old. Empty until the app has been collecting for a day.
  def self.trends_for(topics)
    reference = where("captured_at <= ?", MIN_AGE.ago).maximum(:captured_at)
    return {} unless reference

    previous = where(captured_at: reference).pluck(:tag, :score).to_h
    topics.to_h { |topic| [topic[:tag], trend(topic[:score], previous[topic[:tag]])] }
  end

  def self.trend(score, previous)
    return { label: "new" } unless previous.to_f.positive?

    percent = (((score - previous) / previous) * 100).round
    label = if percent >= 10 then "up" elsif percent <= -10 then "down" else "flat" end
    { label: label, percent: percent }
  end
end
