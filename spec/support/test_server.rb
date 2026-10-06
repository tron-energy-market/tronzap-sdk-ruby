# frozen_string_literal: true

require "openssl"
require "socket"
require "tempfile"

# A real HTTP server on 127.0.0.1 that records what it receives and answers with whatever the test configures.
#
# A handler returns [status, headers, body], or one of the actions :hang (never answer) and :close (drop the
# connection without answering).
class TestServer
  Request = Data.define(:http_method, :path, :headers, :body)

  REASONS = Hash.new("Status").merge(200 => "OK", 401 => "Unauthorized", 429 => "Too Many Requests",
                                     500 => "Internal Server Error").freeze

  attr_reader :port

  def initialize(tls: false)
    @tcp = TCPServer.new("127.0.0.1", 0)
    @port = @tcp.addr[1]
    @tls = tls
    @requests = []
    @mutex = Mutex.new
    @handler = ->(_request) { [200, {}, '{"code":0,"result":{}}'] }
    @threads = []
    @acceptor = Thread.new { accept_loop }
  end

  def url
    "#{@tls ? "https" : "http"}://127.0.0.1:#{port}"
  end

  def respond(status = 200, body = "", headers = {})
    @handler = ->(_request) { [status, headers, body] }
  end

  def respond_json(payload, status: 200, headers: {})
    respond(status, JSON.generate(payload), headers)
  end

  def handle(&block)
    @handler = block
  end

  def requests
    @mutex.synchronize { @requests.dup }
  end

  def last_request
    requests.last
  end

  def stop
    @acceptor.kill
    @threads.each(&:kill)
    @tcp.close unless @tcp.closed?
  end

  def self.certificate
    @certificate ||= begin
      key = OpenSSL::PKey::EC.generate("prime256v1")
      cert = OpenSSL::X509::Certificate.new
      cert.version = 2
      cert.serial = 1
      cert.subject = cert.issuer = OpenSSL::X509::Name.parse("/CN=127.0.0.1")
      cert.public_key = key
      cert.not_before = Time.now - 60
      cert.not_after = Time.now + 3600
      extensions = OpenSSL::X509::ExtensionFactory.new(cert, cert)
      cert.add_extension(extensions.create_extension("subjectAltName", "IP:127.0.0.1,DNS:localhost"))
      cert.add_extension(extensions.create_extension("basicConstraints", "CA:TRUE", true))
      cert.sign(key, OpenSSL::Digest.new("SHA256"))
      [cert, key]
    end
  end

  def self.ca_file
    @ca_file ||= Tempfile.new(["tronzap-test-ca", ".pem"]).tap do |file|
      file.write(certificate.first.to_pem)
      file.flush
    end
  end

  private

  def accept_loop
    loop do
      socket = @tcp.accept
      @threads << Thread.new { serve(socket) }
    end
  rescue IOError, Errno::EBADF
    nil
  end

  def serve(socket)
    socket = tls_wrap(socket) if @tls
    request = read_request(socket)
    @mutex.synchronize { @requests << request }
    answer(socket, @handler.call(request))
  rescue OpenSSL::SSL::SSLError, IOError, SystemCallError
    nil
  ensure
    socket.close unless socket.nil? || socket.closed?
  end

  def tls_wrap(socket)
    cert, key = self.class.certificate
    context = OpenSSL::SSL::SSLContext.new
    context.cert = cert
    context.key = key
    ssl = OpenSSL::SSL::SSLSocket.new(socket, context)
    ssl.sync_close = true
    ssl.accept
    ssl
  end

  def read_request(socket)
    method, path = socket.gets.to_s.split
    headers = {}
    while (line = socket.gets) && line != "\r\n"
      name, value = line.split(":", 2)
      headers[name.strip.downcase] = value.strip
    end
    body = headers["content-length"] ? socket.read(headers["content-length"].to_i) : ""
    Request.new(http_method: method, path: path, headers: headers.freeze, body: body.b.freeze)
  end

  def answer(socket, action)
    case action
    when :hang then sleep
    when :close then nil
    else
      status, headers, body = action
      body = body.b
      head = ["HTTP/1.1 #{status} #{REASONS[status]}", "Content-Length: #{body.bytesize}", "Connection: close"]
      headers.each { |name, value| head << "#{name}: #{value}" }
      socket.write("#{head.join("\r\n")}\r\n\r\n")
      socket.write(body)
    end
  end
end
