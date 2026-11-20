# frozen_string_literal: true

module Tronzap
  # Turns an HTTP response into a result or the matching {Error}.
  #
  # @api private
  module ResponseDecoder
    UNKNOWN_API_ERROR = "Unknown API error"
    private_constant :UNKNOWN_API_ERROR

    module_function

    # The API code takes precedence over the HTTP status: some API errors arrive with 2xx, others with 4xx/5xx.
    #
    # @param response [#status, #headers, #body]
    # @yieldparam result [Object] the parsed +result+ field
    # @return [Object] what the block returns
    def decode(response)
      status = response.status.to_i
      body = text(response.body)
      document, parse_error = parse(body)

      retry_after = retry_after(response.headers, parse_error ? nil : document)
      check_api_error(document, status, body, retry_after) unless parse_error
      raise http_error(status, body, retry_after) unless (200..299).cover?(status)

      result = result(document, parse_error, status, body)
      begin
        yield result
      rescue Coerce::Error => e
        raise invalid("Unexpected result in response: #{e.message}", status, body)
      end
    end

    def result(document, parse_error, status, body)
      raise invalid("Invalid JSON response: #{parse_error.message}", status, body) if parse_error

      result = document["result"]
      raise invalid("Missing result in response", status, body) if result.nil?

      result
    end

    def invalid(message, status, body)
      InvalidResponseError.new(message, status: status, response_body: body)
    end

    def text(body)
      text = body.to_s.dup.force_encoding(Encoding::UTF_8)
      text.valid_encoding? ? text.freeze : text.scrub.freeze
    end

    def parse(body)
      [JSON.parse(body, decimal_class: BigDecimal), nil]
    rescue JSON::ParserError, EncodingError => e
      [nil, e]
    end

    # @param response [#status, #headers, #body]
    # @return [Boolean] whether the status is 2xx and the body is +text/csv+
    def csv?(response)
      (200..299).cover?(response.status.to_i) &&
        header(response.headers, "content-type").to_s.split(";").first.to_s.strip.casecmp?("text/csv")
    end

    def check_api_error(document, status, body, retry_after)
      unless document.is_a?(Hash)
        raise ApiError.new(UNKNOWN_API_ERROR, code: ErrorCode::AUTH_ERROR, status: status, response_body: body)
      end

      code = code(document["code"])
      return if code&.zero?

      raise api_error(
        string(document["error"]) || UNKNOWN_API_ERROR,
        code: code || ErrorCode::AUTH_ERROR,
        status: status,
        response_body: body,
        error_key: string(document["key"]),
        request_id: string(document["request_id"]),
        result: document["result"],
        retry_after: retry_after
      )
    end

    def api_error(message, **details)
      result = details[:result]
      if result.is_a?(Hash)
        case details[:code]
        when ErrorCode::BULK_PRICE_CHANGED
          return BulkPriceChangedError.new(message, calculation: Responses::BulkCalculation.from_api(result),
                                                    **details)
        when ErrorCode::BULK_NO_VALID_ITEMS
          return BulkNoValidItemsError.new(message, rejected: Models::BulkRejectedRow.list_from_api(result["rejected"]),
                                                    **details)
        end
      end
      ApiError.new(message, **details)
    rescue Coerce::Error
      ApiError.new(message, **details)
    end

    def code(value)
      case value
      when Integer then value
      when String then value.strip.match?(/\A[+-]?\d+\z/) ? value.to_i : nil
      end
    end

    def string(value)
      case value
      when String then value
      when Integer then value.to_s
      when BigDecimal then value.to_s("F")
      end
    end

    def http_error(status, body, retry_after)
      details = { status: status, response_body: body, retry_after: retry_after }
      case status
      when 429 then RateLimitError.new("Too many requests (HTTP 429)", **details)
      when 401, 403 then UnauthorizedError.new("Unauthorized (HTTP #{status})", **details)
      when 500.. then ServerError.new("Server error (HTTP #{status})", **details)
      else HttpError.new("HTTP error #{status}", **details)
      end
    end

    def retry_after(headers, document)
      retry_after_header(header(headers, "retry-after")) || retry_after_field(document)
    end

    def retry_after_header(value)
      return nil unless value.is_a?(String)

      value = value.strip
      return value.to_f if value.match?(/\A\d+(\.\d+)?\z/)

      [Time.httpdate(value) - Time.now, 0.0].max
    rescue ArgumentError
      nil
    end

    def retry_after_field(document)
      value = document["retry_after"] if document.is_a?(Hash)
      value.to_f if value.is_a?(Integer) && !value.negative?
    end

    def header(headers, name)
      value = headers.to_h.find { |key, _| key.to_s.casecmp?(name) }&.last
      value.is_a?(Array) ? value.first : value
    end
  end
end
