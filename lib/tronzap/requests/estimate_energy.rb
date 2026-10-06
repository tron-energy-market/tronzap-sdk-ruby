# frozen_string_literal: true

module Tronzap
  # The USDT (TRC20) contract address. The API estimates a transfer of this token when
  # {Requests::EstimateEnergy#contract_address} is not set.
  USDT_CONTRACT_ADDRESS = "TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t"

  module Requests
    # A token transfer to estimate the energy for.
    #
    # @!attribute [r] from_address
    #   @return [String] the sender's TRON address
    # @!attribute [r] to_address
    #   @return [String] the recipient's TRON address
    # @!attribute [r] contract_address
    #   @return [String, nil] the token contract address. When not set the API estimates a USDT (TRC20) transfer.
    EstimateEnergy = Data.define(:from_address, :to_address, :contract_address) do
      # @param from_address [String]
      # @param to_address [String]
      # @param contract_address [String, nil]
      # @raise [ArgumentError]
      def initialize(from_address:, to_address:, contract_address: nil)
        super(
          from_address: Validation.string(from_address, "from_address"),
          to_address: Validation.string(to_address, "to_address"),
          contract_address: Validation.optional_string(contract_address, "contract_address")
        )
      end

      # @api private
      def body
        body = { "from_address" => from_address, "to_address" => to_address }
        body["contract_address"] = contract_address if contract_address
        body
      end
    end
  end
end
