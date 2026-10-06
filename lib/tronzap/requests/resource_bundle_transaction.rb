# frozen_string_literal: true

module Tronzap
  module Requests
    # A purchase of energy and bandwidth in one transaction.
    #
    # @!attribute [r] address
    #   @return [String] the TRON address that receives the resources
    # @!attribute [r] energy
    #   @return [Integer] the amount of energy to buy
    # @!attribute [r] bandwidth
    #   @return [Integer] the amount of bandwidth to buy
    # @!attribute [r] duration
    #   @return [Integer] rental duration in hours
    # @!attribute [r] external_id
    #   @return [String, nil] your own ID for the transaction, to look it up with {CheckTransaction.by_external_id}
    # @!attribute [r] activate_address
    #   @return [Boolean] whether to activate the address in the same transaction
    ResourceBundleTransaction = Data.define(:address, :energy, :bandwidth, :duration, :external_id,
                                            :activate_address) do
      # @param address [String]
      # @param energy [Integer]
      # @param bandwidth [Integer]
      # @param duration [Integer]
      # @param external_id [String, nil]
      # @param activate_address [Boolean]
      # @raise [ArgumentError]
      def initialize(address:, energy:, bandwidth:, duration: 1, external_id: nil, activate_address: false)
        super(
          address: Validation.string(address, "address"),
          energy: Validation.positive_integer(energy, "energy"),
          bandwidth: Validation.positive_integer(bandwidth, "bandwidth"),
          duration: Validation.positive_integer(duration, "duration"),
          external_id: Validation.optional_string(external_id, "external_id"),
          activate_address: Validation.boolean(activate_address, "activate_address")
        )
      end

      # @api private
      def body
        params = {
          "address" => address,
          "amounts" => { "energy" => energy, "bandwidth" => bandwidth },
          "duration" => duration
        }
        params["activate_address"] = true if activate_address
        Validation.transaction("resource_bundle", params, external_id)
      end
    end
  end
end
