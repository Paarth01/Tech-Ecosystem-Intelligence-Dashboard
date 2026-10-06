# Groups items by technology and scores each one.
#
# score = (sum over the items that mention it of: source weight * engagement factor)
#         * (1 + log2(source_count) * 0.8)
#
# The engagement factor is 0.5 for an item nobody engaged with and 1.5 for the most engaged item on
# its own source (stars this week, points, reactions...). Comparing within a source keeps GitHub's big
# numbers from drowning out Hacker News. A technology seen on several independent platforms
# outranks one that is only repeated on a single platform.
class TrendAggregator
  WEIGHTS = { "GitHub" => 1.5, "HackerNews" => 1.2, "StackOverflow" => 1.0, "Dev.to" => 0.8, "Lobsters" => 0.8 }.freeze

  # Adds :topics and :ecosystems to every item (in place) and returns the ranked topic list.
  def self.call(items)
    topics = {}
    top_engagement = items.group_by { |i| i[:source] }.transform_values { |list| list.map { |i| i[:engagement].to_i }.max.to_i }

    items.each do |item|
      tags = TagNormalizer.tags_for(item[:tags], "#{item[:title]} #{item[:description]}")
      item[:topics] = tags
      item[:ecosystems] = TagNormalizer.ecosystems_for(tags)

      tags.each do |tag|
        topic = (topics[tag] ||= { tag: tag, mentions: [], base: 0.0 })
        topic[:mentions] << item
        topic[:base] += WEIGHTS.fetch(item[:source], 1.0) * engagement_factor(item, top_engagement[item[:source]])
      end
    end

    topics.values.map { |t| build_topic(t) }.sort_by { |t| -t[:score] }
  end

  def self.engagement_factor(item, top)
    return 1.0 unless top.positive? && item[:engagement]
    0.5 + item[:engagement].to_f / top
  end
  private_class_method :engagement_factor

  def self.build_topic(topic)
    source_count = topic[:mentions].map { |m| m[:source] }.uniq.size
    {
      name: TagNormalizer.display(topic[:tag]),
      tag: topic[:tag],
      score: (topic[:base] * (1 + Math.log2(source_count) * 0.8)).round(1),
      source_count: source_count,
      mention_count: topic[:mentions].size,
      ecosystems: TagNormalizer.ecosystems_for([topic[:tag]]),
      mentions: topic[:mentions].first(4).map { |m| m.slice(:title, :url, :source) }
    }
  end
  private_class_method :build_topic
end
