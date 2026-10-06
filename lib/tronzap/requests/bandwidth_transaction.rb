# frozen_string_literal: true

module Tronzap
  module Requests
    # A bandwidth purchase. Bandwidth is rented for one hour.
    #
    # @!attribute [r] address
    #   @return [String] the TRON address that receives the bandwidth
    # @!attribute [r] bandwidth
    #   @return [Integer] the amount of bandwidth to buy
    # @!attribute [r] external_id
    #   @return [String, nil] your own ID for the transaction, to look it up with {CheckTransaction.by_external_id}
    BandwidthTransaction = Data.define(:address, :bandwidth, :external_id) do
      # @param address [String]
      # @param bandwidth [Integer]
      # @param external_id [String, nil]
      # @raise [ArgumentError]
      def initialize(address:, bandwidth:, external_id: nil)
        super(
          address: Validation.string(address, "address"),
          bandwidth: Validation.positive_integer(bandwidth, "bandwidth"),
          external_id: Validation.optional_string(external_id, "external_id")
        )
      end

      # @api private
      def body
        params = { "address" => address, "amounts" => { "bandwidth" => bandwidth }, "duration" => 1 }
        Validation.transaction("bandwidth", params, external_id)
      end
    end
  end
end
