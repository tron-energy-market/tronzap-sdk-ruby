# frozen_string_literal: true

module Tronzap
  module Models
    # A bandwidth price tier. Bandwidth is priced per 1000 units: 345 bandwidth at a {price} of 1 costs 0.345.
    #
    # @!attribute [r] duration
    #   @return [Integer] rental duration in hours
    # @!attribute [r] min_amount
    #   @return [Integer] smallest bandwidth amount this tier applies to
    # @!attribute [r] max_amount
    #   @return [Integer] largest bandwidth amount this tier applies to
    # @!attribute [r] price
    #   @return [BigDecimal] price per 1000 units of bandwidth, in TRX
    BandwidthRate = Data.define(:duration, :min_amount, :max_amount, :price) do
      # @api private
      def self.from_api(value)
        data = Coerce.object(value, "bandwidth rate")
        new(
          duration: Coerce.integer(data["duration"], "duration"),
          min_amount: Coerce.integer(data["min_amount"], "min_amount"),
          max_amount: Coerce.integer(data["max_amount"], "max_amount"),
          price: Coerce.decimal(data["price"], "price")
        )
      end
    end
  end
end
