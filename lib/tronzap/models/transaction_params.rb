# frozen_string_literal: true

module Tronzap
  module Models
    # The parameters a transaction was created with.
    #
    # @!attribute [r] address
    #   @return [String] the TRON address that receives the resources
    # @!attribute [r] duration
    #   @return [Integer] rental duration in hours
    # @!attribute [r] amounts
    #   @return [ResourceAmounts] the resources the transaction buys
    # @!attribute [r] activate_address
    #   @return [Boolean] whether the transaction also activates the address
    TransactionParams = Data.define(:address, :duration, :amounts, :activate_address) do
      # @api private
      def self.from_api(value, service)
        data = Coerce.object(value, "params")
        new(
          address: Coerce.text(data["address"], "params.address"),
          duration: Coerce.integer(data["duration"], "params.duration"),
          amounts: amounts(data, service),
          activate_address: Coerce.boolean(data["activate_address"], "params.activate_address")
        )
      end

      # Older transactions carry params.amount / params.energy_amount instead of params.amounts.
      def self.amounts(data, service)
        amounts = Coerce.object(data["amounts"], "params.amounts")
        energy = Coerce.integer(amounts["energy"], "params.amounts.energy")
        bandwidth = Coerce.integer(amounts["bandwidth"], "params.amounts.bandwidth")
        if energy.zero? && bandwidth.zero?
          energy = Coerce.integer(data["energy_amount"], "params.energy_amount")
          amount = Coerce.integer(data["amount"], "params.amount")
          if service == :bandwidth
            bandwidth = amount
          elsif energy.zero?
            energy = amount
          end
        end
        ResourceAmounts.new(energy: energy, bandwidth: bandwidth)
      end
      private_class_method :amounts
    end
  end
end
