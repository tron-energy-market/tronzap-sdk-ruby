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

    # @return [Object, nil] the +result+ the API sent along with the error, as parsed JSON (numbers as +Integer+ or
    #   +BigDecimal+), or +nil+. {ErrorCode::BULK_PRICE_CHANGED} and {ErrorCode::BULK_NO_VALID_ITEMS} carry it;
    #   {BulkPriceChangedError} and {BulkNoValidItemsError} also expose it typed.
    attr_reader :result

    # @return [Float, nil] seconds to wait before retrying, from the +Retry-After+ header or the +retry_after+ field,
    #   or +nil+ when the API sent neither. {ErrorCode::RATE_LIMITED} carries it.
    attr_reader :retry_after

    # @param message [String] the error message from the API
    # @param code [Integer] the numeric error code
    # @param status [Integer] the HTTP status of the response
    # @param response_body [String] the raw response body
    # @param error_key [String, nil] the error key
    # @param request_id [String, nil] the request ID
    # @param result [Object, nil] the +result+ sent with the error
    # @param retry_after [Float, nil] seconds to wait before retrying
    def initialize(message, code:, status:, response_body:, error_key: nil, request_id: nil, result: nil,
                   retry_after: nil)
      super(message)
      @code = code
      @status = status
      @response_body = response_body
      @error_key = error_key
      @request_id = request_id
      @result = result
      @retry_after = retry_after
    end
  end

  # The price of a bulk order changed since its calculation, so the order was not started:
  # {ErrorCode::BULK_PRICE_CHANGED}. Confirm the new total of {#calculation}, then start the order with its ID.
  class BulkPriceChangedError < ApiError
    # @return [Responses::BulkCalculation] the new calculation, valid for 10 minutes
    attr_reader :calculation

    # @param message [String] the error message from the API
    # @param calculation [Responses::BulkCalculation] the new calculation
    # @param options [Hash] the keyword arguments of {ApiError#initialize}
    def initialize(message, calculation:, **)
      super(message, **)
      @calculation = calculation
    end
  end

  # No row of a bulk calculation is valid: {ErrorCode::BULK_NO_VALID_ITEMS}. Fix the rows in {#rejected}.
  class BulkNoValidItemsError < ApiError
    # @return [Array<Models::BulkRejectedRow>] the rejected rows with their row numbers and reasons
    attr_reader :rejected

    # @param message [String] the error message from the API
    # @param rejected [Array<Models::BulkRejectedRow>] the rejected rows
    # @param options [Hash] the keyword arguments of {ApiError#initialize}
    def initialize(message, rejected:, **)
      super(message, **)
      @rejected = rejected
    end
  end

  # The API answered with a non-2xx status and no error code in the body.
  class HttpError < Error
    # @return [Integer] the HTTP status of the response
    attr_reader :status

    # @return [String] the raw response body
    attr_reader :response_body

    # @return [Float, nil] seconds to wait before retrying, from the +Retry-After+ header or the +retry_after+ field,
    #   or +nil+ when the server sent neither
    attr_reader :retry_after

    # @param message [String] the error message
    # @param status [Integer] the HTTP status of the response
    # @param response_body [String] the raw response body
    # @param retry_after [Float, nil] seconds to wait before retrying
    def initialize(message, status:, response_body:, retry_after: nil)
      super(message)
      @status = status
      @response_body = response_body
      @retry_after = retry_after
    end
  end

  # HTTP 429 without an API payload, for example from a proxy. Back off and retry.
  #
  # A rate limit reported by the API arrives as {ApiError} with {ErrorCode::RATE_LIMITED}.
  class RateLimitError < HttpError; end

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
    # Bulk order not found: check the order ID or external ID. A calculation that was never started is not an order.
    BULK_NOT_FOUND = 90
    # Bulk calculation expired: call {Client#bulk_calculate} again; a calculation is valid for 10 minutes.
    BULK_EXPIRED = 91
    # The price changed since the calculation: confirm the new total of {BulkPriceChangedError#calculation}, then
    # start the order with its ID.
    BULK_PRICE_CHANGED = 92
    # Too many items: send at most 10 000 rows in one calculation.
    BULK_TOO_MANY_ITEMS = 93
    # No valid items: fix the rows in {BulkNoValidItemsError#rejected}.
    BULK_NO_VALID_ITEMS = 94
    # The resource cannot be ordered in bulk: only energy can.
    BULK_RESOURCE_NOT_SUPPORTED = 95
    # The request body is too large (HTTP 413): send fewer rows in one calculation.
    PAYLOAD_TOO_LARGE = 96
    # Too many requests (HTTP 429): wait {ApiError#retry_after} seconds, when given, and retry.
    RATE_LIMITED = 429
    # Internal server error. Contact support if it persists.
    INTERNAL_SERVER_ERROR = 500
  end
end
