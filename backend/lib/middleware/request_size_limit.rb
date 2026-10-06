require "stringio"

# Rejects requests whose body is larger than the limit, before Rails parses anything.
# Every legitimate request here is a few KB of JSON, so the default of 256 KB is generous.
# (Also set a limit in your reverse proxy, e.g. nginx client_max_body_size, as the first line of defence.)
class RequestSizeLimit
  DEFAULT_LIMIT = 256 * 1024

  def initialize(app, limit: ENV.fetch("MAX_REQUEST_BYTES", DEFAULT_LIMIT).to_i)
    @app = app
    @limit = limit
  end

  def call(env)
    return too_large if env["CONTENT_LENGTH"].to_i > @limit
    return too_large if chunked_without_length?(env) && body_too_big?(env)

    @app.call(env)
  end

  private

  # A chunked upload has no Content-Length to check, so read at most limit + 1 bytes and look.
  # What was read is put back, so the app still sees the whole body.
  def chunked_without_length?(env)
    env["CONTENT_LENGTH"].to_s.empty? && env["HTTP_TRANSFER_ENCODING"].to_s.downcase.include?("chunked")
  end

  def body_too_big?(env)
    input = env["rack.input"] or return false
    data = input.read(@limit + 1).to_s
    env["rack.input"] = StringIO.new(data)
    data.bytesize > @limit
  end

  def too_large
    body = '{"error":"Request is too large"}'
    [413, { "content-type" => "application/json", "content-length" => body.bytesize.to_s }, [body]]
  end
end
