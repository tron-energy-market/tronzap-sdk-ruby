# frozen_string_literal: true

module Tronzap
  module Models
    # An energy price tier. Energy is priced per 1000 units: 65000 energy at a {price} of 0.03 costs 1.95.
    #
    # @!attribute [r] duration
    #   @return [Integer] rental duration in hours
    # @!attribute [r] min_amount
    #   @return [Integer] smallest amount this tier applies to
    # @!attribute [r] max_amount
    #   @return [Integer] largest amount this tier applies to
    # @!attribute [r] min_energy
    #   @deprecated Use {#min_amount}.
    #   @return [Integer] the same value as {#min_amount}
    # @!attribute [r] max_energy
    #   @deprecated Use {#max_amount}.
    #   @return [Integer] the same value as {#max_amount}
    # @!attribute [r] price
    #   @return [BigDecimal] price per 1000 units of energy, in TRX
    # @!attribute [r] price_32k
    #   @return [BigDecimal] price of 32 000 energy, in TRX
    # @!attribute [r] price_65k
    #   @return [BigDecimal] price of 65 000 energy, in TRX
    # @!attribute [r] price_131k
    #   @return [BigDecimal] price of 131 000 energy, in TRX
    EnergyRate = Data.define(:duration, :min_amount, :max_amount, :min_energy, :max_energy,
                             :price, :price_32k, :price_65k, :price_131k) do
      # @api private
      def self.from_api(value)
        data = Coerce.object(value, "energy rate")
        min_amount = Coerce.integer(data["min_amount"], "min_amount")
        max_amount = Coerce.integer(data["max_amount"], "max_amount")
        new(
          duration: Coerce.integer(data["duration"], "duration"),
          min_amount: min_amount,
          max_amount: max_amount,
          min_energy: min_amount,
          max_energy: max_amount,
          price: Coerce.decimal(data["price"], "price"),
          price_32k: Coerce.decimal(data["price_32k"], "price_32k"),
          price_65k: Coerce.decimal(data["price_65k"], "price_65k"),
          price_131k: Coerce.decimal(data["price_131k"], "price_131k")
        )
      end
    end
  end
end
