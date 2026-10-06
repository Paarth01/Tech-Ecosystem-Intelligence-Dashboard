# A single-use link sent by email. The email contains a random token; only its hash is stored.
class EmailToken < ApplicationRecord
  LIFETIMES = { "password_reset" => 1.hour, "email_verification" => 3.days }.freeze

  belongs_to :user

  validates :purpose, inclusion: { in: LIFETIMES.keys }

  # Creates a token and returns the raw value to put in the email. Only one live token
  # per purpose exists for a user, so asking again invalidates the previous link.
  def self.issue(user, purpose)
    where("expires_at < ?", Time.current).delete_all
    user.email_tokens.where(purpose: purpose).destroy_all
    raw = SecureRandom.urlsafe_base64(32)
    create!(user: user, purpose: purpose, token_digest: digest(raw), expires_at: LIFETIMES.fetch(purpose).from_now)
    raw
  end

  # Returns the unexpired token record for this raw value and purpose, or nil.
  def self.find_live(raw, purpose)
    return nil if raw.blank?
    where(purpose: purpose).where("expires_at > ?", Time.current).find_by(token_digest: digest(raw))
  end

  def self.digest(raw)
    Digest::SHA256.hexdigest(raw.to_s)
  end
end
