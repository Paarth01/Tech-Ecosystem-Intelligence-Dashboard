require "test_helper"

class ThrottleTest < ActiveSupport::TestCase
  test "counts hits, clears, and never stores raw values in keys" do
    assert_equal 0, Throttle.count("k")
    assert_equal 1, Throttle.hit("k", within: 1.hour)
    assert_equal 2, Throttle.hit("k", within: 1.hour)
    assert_equal 2, Throttle.count("k")
    Throttle.clear("k")
    assert_equal 0, Throttle.count("k")

    assert_equal Throttle.fingerprint("Ada@Example.com"), Throttle.fingerprint("ada@example.com")
    assert_not_includes Throttle.fingerprint("ada@example.com"), "ada"
  end
end

class ErrorWebhookTest < ActiveSupport::TestCase
  def capture_posts
    posts = []
    stub_singleton(HttpClient, :post_json, ->(url, body, **_) { posts << [url, body] }) { yield posts }
  end

  def report(webhook, error, handled: false)
    webhook.report(error, handled: handled, severity: :error, context: {})
    webhook.thread&.join
  end

  test "posts unhandled errors to the webhook" do
    capture_posts do |posts|
      with_env("ERROR_WEBHOOK_URL" => "https://hooks.example.com/abc") do
        report(ErrorWebhook.new, RuntimeError.new("boom"))
      end
      url, body = posts.first
      assert_equal "https://hooks.example.com/abc", url
      assert_includes body[:text], "RuntimeError: boom"
    end
  end

  test "ignores handled errors and does nothing without a URL" do
    capture_posts do |posts|
      with_env("ERROR_WEBHOOK_URL" => "https://hooks.example.com/abc") { report(ErrorWebhook.new, RuntimeError.new("x"), handled: true) }
      with_env("ERROR_WEBHOOK_URL" => nil) { report(ErrorWebhook.new, RuntimeError.new("x")) }
      assert_empty posts
    end
  end

  test "sends at most 20 an hour" do
    capture_posts do |posts|
      with_env("ERROR_WEBHOOK_URL" => "https://hooks.example.com/abc") do
        webhook = ErrorWebhook.new
        25.times { report(webhook, RuntimeError.new("again")) }
      end
      assert_equal ErrorWebhook::MAX_PER_HOUR, posts.size
    end
  end

  test "a failing webhook never raises into the request" do
    stub_singleton(HttpClient, :post_json, ->(*_a, **_k) { raise HttpClient::Error, "down" }) do
      with_env("ERROR_WEBHOOK_URL" => "https://hooks.example.com/abc") { report(ErrorWebhook.new, RuntimeError.new("boom")) }
    end
  end

  test "works as a subscriber of Rails' own error reporter" do
    capture_posts do |posts|
      with_env("ERROR_WEBHOOK_URL" => "https://hooks.example.com/abc") do
        webhook = ErrorWebhook.new
        Rails.error.subscribe(webhook)
        begin
          Rails.error.report(RuntimeError.new("via rails"), handled: false)
          webhook.thread&.join
        ensure
          Rails.error.unsubscribe(webhook)
        end
      end
      assert_includes posts.first.last[:text], "via rails"
    end
  end
end

# VACUUM (used by the backup) can't run inside the transaction tests normally use.
class BackupTaskTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  DIR = Rails.root.join("backups")

  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("db:backup")
    FileUtils.rm_rf(DIR)
  end
  teardown { FileUtils.rm_rf(DIR) }

  test "writes a readable copy of the database and keeps only the newest ones" do
    with_env("KEEP" => "2") do
      3.times do
        Rake::Task["db:backup"].reenable
        capture_io { Rake::Task["db:backup"].invoke }
      end
    end
    files = Dir[DIR.join("*.sqlite3")]
    assert_equal 2, files.size
    copy = SQLite3::Database.new(files.first, readonly: true)
    assert_equal 0, copy.execute("SELECT count(*) FROM users").first.first
    assert_includes copy.execute("SELECT name FROM sqlite_master WHERE type = 'table'").flatten, "saved_articles"
  end
end
