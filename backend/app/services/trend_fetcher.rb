require "cgi"
require "nokogiri"

# Loads the live trending feeds. Each source is cached for an hour and a failing
# source simply returns an empty list so the dashboard still renders.
class TrendFetcher
  LIMIT = 8
  SOURCES = %w[github hackernews devto lobsters stackoverflow].freeze
  # One lock per source, so when the cache expires only one request refetches and the rest reuse it.
  LOCKS = SOURCES.to_h { |source| [source, Mutex.new] }.freeze

  # force: true skips the cache (used by the Refresh button).
  def self.dashboard(force: false)
    results = Fanout.run(SOURCES.to_h { |source| [source, -> { load_source(source, force) }] })
    loaded = results.transform_values { |r| r[:value] || { items: [], fetched_at: nil } }

    feeds = loaded.transform_values { |entry| entry[:items] }
    topics = TrendAggregator.call(feeds.values.flatten)
    # A snapshot taken while a source is down would make topics look like they fell, so it is skipped.
    trends = record_and_compare(topics, capture: feeds.values.none?(&:empty?))
    topics = topics.first(30).map { |topic| topic.merge(trend: trends[topic[:tag]]) }

    {
      feeds: feeds,
      topics: topics,
      unavailable: feeds.select { |_, items| items.empty? }.keys,
      ecosystems: TagNormalizer::ECOSYSTEM_NAMES,
      updated_at: loaded.values.filter_map { |entry| entry[:fetched_at] }.min || Time.current
    }
  end

  # Saves an hourly snapshot and returns each topic's change since yesterday. The dashboard still
  # works if the database is unavailable.
  def self.record_and_compare(topics, capture: true)
    TrendSnapshot.capture_if_due(topics) if capture
    TrendSnapshot.trends_for(topics.first(30))
  rescue StandardError => e
    Rails.logger.warn("[trends] snapshots unavailable: #{e.class}: #{e.message}")
    {}
  end

  # Returns { items:, fetched_at: } for one source. Good data is cached for an hour. A failure
  # is cached for a minute so a down source doesn't make every request wait for its timeout,
  # and a failed refresh never replaces older good data.
  def self.load_source(source, force)
    cache_key = "trend:#{source}:v2"
    previous = Rails.cache.read(cache_key)
    return previous if previous && !force

    LOCKS.fetch(source).synchronize do
      unless force
        current = Rails.cache.read(cache_key)   # another request may have refilled the cache while we waited
        return current if current
      end
      refill_source(source, cache_key, previous)
    end
  end

  def self.refill_source(source, cache_key, previous)
    items = begin
      ArticleSanitizer.safe_items(public_send("fetch_#{source}"))
    rescue StandardError => e
      Rails.logger.warn("[trends] #{source} failed: #{e.class}: #{e.message}")
      []
    end
    return previous if items.empty? && previous&.dig(:items).present?

    entry = { items: items, fetched_at: Time.current }
    Rails.cache.write(cache_key, entry, expires_in: items.any? ? 1.hour : 1.minute)
    entry
  end

  def self.fetch_github
    html = HttpClient.get("https://github.com/trending?since=weekly", headers: { "Accept" => "text/html" })
    Nokogiri::HTML(html).css(".Box-row").first(LIMIT).filter_map do |row|
      href = row.at_css("h2 a")&.[]("href")
      next unless href

      stars = row.text[/([\d,]+)\s+stars?\s+(?:this week|today)/, 1]
      language = row.at_css("[itemprop=programmingLanguage]")&.text&.strip
      {
        id: href, title: href.delete_prefix("/"), url: "https://github.com#{href}", source: "GitHub",
        description: row.at_css("p")&.text&.squish.presence || "No description",
        meta: stars ? "+#{stars} stars this week" : "Trending", engagement: stars.to_s.delete(",").to_i, tags: [language].compact_blank,
        author: href.split("/")[1], date: nil
      }
    end
  end

  def self.fetch_hackernews
    ids = HttpClient.get_json("https://hacker-news.firebaseio.com/v0/topstories.json").first(LIMIT)
    stories = Fanout.run(ids.to_h { |id| [id, -> { HttpClient.get_json("https://hacker-news.firebaseio.com/v0/item/#{id}.json") }] })
    ids.filter_map do |id|
      s = stories.dig(id, :value)
      next unless s && s["title"] && !s["dead"] && !s["deleted"]

      {
        id: id.to_s, title: s["title"], url: s["url"].presence || "https://news.ycombinator.com/item?id=#{id}",
        source: "HackerNews", description: "#{s['descendants'].to_i} comments · by #{s['by']}",
        meta: "#{s['score']} points", engagement: s["score"].to_i, tags: [], author: s["by"], date: format_time(s["time"])
      }
    end
  end

  def self.fetch_devto
    HttpClient.get_json("https://dev.to/api/articles?top=7&per_page=#{LIMIT}").map do |a|
      {
        id: a["id"].to_s, title: a["title"], url: a["url"], source: "Dev.to", description: a["description"].to_s,
        meta: "♥ #{a['positive_reactions_count']}", engagement: a["positive_reactions_count"].to_i,
        tags: split_tags(a["tag_list"]),
        author: a.dig("user", "name"), date: a["readable_publish_date"]
      }
    end
  end

  def self.fetch_lobsters
    HttpClient.get_json("https://lobste.rs/hottest.json").first(LIMIT).map do |s|
      user = s["submitter_user"].is_a?(Hash) ? s["submitter_user"]["username"] : s["submitter_user"]
      {
        id: s["short_id"], title: s["title"], url: s["url"].presence || s["comments_url"], source: "Lobsters",
        description: "#{s['comment_count']} comments · by #{user}", meta: "↑ #{s['score']}", engagement: s["score"].to_i,
        tags: Array(s["tags"]), author: user, date: format_time(s["created_at"])
      }
    end
  end

  def self.fetch_stackoverflow
    data = HttpClient.get_json("https://api.stackexchange.com/2.3/questions?order=desc&sort=hot&site=stackoverflow&pagesize=#{LIMIT}")
    data.fetch("items", []).map do |q|
      {
        id: q["question_id"].to_s, title: CGI.unescapeHTML(q["title"].to_s), url: q["link"], source: "StackOverflow",
        description: "Score #{q['score']} · #{q['answer_count']} answers", meta: "#{q['view_count']} views",
        engagement: q["score"].to_i,
        tags: Array(q["tags"]).first(4), author: CGI.unescapeHTML(q.dig("owner", "display_name").to_s),
        date: format_time(q["creation_date"])
      }
    end
  end

  def self.split_tags(value)
    value.is_a?(Array) ? value : value.to_s.split(",").map(&:strip)
  end

  def self.format_time(value)
    return nil if value.blank?
    time = value.is_a?(Numeric) ? Time.at(value) : Time.parse(value.to_s)
    time.utc.strftime("%b %-d, %Y")
  rescue ArgumentError
    nil
  end
end
