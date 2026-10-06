# frozen_string_literal: true

require "uri"

module Tronzap
  # Settings of a {Client}. Every client owns its configuration: the client validates and freezes it when it is
  # created, so there is no shared or global state.
  #
  # @example In the constructor
  #   Tronzap::Client.new(api_token: token, api_secret: secret, timeout: 10)
  #
  # @example In a block
  #   Tronzap::Client.new do |config|
  #     config.api_token = token
  #     config.api_secret = secret
  #     config.base_url = "api.tronzap.com"
  #   end
  class Configuration
    # The production API endpoint.
    DEFAULT_BASE_URL = "https://api.tronzap.com"

    # The default timeout, in seconds.
    DEFAULT_TIMEOUT = 30

    # @return [String] the API token from your TronZap dashboard, sent as a bearer token. Required.
    attr_accessor :api_token

    # @return [String] the API secret from your TronZap dashboard, used to sign every request body. It is never
    #   sent. Required.
    attr_accessor :api_secret

    # @return [String] the API endpoint. A bare host such as +api.tronzap.com+ gets the +https+ scheme and a
    #   trailing slash is removed. Give an explicit scheme to opt out, for example +http://localhost:8080+.
    attr_accessor :base_url

    # @return [Numeric] seconds allowed for connecting and for each read or write of a request
    attr_accessor :timeout

    # @return [String] the +User-Agent+ header
    attr_accessor :user_agent

    # @return [#call] the HTTP adapter, see {HttpAdapter}
    attr_accessor :adapter

    # @param api_token [String, nil]
    # @param api_secret [String, nil]
    # @param base_url [String]
    # @param timeout [Numeric]
    # @param user_agent [String]
    # @param adapter [#call, nil] defaults to {HttpAdapter::NetHttp}
    def initialize(api_token: nil, api_secret: nil, base_url: DEFAULT_BASE_URL, timeout: DEFAULT_TIMEOUT,
                   user_agent: "tronzap-sdk-ruby/#{VERSION}", adapter: nil)
      @api_token = api_token
      @api_secret = api_secret
      @base_url = base_url
      @timeout = timeout
      @user_agent = user_agent
      @adapter = adapter
    end

    # Validates and normalizes the settings, then freezes the configuration.
    #
    # @return [self]
    # @raise [ArgumentError] when a setting is invalid
    def finalize!
      @api_token = credential(@api_token, "api_token")
      @api_secret = credential(@api_secret, "api_secret")
      @base_url = self.class.normalize_base_url(@base_url)
      @timeout = validate_timeout(@timeout)
      @user_agent = validate_user_agent(@user_agent)
      @adapter = validate_adapter(@adapter || HttpAdapter::NetHttp.new)
      freeze
    end

    # @return [String] a description that leaves out the credentials
    def inspect
      "#<#{self.class.name} base_url=#{@base_url.inspect} timeout=#{@timeout.inspect} " \
        "user_agent=#{@user_agent.inspect} adapter=#{@adapter.class.name}>"
    end

    # @param base_url [String]
    # @return [String] the URL with a scheme and without a trailing slash
    # @raise [ArgumentError] when it is not an http or https URL
    def self.normalize_base_url(base_url)
      raise ArgumentError, "base_url must be a String" unless base_url.is_a?(String)

      normalized = base_url.strip
      raise ArgumentError, "base_url must not be blank" if normalized.empty?

      normalized = "https://#{normalized.delete_prefix("/")}" unless normalized.include?("://")
      normalized = normalized.sub(%r{/+\z}, "")
      check_url(normalized, base_url)
      normalized
    end

    def self.check_url(url, original)
      uri = begin
        URI.parse(url)
      rescue URI::InvalidURIError
        raise ArgumentError, "base_url is not a valid URL: #{original}"
      end
      raise ArgumentError, "base_url must use http or https: #{original}" unless %w[http https].include?(uri.scheme)
      raise ArgumentError, "base_url has no host: #{original}" if uri.host.nil? || uri.host.empty?
      return unless uri.query || uri.fragment

      raise ArgumentError, "base_url must not have a query or fragment: #{original}"
    end
    private_class_method :check_url

    private

    def credential(value, name)
      raise ArgumentError, "#{name} is required" unless value.is_a?(String) && !value.strip.empty?

      value.dup.freeze
    end

    def validate_timeout(value)
      unless value.is_a?(Numeric) && value.real? && value.positive? && value.to_f.finite?
        raise ArgumentError, "timeout must be a positive number of seconds, got #{value.inspect}"
      end

      value
    end

    def validate_user_agent(value)
      unless value.is_a?(String) && !value.strip.empty? && !value.match?(/[\r\n]/)
        raise ArgumentError, "user_agent must be a non-blank single-line String"
      end

      value.dup.freeze
    end

    def validate_adapter(value)
      raise ArgumentError, "adapter must respond to #call" unless value.respond_to?(:call)

      value
    end
  end
end
