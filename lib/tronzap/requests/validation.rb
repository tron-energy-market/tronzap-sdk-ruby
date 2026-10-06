# frozen_string_literal: true

module Tronzap
  # Parameters of {Client} calls. A request validates its values when it is created, so an invalid one raises
  # +ArgumentError+ and never reaches the API.
  module Requests
    # @api private
    module Validation
      module_function

      def string(value, name)
        raise ArgumentError, "#{name} is required" unless value.is_a?(String) && !value.strip.empty?

        value.dup.freeze
      end

      def optional_string(value, name)
        return nil if value.nil?
        raise ArgumentError, "#{name} must be a non-blank String when set" unless value.is_a?(String) &&
                                                                                  !value.strip.empty?

        value.dup.freeze
      end

      def positive_integer(value, name)
        raise ArgumentError, "#{name} must be a positive Integer, got #{value.inspect}" unless value.is_a?(Integer) &&
                                                                                               value.positive?

        value
      end

      def boolean(value, name)
        raise ArgumentError, "#{name} must be true or false, got #{value.inspect}" unless [true, false].include?(value)

        value
      end

      def one_of(value, allowed, name)
        symbol = value.is_a?(String) ? allowed.find { |item| item.name == value } : value
        return symbol if allowed.include?(symbol)

        raise ArgumentError, "#{name} must be one of #{allowed.map(&:inspect).join(", ")}, got #{value.inspect}"
      end

      def optional_one_of(value, allowed, name)
        value.nil? ? nil : one_of(value, allowed, name)
      end

      def transaction(service, params, external_id)
        body = { "service" => service, "params" => params }
        body["external_id"] = external_id if external_id
        body
      end
    end
  end
end
