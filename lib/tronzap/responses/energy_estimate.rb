# frozen_string_literal: true

module Tronzap
  module Responses
    # The energy a token transfer needs and what that energy costs.
    #
    # @!attribute [r] amount
    #   @return [Integer] the energy the transfer needs, which the price applies to
    # @!attribute [r] energy
    #   @deprecated Use {#amount}.
    #   @return [Integer] the same value as {#amount}
    # @!attribute [r] duration
    #   @return [Integer] rental duration in hours
    # @!attribute [r] price
    #   @return [BigDecimal] price of the energy, in TRX
    # @!attribute [r] activation_fee
    #   @return [BigDecimal] address activation fee, in TRX
    # @!attribute [r] total
    #   @return [BigDecimal] total cost, in TRX
    # @!attribute [r] from_address
    #   @return [String] the sender address
    # @!attribute [r] to_address
    #   @return [String] the recipient address
    # @!attribute [r] contract_address
    #   @return [String] the token contract the estimate is for
    EnergyEstimate = Data.define(:amount, :energy, :duration, :price, :activation_fee, :total,
                                 :from_address, :to_address, :contract_address) do
      # @api private
      def self.from_api(value)
        data = Coerce.object(value, "result")
        amount = Coerce.integer(data["amount"], "amount")
        new(
          amount: amount,
          energy: amount,
          duration: Coerce.integer(data["duration"], "duration"),
          price: Coerce.decimal(data["price"], "price"),
          activation_fee: Coerce.decimal(data["activation_fee"], "activation_fee"),
          total: Coerce.decimal(data["total"], "total"),
          from_address: Coerce.text(data["from_address"], "from_address"),
          to_address: Coerce.text(data["to_address"], "to_address"),
          contract_address: Coerce.text(data["contract_address"], "contract_address")
        )
      end
    end
  end
end
