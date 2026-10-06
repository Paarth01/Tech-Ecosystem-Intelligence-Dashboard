class Comparison < ApplicationRecord
  MAX_PER_USER = 100

  belongs_to :user

  validates :title, presence: true, length: { maximum: 300 }
  validates :result, presence: true, length: { maximum: 20_000 }
  validate :two_to_four_items
  validate :under_limit, on: :create

  def summary_json
    { id: id, title: title, ai_generated: ai_generated, created_at: created_at,
      item_count: Array(items).size, sources: Array(items).map { |i| i["source"] }.compact.uniq }
  end

  def full_json
    summary_json.merge(items: Array(items), result: result)
  end

  private

  def two_to_four_items
    errors.add(:items, "must contain 2 to 4 articles") unless Array(items).size.between?(2, 4)
  end

  def under_limit
    return unless user && user.comparisons.count >= MAX_PER_USER
    errors.add(:base, "You can keep up to #{MAX_PER_USER} comparisons. Delete some to save more.")
  end
end
