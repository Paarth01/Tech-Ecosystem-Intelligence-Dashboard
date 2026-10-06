require "cgi"

# "Idea Researcher": searches four platforms at once for a project idea.
class IdeaSearcher
  PER_SOURCE = 6

  SECTIONS = [
    { key: "code",        title: "Reference code",        source: "GitHub",        method: :github,
      description: "Open-source repos to study and learn from" },
    { key: "tutorials",   title: "Tutorials and guides",  source: "Dev.to",        method: :devto,
      description: "Step-by-step articles from idea to implementation" },
    { key: "discussions", title: "Community discussions", source: "Reddit",        method: :reddit,
      description: "Opinions, comparisons and gotchas from developers" },
    { key: "blockers",    title: "Common blockers",       source: "StackOverflow", method: :stackoverflow,
      description: "Problems you are likely to hit, before you hit them" }
  ].freeze

  def self.call(query)
    cache_key = "search:v1:#{query.downcase}"
    cached = Rails.cache.read(cache_key)
    return cached if cached

    results = Fanout.run(SECTIONS.to_h { |s| [s[:key], -> { guarded(s[:source]) { public_send(s[:method], query) } }] })
    sections = SECTIONS.map do |s|
      r = results[s[:key]]
      s.slice(:key, :title, :description, :source).merge(items: r[:value] || [], error: r[:error].present?)
    end
    response = { query: query, sections: sections }

    # Only remember complete answers, so a temporary outage isn't served for 30 minutes.
    Rails.cache.write(cache_key, response, expires_in: 30.minutes) if sections.none? { |s| s[:error] }
    response
  end

  class SourceDown < StandardError; end

  # After a source fails, skip it for a minute instead of waiting for its timeout on every search.
  def self.guarded(source)
    raise SourceDown, "#{source} was unavailable moments ago" if Rails.cache.exist?("search_down:#{source}")

    ArticleSanitizer.safe_items(yield)
  rescue HttpClient::Error
    Rails.cache.write("search_down:#{source}", true, expires_in: 1.minute)
    raise
  end

  def self.github(query)
    headers = { "Accept" => "application/vnd.github+json" }
    headers["Authorization"] = "Bearer #{ENV['GITHUB_TOKEN']}" if ENV["GITHUB_TOKEN"].present?
    url = "https://api.github.com/search/repositories?q=#{CGI.escape(query)}&sort=stars&order=desc&per_page=#{PER_SOURCE}"
    HttpClient.get_json(url, headers: headers).fetch("items", []).map do |r|
      {
        id: r["id"].to_s, title: r["full_name"], url: r["html_url"], source: "GitHub",
        description: r["description"].presence || "No description",
        meta: "★ #{number(r['stargazers_count'])} · #{number(r['forks_count'])} forks",
        tags: [r["language"]].compact, author: r.dig("owner", "login"), date: nil
      }
    end
  end

  def self.devto(query)
    HttpClient.get_json("https://dev.to/api/articles/search?q=#{CGI.escape(query)}&per_page=#{PER_SOURCE}").map do |a|
      {
        id: a["id"].to_s, title: a["title"], url: a["url"].presence || "https://dev.to#{a['path']}",
        source: "Dev.to", description: a["description"].to_s,
        meta: "♥ #{a['positive_reactions_count'] || a['public_reactions_count'] || 0}",
        tags: TrendFetcher.split_tags(a["tag_list"]), author: a.dig("user", "name"), date: a["readable_publish_date"]
      }
    end
  end

  def self.reddit(query)
    url = "https://www.reddit.com/search.json?q=#{CGI.escape(query)}&limit=#{PER_SOURCE}&sort=relevance&type=link"
    HttpClient.get_json(url).dig("data", "children").to_a.map do |c|
      p = c["data"]
      {
        id: p["id"], title: CGI.unescapeHTML(p["title"].to_s), url: "https://www.reddit.com#{p['permalink']}",
        source: "Reddit", description: "#{p['subreddit_name_prefixed']} · #{p['selftext'].to_s.squish.first(160)}".strip,
        meta: "↑ #{number(p['score'])} · #{number(p['num_comments'])} comments",
        tags: [], author: p["author"], date: nil
      }
    end
  end

  def self.stackoverflow(query)
    url = "https://api.stackexchange.com/2.3/search/advanced?q=#{CGI.escape(query)}&site=stackoverflow&pagesize=#{PER_SOURCE}&sort=relevance&order=desc"
    HttpClient.get_json(url).fetch("items", []).map do |q|
      {
        id: q["question_id"].to_s, title: CGI.unescapeHTML(q["title"].to_s), url: q["link"], source: "StackOverflow",
        description: "Score #{q['score']}", meta: q["answer_count"].to_i.positive? ? "#{q['answer_count']} answers" : "Unanswered",
        tags: Array(q["tags"]).first(4), author: nil, date: nil
      }
    end
  end

  def self.number(n)
    ActiveSupport::NumberHelper.number_to_delimited(n.to_i)
  end
end
