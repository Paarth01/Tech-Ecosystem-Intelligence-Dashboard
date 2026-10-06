# One signed-in browser. The browser holds a random token in an HttpOnly cookie;
# the database only stores its SHA-256 hash, so a database leak does not leak logins.
class Session < ApplicationRecord
  TTL = 30.days   # sliding: every use pushes expiry out

  belongs_to :user

  # True when this request slid the expiry forward (the controller then refreshes the cookie too).
  attr_accessor :renewed

  def self.digest(token)
    Digest::SHA256.hexdigest(token.to_s)
  end

  # Creates a session and returns the raw token (it is never stored).
  def self.start(user)
    where("last_used_at < ?", TTL.ago).delete_all   # tidy up expired sessions
    token = SecureRandom.urlsafe_base64(32)
    user.sessions.create!(token_digest: digest(token), last_used_at: Time.current)
    token
  end

  def self.find_by_token(token)
    return nil if token.blank?

    session = where("last_used_at > ?", TTL.ago).find_by(token_digest: digest(token))
    if session && session.last_used_at < 1.day.ago
      session.update_column(:last_used_at, Time.current)
      session.renewed = true
    end
    session
  end
end
