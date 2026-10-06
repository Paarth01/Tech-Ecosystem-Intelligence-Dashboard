class User < ApplicationRecord
  has_secure_password

  has_many :sessions, dependent: :destroy
  has_many :email_tokens, dependent: :destroy
  has_many :saved_articles, dependent: :destroy
  has_many :comparisons, dependent: :destroy

  before_validation do
    self.email = email.to_s.strip.downcase
    # Control characters (such as line breaks) have no place in a name, and the name appears in emails.
    self.name = name.to_s.gsub(/[[:cntrl:]]/, " ").squish
  end

  validates :name, presence: true, length: { maximum: 80 }
  validates :email, presence: true, length: { maximum: 254 }, format: { with: URI::MailTo::EMAIL_REGEXP },
                    uniqueness: { case_sensitive: false }
  validates :password, length: { minimum: 8 }, allow_nil: true

  # Returns the user for a correct email and password, otherwise nil. An unknown email still
  # pays for one password check, so response time doesn't reveal which emails are registered.
  def self.sign_in(email, password)
    user = find_by(email: email.to_s.strip.downcase)
    return user.authenticate(password.to_s) || nil if user

    BCrypt::Password.new(dummy_digest).is_password?(password.to_s)
    nil
  end

  def self.dummy_digest
    @dummy_digest ||= BCrypt::Password.create("not-a-real-password", cost: bcrypt_cost)
  end

  def self.bcrypt_cost
    ActiveModel::SecurePassword.min_cost ? BCrypt::Engine::MIN_COST : BCrypt::Engine.cost
  end
  private_class_method :bcrypt_cost

  def email_verified?
    email_verified_at.present?
  end

  # Emails are sent by a background job, so the request doesn't wait for the mail server.
  def send_verification_email
    UserMailer.email_verification(id, EmailToken.issue(self, "email_verification")).deliver_later
  end

  def send_password_reset_email
    UserMailer.password_reset(id, EmailToken.issue(self, "password_reset")).deliver_later
  end

  def public_json
    { id: id, name: name, email: email, email_verified: email_verified? }
  end
end
