class SavedArticle < ApplicationRecord
  MAX_PER_USER = 500

  belongs_to :user

  validates :title, presence: true, length: { maximum: 300 }
  validates :description, length: { maximum: 1000 }
  validates :url, presence: true, length: { maximum: 2000 },
                  format: { with: %r{\Ahttps?://\S+\z}i, message: "must start with http:// or https://" },
                  uniqueness: { scope: :user_id }
  validate :under_limit, on: :create

  def as_item
    as_json(only: %i[id title url source description meta author date tags created_at])
  end

  private

  def under_limit
    return unless user && user.saved_articles.count >= MAX_PER_USER
    errors.add(:base, "You can save up to #{MAX_PER_USER} articles. Remove some to save more.")
  end
end
