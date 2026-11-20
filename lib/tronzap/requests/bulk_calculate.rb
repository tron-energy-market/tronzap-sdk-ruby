# frozen_string_literal: true

module Tronzap
  module Requests
    # The rows of a bulk energy order to validate and price.
    #
    # @!attribute [r] items
    #   @return [Array<BulkItem>] the rows, at most 10 000
    # @!attribute [r] duration
    #   @return [Integer] rental duration in hours, one of the durations {Client#get_services} lists
    BulkCalculate = Data.define(:items, :duration) do
      # @param items [Array<BulkItem, Hash>] the rows, as {BulkItem}s or hashes with +address+ and +amount+
      # @param duration [Integer]
      # @raise [ArgumentError]
      def initialize(items:, duration: 1)
        raise ArgumentError, "items is required" unless items.is_a?(Array) && !items.empty?

        super(
          items: items.map { |item| item(item) }.freeze,
          duration: Validation.positive_integer(duration, "duration")
        )
      end

      # @api private
      def body
        { "resource" => "energy", "duration" => duration, "items" => items.map(&:body) }
      end

      private

      def item(value)
        case value
        when BulkItem then value
        when Hash then BulkItem.new(**value.transform_keys(&:to_sym))
        else raise ArgumentError, "items must hold BulkItems or hashes, got #{value.inspect}"
        end
      end
    end
  end
end
