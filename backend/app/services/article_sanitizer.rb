# Cleans article data that comes from outside (a feed, or the browser) before it is shown,
# saved or compared: caps field sizes and only allows http(s) links.
module ArticleSanitizer
  LIMITS = { title: 300, source: 40, description: 1000, meta: 100, author: 100, date: 40 }.freeze
  URL_MAX = 2000

  def self.safe_url?(url)
    url.is_a?(String) && url.length <= URL_MAX && url.match?(%r{\Ahttps?://\S+\z}i)
  end

  # Returns a plain hash with string keys and size-limited values.
  def self.clean(raw)
    data = raw.to_h.with_indifferent_access
    cleaned = LIMITS.to_h { |field, max| [field.to_s, data[field].to_s.strip.first(max).presence] }
    cleaned["url"] = data[:url].to_s.strip
    cleaned["tags"] = Array(data[:tags]).map { |t| t.to_s.strip.first(40) }.reject(&:blank?).first(8)
    cleaned
  end

  def self.safe_items(items)
    items.select { |item| safe_url?(item[:url]) }
  end
end
