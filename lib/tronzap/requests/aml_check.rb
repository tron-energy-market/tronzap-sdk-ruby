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
    #   @return [String] the address to screen; for a hash check, the recipient address of the transaction, where
    #     the funds were received
    # @!attribute [r] transaction_hash
    #   @return [String, nil] the transaction hash, required when {type} is +:hash+
    # @!attribute [r] direction
    #   @return [Symbol, nil] for a hash check, which side of the transaction you are on, one of
    #     {Models::AML_DIRECTIONS}: +:deposit+ if the funds were sent to your address (+address+ is yours),
    #     +:withdrawal+ if you sent them (+address+ is the external recipient's). The risk is scored for the
    #     counterparty. When omitted for a hash check, the SDK sends +deposit+.
    AmlCheck = Data.define(:type, :network, :address, :transaction_hash, :direction) do
      # @param type [Symbol, String] +:address+ or +:hash+
      # @param network [String]
      # @param address [String]
      # @param transaction_hash [String, nil]
      # @param direction [Symbol, String, nil] +:deposit+ or +:withdrawal+; a hash check without one sends +deposit+
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
      # +address+ is the recipient address of the transaction, where the funds were received. +direction+ says
      # which side of the transaction you are on: +:deposit+ if the funds were sent to your address (+address+ is
      # yours), +:withdrawal+ if you sent them (+address+ is the external recipient's). The risk is scored for the
      # counterparty: the sender of a deposit, the recipient of a withdrawal. Without a direction the SDK sends
      # +deposit+.
      #
      # @param network [String] the network code, for example +BTC+
      # @param address [String] the recipient address of the transaction
      # @param transaction_hash [String]
      # @param direction [Symbol, String, nil] +:deposit+ (the default) or +:withdrawal+
      # @return [AmlCheck]
      def self.for_hash(network, address, transaction_hash, direction: nil)
        new(type: :hash, network: network, address: address, transaction_hash: transaction_hash,
            direction: direction)
      end

      # @api private
      def body
        body = { "type" => type.name, "network" => network, "address" => address }
        body["hash"] = transaction_hash if transaction_hash
        sent_direction = direction || (:deposit if type == :hash)
        body["direction"] = sent_direction.name if sent_direction
        body
      end
    end
  end
end
