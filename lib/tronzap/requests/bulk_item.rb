# frozen_string_literal: true

module Tronzap
  module Requests
    # One row of a bulk energy order. The SDK does not check the address or the amount: the calculation rejects
    # invalid rows and reports them with their row number.
    #
    # @!attribute [r] address
    #   @return [String] the TRON address that receives the energy
    # @!attribute [r] amount
    #   @return [Integer] the amount of energy
    BulkItem = Data.define(:address, :amount) do
      # @param address [String]
      # @param amount [Integer]
      # @raise [ArgumentError] when the address is not a String or the amount not an Integer
      def initialize(address:, amount:)
        raise ArgumentError, "address must be a String, got #{address.inspect}" unless address.is_a?(String)
        raise ArgumentError, "amount must be an Integer, got #{amount.inspect}" unless amount.is_a?(Integer)

        super(address: address.dup.freeze, amount: amount)
      end

      # @api private
      def body
        { "address" => address, "amount" => amount }
      end
    end
  end
end
