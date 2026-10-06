require "test_helper"
require "socket"

# Talks to a throwaway local server that misbehaves in specific ways.
class HttpClientTest < ActiveSupport::TestCase
  def serve(&handler)
    server = TCPServer.new("127.0.0.1", 0)
    @servers = (@servers || []) << server
    Thread.new do
      loop do
        client = server.accept
        Thread.new(client) do |socket|
          begin
            socket.readpartial(8192)
            handler.call(socket)
          rescue StandardError
            nil
          ensure
            socket.close rescue nil
          end
        end
      end
    rescue IOError
      nil
    end
    "http://127.0.0.1:#{server.addr[1]}/"
  end

  teardown { (@servers || []).each(&:close) }

  test "returns the body of a normal answer" do
    url = serve { |s| body = '{"a":1}'; s.write "HTTP/1.1 200 OK\r\nContent-Length: #{body.bytesize}\r\nConnection: close\r\n\r\n#{body}" }
    assert_equal({ "a" => 1 }, HttpClient.get_json(url))
  end

  test "a connection that closes without answering is an HttpClient::Error, not an EOFError" do
    assert_raises(HttpClient::Error) { HttpClient.get(serve { |_s| }) }
  end

  test "a garbled answer is an HttpClient::Error" do
    assert_raises(HttpClient::Error) { HttpClient.get(serve { |s| s.write "this is not http\r\n\r\n" }) }
  end

  test "an answer larger than the limit is refused, declared or streamed" do
    declared = serve { |s| s.write "HTTP/1.1 200 OK\r\nContent-Length: 5000000\r\nConnection: close\r\n\r\n"; s.write("x" * 1000) }
    assert_match(/too much/, assert_raises(HttpClient::Error) { HttpClient.get(declared) }.message)

    chunked = serve do |s|
      s.write "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\nConnection: close\r\n\r\n"
      40.times { s.write "%x\r\n%s\r\n" % [65_536, "y" * 65_536] }
      s.write "0\r\n\r\n"
    end
    assert_match(/too much/, assert_raises(HttpClient::Error) { HttpClient.get(chunked) }.message)
  end

  test "an error status carries the status code" do
    url = serve { |s| s.write "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n" }
    assert_equal 404, assert_raises(HttpClient::Error) { HttpClient.get(url) }.status
  end
end
