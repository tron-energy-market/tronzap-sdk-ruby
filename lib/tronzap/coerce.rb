# frozen_string_literal: true

module Tronzap
  # Reads loosely typed JSON values into the types the models expose.
  #
  # @api private
  module Coerce
    # A value in the response does not have the expected shape.
    class Error < StandardError; end

    EMPTY_HASH = {}.freeze
    EMPTY_ARRAY = [].freeze

    module_function

    # The API is backed by PHP, which encodes an empty associative array as [].
    def object(value, name)
      return EMPTY_HASH if value.nil? || value == EMPTY_ARRAY
      raise Error, "#{name} is not an object" unless value.is_a?(Hash)

      value
    end

    def list(value, name, &)
      return EMPTY_ARRAY if value.nil? || value == EMPTY_HASH
      raise Error, "#{name} is not an array" unless value.is_a?(Array)

      value.map(&).freeze
    end

    def text(value, name)
      case value
      when nil then ""
      when String then value
      when Integer, true, false then value.to_s
      when BigDecimal then value.to_s("F")
      else raise Error, "#{name} is not a string"
      end
    end

    def optional_text(value, name)
      result = text(value, name)
      result.empty? ? nil : result
    end

    def integer(value, name)
      return 0 if value.nil? || (value.is_a?(String) && value.strip.empty?)
      return value if value.is_a?(Integer)

      number = to_decimal(value, name)
      raise Error, "#{name} is not an integer: #{value.inspect}" unless number.frac.zero?

      number.to_i
    end

    def decimal(value, name)
      optional_decimal(value, name) || BigDecimal(0)
    end

    def optional_decimal(value, name)
      return nil if value.nil? || (value.is_a?(String) && value.strip.empty?)

      to_decimal(value, name)
    end

    # Amounts arrive as JSON numbers from some endpoints and as strings from others.
    def to_decimal(value, name)
      case value
      when BigDecimal then value
      when Integer then BigDecimal(value)
      when Float then BigDecimal(value.to_s)
      when String then parse_decimal(value, name)
      else raise Error, "#{name} is not a number: #{value.inspect}"
      end
    end

    def parse_decimal(value, name)
      number = BigDecimal(value.strip)
      raise Error, "#{name} is not a finite number: #{value.inspect}" unless number.finite?

      number
    rescue ArgumentError
      raise Error, "#{name} is not a number: #{value.inspect}"
    end

    def boolean(value, name)
      case value
      when nil, false then false
      when true then true
      when Integer, BigDecimal then !value.zero?
      when String then parse_boolean(value, name)
      else raise Error, "#{name} is not a boolean: #{value.inspect}"
      end
    end

    def parse_boolean(value, name)
      case value.strip
      when "true", "1" then true
      when "", "false", "0" then false
      else raise Error, "#{name} is not a boolean: #{value.inspect}"
      end
    end

    def decimal_map(value, name)
      object(value, name).to_h { |key, amount| [key.to_s.freeze, to_decimal(amount, "#{name}.#{key}")] }.freeze
    end

    def timestamp(value, name)
      case value
      when nil then nil
      when String then value.strip.empty? ? nil : Models::Timestamp.parse(value)
      when Integer then Models::Timestamp.parse(value.to_s)
      else raise Error, "#{name} is not a timestamp: #{value.inspect}"
      end
    end

    # Values the API may add later are reported as +:unknown+ instead of failing the response.
    def enum(value, allowed, name)
      wire = text(value, name)
      allowed.find { |symbol| symbol.name == wire } || :unknown
    end

    def optional_enum(value, allowed, name)
      optional_text(value, name) && enum(value, allowed, name)
    end
  end
end
