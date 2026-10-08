# frozen_string_literal: true

module Tronzap
  module Models
    # A rate energy is delivered at for a direct recharge.
    #
    # @!attribute [r] duration
    #   @return [Integer] rental duration in hours
    # @!attribute [r] min_energy
    #   @return [Integer] smallest energy amount this rate applies to
    # @!attribute [r] max_energy
    #   @return [Integer] largest energy amount this rate applies to
    # @!attribute [r] price
    #   @return [BigDecimal] price per 1000 units of energy, in TRX
    # @!attribute [r] price_32k
    #   @return [BigDecimal] price of 32 000 energy, in TRX
    # @!attribute [r] price_65k
    #   @return [BigDecimal] price of 65 000 energy, in TRX
    # @!attribute [r] price_131k
    #   @return [BigDecimal] price of 131 000 energy, in TRX
    DirectRechargeRate = Data.define(:duration, :min_energy, :max_energy,
                                     :price, :price_32k, :price_65k, :price_131k) do
      # @api private
      def self.from_api(value)
        data = Coerce.object(value, "direct recharge rate")
        new(
          duration: Coerce.integer(data["duration"], "duration"),
          min_energy: Coerce.integer(data["min_energy"], "min_energy"),
          max_energy: Coerce.integer(data["max_energy"], "max_energy"),
          price: Coerce.decimal(data["price"], "price"),
          price_32k: Coerce.decimal(data["price_32k"], "price_32k"),
          price_65k: Coerce.decimal(data["price_65k"], "price_65k"),
          price_131k: Coerce.decimal(data["price_131k"], "price_131k")
        )
      end
    end
  end
end
