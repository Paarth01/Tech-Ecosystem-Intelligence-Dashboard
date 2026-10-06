# Sends unexpected errors to a chat or alerting webhook (Slack, Discord and similar accept {"text": ...}).
# Set ERROR_WEBHOOK_URL to turn it on. Rails reports every unhandled exception to its error
# reporter, and this class is subscribed to it (see config/initializers/error_reporting.rb).
class ErrorWebhook
  MAX_PER_HOUR = 20   # a broken page shouldn't flood the channel

  attr_reader :thread

  def report(error, handled:, severity:, context: {}, source: nil)
    return if handled
    url = ENV["ERROR_WEBHOOK_URL"].presence or return
    return if Throttle.hit("error-webhook:#{Time.current.to_i / 3600}", within: 1.hour) > MAX_PER_HOUR

    text = "#{Rails.env}: #{error.class}: #{error.message.to_s.first(300)}"
    text += "\n#{Array(error.backtrace).first(3).join("\n")}" if error.backtrace
    # Delivered in the background so a slow webhook never slows down a request.
    @thread = Thread.new do
      HttpClient.post_json(url, { text: text }, timeout: 5)
    rescue StandardError => e
      Rails.logger.warn("[error_webhook] could not deliver: #{e.message}")
    end
  end
end
