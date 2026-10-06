# frozen_string_literal: true

module Tronzap
  module Requests
    # A TRON address to activate.
    #
    # @!attribute [r] address
    #   @return [String] the TRON address to activate
    # @!attribute [r] external_id
    #   @return [String, nil] your own ID for the transaction, to look it up with {CheckTransaction.by_external_id}
    AddressActivation = Data.define(:address, :external_id) do
      # @param address [String]
      # @param external_id [String, nil]
      # @raise [ArgumentError]
      def initialize(address:, external_id: nil)
        super(
          address: Validation.string(address, "address"),
          external_id: Validation.optional_string(external_id, "external_id")
        )
      end

      # @api private
      def body
        Validation.transaction("activate_address", { "address" => address }, external_id)
      end
    end
  end
end
