# frozen_string_literal: true

module Tronzap
  module Responses
    # The price of an energy purchase.
    #
    # @!attribute [r] address
    #   @return [String] the TRON address that would receive the energy
    # @!attribute [r] service
    #   @return [Symbol] the service the price is for, one of {Models::SERVICES} or +:unknown+
    # @!attribute [r] amount
    #   @return [Integer] the amount priced
    # @!attribute [r] energy
    #   @return [Integer] the energy priced
    # @!attribute [r] duration
    #   @return [Integer] rental duration in hours
    # @!attribute [r] price
    #   @return [BigDecimal] price of the energy, in TRX
    # @!attribute [r] activation_fee
    #   @return [BigDecimal] address activation fee, in TRX
    # @!attribute [r] total
    #   @return [BigDecimal] total cost, in TRX
    Calculation = Data.define(:address, :service, :amount, :energy, :duration, :price, :activation_fee, :total) do
      # @api private
      def self.from_api(value)
        data = Coerce.object(value, "result")
        new(
          address: Coerce.text(data["address"], "address"),
          service: Coerce.enum(data["type"], Models::SERVICES, "type"),
          amount: Coerce.integer(data["amount"], "amount"),
          energy: Coerce.integer(data["energy"], "energy"),
          duration: Coerce.integer(data["duration"], "duration"),
          price: Coerce.decimal(data["price"], "price"),
          activation_fee: Coerce.decimal(data["activation_fee"], "activation_fee"),
          total: Coerce.decimal(data["total"], "total")
        )
      end
    end
  end
end
