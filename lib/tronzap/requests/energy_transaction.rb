# frozen_string_literal: true

module Tronzap
  module Requests
    # An energy purchase.
    #
    # @!attribute [r] address
    #   @return [String] the TRON address that receives the energy
    # @!attribute [r] energy
    #   @return [Integer] the amount of energy to buy
    # @!attribute [r] duration
    #   @return [Integer] rental duration in hours, one of the durations {Client#get_services} lists
    # @!attribute [r] external_id
    #   @return [String, nil] your own ID for the transaction, to look it up with {CheckTransaction.by_external_id}
    # @!attribute [r] activate_address
    #   @return [Boolean] whether to activate the address in the same transaction
    EnergyTransaction = Data.define(:address, :energy, :duration, :external_id, :activate_address) do
      # @param address [String]
      # @param energy [Integer]
      # @param duration [Integer]
      # @param external_id [String, nil]
      # @param activate_address [Boolean]
      # @raise [ArgumentError]
      def initialize(address:, energy:, duration: 1, external_id: nil, activate_address: false)
        super(
          address: Validation.string(address, "address"),
          energy: Validation.positive_integer(energy, "energy"),
          duration: Validation.positive_integer(duration, "duration"),
          external_id: Validation.optional_string(external_id, "external_id"),
          activate_address: Validation.boolean(activate_address, "activate_address")
        )
      end

      # @api private
      def body
        params = { "address" => address, "amounts" => { "energy" => energy }, "duration" => duration }
        params["activate_address"] = true if activate_address
        Validation.transaction("energy", params, external_id)
      end
    end
  end
end
