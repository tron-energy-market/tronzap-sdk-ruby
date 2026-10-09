# frozen_string_literal: true

module Tronzap
  # The base class of every failure of a TronZap API call.
  #
  # Invalid arguments are not API failures: they raise +ArgumentError+ before anything is sent.
  class Error < StandardError; end

  # The API rejected the request with a non-zero error code.
  #
  # The API reports some errors with a 2xx status and others with 4xx or 5xx, so this error takes precedence over
  # {HttpError} whenever the response carries an error code.
  class ApiError < Error
    # @return [Integer] the numeric error code, one of the {ErrorCode} constants or a code this SDK does not know
    attr_reader :code

    # @return [String, nil] the error key, for example +invalid_tron_address+ or
    #   +invalid_tron_address.from_address+
    attr_reader :error_key

    # @return [String, nil] the ID the API assigned to the request. Quote it when contacting support.
    attr_reader :request_id

    # @return [Integer] the HTTP status of the response
    attr_reader :status

    # @return [String] the raw response body
    attr_reader :response_body

    # @param message [String] the error message from the API
    # @param code [Integer] the numeric error code
    # @param status [Integer] the HTTP status of the response
    # @param response_body [String] the raw response body
    # @param error_key [String, nil] the error key
    # @param request_id [String, nil] the request ID
    def initialize(message, code:, status:, response_body:, error_key: nil, request_id: nil)
      super(message)
      @code = code
      @status = status
      @response_body = response_body
      @error_key = error_key
      @request_id = request_id
    end
  end

  # The API answered with a non-2xx status and no error code in the body.
  class HttpError < Error
    # @return [Integer] the HTTP status of the response
    attr_reader :status

    # @return [String] the raw response body
    attr_reader :response_body

    # @param message [String] the error message
    # @param status [Integer] the HTTP status of the response
    # @param response_body [String] the raw response body
    def initialize(message, status:, response_body:)
      super(message)
      @status = status
      @response_body = response_body
    end
  end

  # The API answered with HTTP 429: too many requests. Back off and retry.
  class RateLimitError < HttpError
    # @return [Float, nil] seconds the API asked to wait before retrying, from the +Retry-After+ header
    attr_reader :retry_after

    # @param message [String] the error message
    # @param status [Integer] the HTTP status of the response
    # @param response_body [String] the raw response body
    # @param retry_after [Float, nil] seconds to wait before retrying
    def initialize(message, status:, response_body:, retry_after: nil)
      super(message, status: status, response_body: response_body)
      @retry_after = retry_after
    end
  end

  # The API answered with HTTP 401 or 403: check the API token and secret.
  class UnauthorizedError < HttpError; end

  # The API answered with an HTTP 5xx status. Usually transient.
  class ServerError < HttpError; end

  # The API answered with a 2xx status, but the SDK could not read the response.
  class InvalidResponseError < Error
    # @return [Integer, nil] the HTTP status of the response, +nil+ when the body was rejected before the status was
    #   known
    attr_reader :status

    # @return [String] the raw response body, empty when it was too large to keep
    attr_reader :response_body

    # @param message [String] the error message
    # @param status [Integer, nil] the HTTP status of the response
    # @param response_body [String] the raw response body
    def initialize(message, status:, response_body:)
      super(message)
      @status = status
      @response_body = response_body
    end
  end

  # No response arrived: the request failed below the HTTP level.
  class NetworkError < Error; end

  # The connection could not be established: the host name did not resolve or the connection was refused.
  class ConnectionError < NetworkError; end

  # The request did not complete within the configured timeout.
  class TimeoutError < NetworkError; end

  # The TLS handshake failed, for example because the server certificate is not trusted.
  class SslError < NetworkError; end

  # Error codes the TronZap API reports in {ApiError#code}.
  module ErrorCode
    # Authentication error: check the API token and that the signature is calculated correctly.
    AUTH_ERROR = 1
    # Invalid service or parameters: check the service name and the parameters.
    INVALID_SERVICE_OR_PARAMS = 2
    # Wallet not found: verify the wallet address, or contact support if you believe this is an error.
    WALLET_NOT_FOUND = 5
    # Insufficient funds: top up the account or request a smaller amount.
    INSUFFICIENT_FUNDS = 6
    # Invalid TRON address: it should be a valid 34-character TRON address. Also reported when the address already
    # has an active subscription.
    INVALID_TRON_ADDRESS = 10
    # Invalid energy amount.
    INVALID_ENERGY_AMOUNT = 11
    # Invalid duration.
    INVALID_DURATION = 12
    # Transaction or subscription not found: check the transaction ID or external ID. The API reports this code
    # under the key +subscription_not_found+.
    TRANSACTION_NOT_FOUND = 20
    # Cannot stop subscription, for example because it has a transactions limit.
    CANNOT_STOP_SUBSCRIPTION = 21
    # Address not activated: activate it first with an address activation transaction.
    ADDRESS_NOT_ACTIVATED = 24
    # Address already activated. No action is needed.
    ADDRESS_ALREADY_ACTIVATED = 25
    # AML check not found: check the ID or run the AML check again.
    AML_CHECK_NOT_FOUND = 30
    # The service is temporarily unavailable.
    SERVICE_NOT_AVAILABLE = 35
    # Invalid bandwidth amount.
    INVALID_BANDWIDTH_AMOUNT = 50
    # Internal server error. Contact support if it persists.
    INTERNAL_SERVER_ERROR = 500
  end
end
