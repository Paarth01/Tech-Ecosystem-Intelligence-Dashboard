require "net/http"
require "json"
require "zlib"

# Tiny wrapper around Net::HTTP so the rest of the code can just call get / get_json.
class HttpClient
  class Error < StandardError
    attr_reader :status
    def initialize(message, status = nil)
      super(message)
      @status = status
    end
  end

  MAX_BYTES = 2 * 1024 * 1024   # no upstream answer is allowed to fill the server's memory

  USER_AGENT = "Mozilla/5.0 (compatible; TechEcosystemDashboard/1.0)".freeze

  def self.get(url, headers: {}, timeout: 5)
    request(Net::HTTP::Get, url, nil, headers, timeout)
  end

  def self.get_json(url, headers: {}, timeout: 5)
    JSON.parse(get(url, headers: { "Accept" => "application/json" }.merge(headers), timeout: timeout))
  rescue JSON::ParserError
    raise Error, "#{URI(url).host} returned invalid JSON"
  end

  def self.post_json(url, body, headers: {}, timeout: 60)
    all = { "Content-Type" => "application/json" }.merge(headers)
    JSON.parse(request(Net::HTTP::Post, url, body.to_json, all, timeout))
  rescue JSON::ParserError
    raise Error, "#{URI(url).host} returned invalid JSON"
  end

  def self.request(klass, url, body, headers, timeout)
    uri = URI(url)
    req = klass.new(uri)
    req["User-Agent"] = USER_AGENT
    headers.each { |k, v| req[k] = v }
    req.body = body if body

    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                    open_timeout: 3, read_timeout: timeout) do |http|
      http.request(req) do |res|
        raise Error.new("#{uri.host} responded with #{res.code}", res.code.to_i) unless res.is_a?(Net::HTTPSuccess)

        return read_limited(res, uri)
      end
    end
  rescue Timeout::Error, SystemCallError, SocketError, OpenSSL::SSL::SSLError,
         IOError, Net::ProtocolError, Net::HTTPBadResponse, Zlib::Error => e
    # Every network failure (including a connection that closes half way) becomes HttpClient::Error,
    # so callers only need to handle one kind of error.
    raise Error, "#{uri&.host}: #{e.message}"
  end
  private_class_method :request

  # Reads the body, giving up if it is larger than MAX_BYTES.
  def self.read_limited(res, uri)
    raise Error, "#{uri.host} sent too much data" if res["Content-Length"].to_i > MAX_BYTES

    buffer = +""
    res.read_body do |chunk|
      buffer << chunk
      raise Error, "#{uri.host} sent too much data" if buffer.bytesize > MAX_BYTES
    end
    buffer.force_encoding(Encoding::UTF_8)
  end
  private_class_method :read_limited
end
