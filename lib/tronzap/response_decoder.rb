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

      check_api_error(document, status, body) unless parse_error
      raise http_error(status, body, response.headers) unless (200..299).cover?(status)

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

    def check_api_error(document, status, body)
      unless document.is_a?(Hash)
        raise ApiError.new(UNKNOWN_API_ERROR, code: ErrorCode::AUTH_ERROR, status: status, response_body: body)
      end

      code = code(document["code"])
      return if code&.zero?

      raise ApiError.new(
        string(document["error"]) || UNKNOWN_API_ERROR,
        code: code || ErrorCode::AUTH_ERROR,
        status: status,
        response_body: body,
        error_key: string(document["key"]),
        request_id: string(document["request_id"])
      )
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

    def http_error(status, body, headers)
      case status
      when 429
        RateLimitError.new("Too many requests (HTTP 429)", status: status, response_body: body,
                                                           retry_after: retry_after(headers))
      when 401, 403 then UnauthorizedError.new("Unauthorized (HTTP #{status})", status: status, response_body: body)
      when 500.. then ServerError.new("Server error (HTTP #{status})", status: status, response_body: body)
      else HttpError.new("HTTP error #{status}", status: status, response_body: body)
      end
    end

    def retry_after(headers)
      value = headers.to_h.find { |name, _| name.to_s.casecmp?("retry-after") }&.last
      value = value.first if value.is_a?(Array)
      return nil unless value.is_a?(String)

      value = value.strip
      return value.to_f if value.match?(/\A\d+(\.\d+)?\z/)

      [Time.httpdate(value) - Time.now, 0.0].max
    rescue ArgumentError
      nil
    end
  end
end
