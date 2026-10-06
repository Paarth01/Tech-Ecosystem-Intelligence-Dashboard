ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

class ActiveSupport::TestCase
  setup do
    Rails.cache.clear
    ActionMailer::Base.deliveries.clear
  end

  # Replaces a class method for the duration of the block (no extra gems needed).
  def stub_singleton(object, name, implementation)
    original = object.method(name)
    object.define_singleton_method(name) { |*args, **kwargs, &blk| implementation.call(*args, **kwargs, &blk) }
    yield
  ensure
    object.define_singleton_method(name, original)
  end

  def with_env(vars)
    old = vars.keys.to_h { |k| [k, ENV[k]] }
    vars.each { |k, v| ENV[k] = v }
    yield
  ensure
    old.each { |k, v| ENV[k] = v }
  end
end

# One browser: it has its own cookie jar, so two clients are two different people (or devices).
class ApiClient
  def initialize(session)
    @session = session
  end

  %i[get post patch delete].each do |verb|
    define_method(verb) do |path, params = nil, headers: {}, env: {}|
      options = { headers: { "X-Requested-With" => "XMLHttpRequest" }.merge(headers), env: env }
      options.merge!(verb == :get ? { params: params } : { params: params, as: :json }) if params
      @session.public_send(verb, path, **options)
      self
    end
  end

  def status = @session.response.status
  def json = JSON.parse(@session.response.body)
  def header(name) = @session.response.headers[name]
  def set_cookie = Array(@session.response.headers["Set-Cookie"]).join("\n")
  def cookie_value = @session.cookies["techintel_session"]
end

class ActionDispatch::IntegrationTest
  def new_client = ApiClient.new(open_session)

  # A client that has registered and is signed in.
  def signed_in(name, email = "#{name.downcase}@example.com")
    client = new_client
    client.post "/api/auth/register", { name: name, email: email, password: "password123" }
    assert_equal 201, client.status
    client
  end

  def clear_mails
    ActionMailer::Base.deliveries.clear
  end

  def mails(subject = nil)
    ActionMailer::Base.deliveries.select { |m| subject.nil? || m.subject == subject }
  end

  # The token inside the link of the newest email with this subject.
  def token_from_mail(subject)
    mails(subject).last.body.to_s[/token=([\w-]+)/, 1]
  end

  def article(n = 1)
    { title: "Article #{n}", url: "https://example.com/#{n}", source: "GitHub",
      description: "Description #{n}", meta: "+10 stars", tags: ["Ruby"], author: "someone" }
  end
end
