# frozen_string_literal: true

require "net/http"
require "openssl"
require "zlib"

module Tronzap
  # The transport a {Client} sends requests through.
  #
  # An adapter is any object with a +call+ method that takes a {Request} and returns a {Response} (or any object
  # with +status+, +headers+ and +body+). The client builds the body, signs it and parses the response; the adapter
  # only moves bytes. {NetHttp} is the default.
  #
  # Failures raised by an adapter are reported as {NetworkError} subclasses when they are standard Ruby network
  # errors: +Timeout::Error+, +OpenSSL::SSL::SSLError+, +SocketError+, +SystemCallError+, +IOError+ and the
  # +Net::HTTP+ protocol errors. An adapter built on another HTTP library should rescue that library's errors and
  # raise {TimeoutError}, {ConnectionError}, {SslError} or {NetworkError} itself.
  #
  # @example An adapter on top of Faraday
  #   class FaradayAdapter
  #     def initialize(connection) = @connection = connection
  #
  #     def call(request)
  #       response = @connection.post(request.url, request.body, request.headers) do |req|
  #         req.options.timeout = request.timeout
  #       end
  #       Tronzap::HttpAdapter::Response.new(status: response.status, headers: response.headers.to_h,
  #                                          body: response.body.to_s)
  #     rescue Faraday::TimeoutError => e
  #       raise Tronzap::TimeoutError, e.message
  #     rescue Faraday::SSLError => e
  #       raise Tronzap::SslError, e.message
  #     rescue Faraday::ConnectionFailed => e
  #       raise Tronzap::ConnectionError, e.message
  #     end
  #   end
  module HttpAdapter
    # An HTTP request to send.
    #
    # @!attribute [r] http_method
    #   @return [Symbol] the HTTP method, always +:post+
    # @!attribute [r] url
    #   @return [String] the absolute URL
    # @!attribute [r] headers
    #   @return [Hash{String => String}] the request headers
    # @!attribute [r] body
    #   @return [String] the JSON body. It is signed byte for byte, so send it unchanged.
    # @!attribute [r] timeout
    #   @return [Numeric] seconds allowed for connecting and for each read or write
    Request = Data.define(:http_method, :url, :headers, :body, :timeout)

    # An HTTP response.
    #
    # @!attribute [r] status
    #   @return [Integer] the HTTP status
    # @!attribute [r] headers
    #   @return [Hash{String => String}] the response headers; names are matched case-insensitively
    # @!attribute [r] body
    #   @return [String] the response body
    Response = Data.define(:status, :headers, :body)

    # The largest response body the default adapter reads.
    MAX_RESPONSE_BYTES = 8 * 1024 * 1024

    # The default adapter, on top of +Net::HTTP+ from the standard library.
    #
    # It opens a new connection for every request and keeps no state between requests, so it is safe to share
    # across threads. TLS certificates are always verified. Proxies are taken from the +http_proxy+ and
    # +https_proxy+ environment variables.
    class NetHttp
      # @param ca_file [String, nil] a PEM file with the certificates to trust instead of the system store
      def initialize(ca_file: nil)
        @ca_file = ca_file&.dup&.freeze
        freeze
      end

      # @param request [Request]
      # @return [Response]
      def call(request)
        uri = URI.parse(request.url)
        http = connection(uri, request.timeout)
        post = Net::HTTP::Post.new(uri.request_uri, request.headers)
        post.body = request.body

        http.start do
          http.request(post) do |response|
            return Response.new(status: response.code.to_i, headers: headers(response), body: read(response))
          end
        end
      end

      private

      def connection(uri, timeout)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"
        if http.use_ssl?
          http.verify_mode = OpenSSL::SSL::VERIFY_PEER
          http.ca_file = @ca_file if @ca_file
        end
        http.open_timeout = timeout
        http.read_timeout = timeout
        http.write_timeout = timeout
        http.ssl_timeout = timeout
        http.max_retries = 0
        http
      end

      def headers(response)
        response.each_header.to_h
      end

      def read(response)
        status = response.code.to_i
        raise too_large(status) if response.content_length.to_i > MAX_RESPONSE_BYTES

        body = +""
        response.read_body do |chunk|
          raise too_large(status) if body.bytesize + chunk.bytesize > MAX_RESPONSE_BYTES

          body << chunk
        end
        body
      end

      def too_large(status)
        InvalidResponseError.new("Response body exceeds #{MAX_RESPONSE_BYTES} bytes",
                                 status: status, response_body: "")
      end
    end

    CONNECTION_ERRORS = [
      SocketError, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ENETUNREACH, Errno::EADDRNOTAVAIL
    ].freeze
    private_constant :CONNECTION_ERRORS

    NETWORK_ERRORS = [
      OpenSSL::SSL::SSLError, Timeout::Error, IOError, SystemCallError, Net::ProtocolError, Net::HTTPBadResponse,
      Zlib::Error, *CONNECTION_ERRORS
    ].freeze
    private_constant :NETWORK_ERRORS

    # Runs the block and reports standard Ruby network failures as {NetworkError} subclasses.
    #
    # @api private
    def self.translate_errors
      yield
    rescue Tronzap::Error
      raise
    rescue *NETWORK_ERRORS => e
      raise classify(e)
    end

    def self.classify(error)
      case error
      when OpenSSL::SSL::SSLError
        SslError.new("TLS error: #{error.message}")
      when Timeout::Error, Errno::ETIMEDOUT
        TimeoutError.new("The request timed out: #{error.message}")
      when *CONNECTION_ERRORS
        ConnectionError.new("Connection failed: #{error.message}")
      else
        NetworkError.new("Network error: #{error.class}: #{error.message}")
      end
    end
    private_class_method :classify
  end
end
