# frozen_string_literal: true

module Tronzap
  module Requests
    # An address or a transaction hash to screen.
    #
    # @!attribute [r] type
    #   @return [Symbol] what to screen, one of {Models::AML_CHECK_TYPES}
    # @!attribute [r] network
    #   @return [String] the network code, for example +TRX+, +BTC+ or +ETH+
    # @!attribute [r] address
    #   @return [String] the wallet address
    # @!attribute [r] transaction_hash
    #   @return [String, nil] the transaction hash, required when {type} is +:hash+
    # @!attribute [r] direction
    #   @return [Symbol, nil] the transaction direction for a hash check, one of {Models::AML_DIRECTIONS}
    AmlCheck = Data.define(:type, :network, :address, :transaction_hash, :direction) do
      # @param type [Symbol, String] +:address+ or +:hash+
      # @param network [String]
      # @param address [String]
      # @param transaction_hash [String, nil]
      # @param direction [Symbol, String, nil] +:deposit+ or +:withdrawal+
      # @raise [ArgumentError]
      def initialize(type:, network:, address:, transaction_hash: nil, direction: nil)
        type = Validation.one_of(type, Models::AML_CHECK_TYPES, "type")
        transaction_hash = Validation.optional_string(transaction_hash, "transaction_hash")
        raise ArgumentError, "transaction_hash is required for a hash check" if type == :hash && !transaction_hash

        super(
          type: type,
          network: Validation.string(network, "network"),
          address: Validation.string(address, "address"),
          transaction_hash: transaction_hash,
          direction: Validation.optional_one_of(direction, Models::AML_DIRECTIONS, "direction")
        )
      end

      # Screens a wallet address.
      #
      # @param network [String] the network code, for example +TRX+
      # @param address [String]
      # @return [AmlCheck]
      def self.for_address(network, address)
        new(type: :address, network: network, address: address)
      end

      # Screens a transaction.
      #
      # @param network [String] the network code, for example +BTC+
      # @param address [String]
      # @param transaction_hash [String]
      # @param direction [Symbol, String, nil] +:deposit+ or +:withdrawal+
      # @return [AmlCheck]
      def self.for_hash(network, address, transaction_hash, direction: nil)
        new(type: :hash, network: network, address: address, transaction_hash: transaction_hash,
            direction: direction)
      end

      # @api private
      def body
        body = { "type" => type.name, "network" => network, "address" => address }
        body["hash"] = transaction_hash if transaction_hash
        body["direction"] = direction.name if direction
        body
      end
    end
  end
end
