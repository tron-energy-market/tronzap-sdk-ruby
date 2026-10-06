# frozen_string_literal: true

module Tronzap
  module Responses
    # A purchase of energy, bandwidth or address activation.
    #
    # @!attribute [r] id
    #   @return [String] the transaction ID assigned by TronZap
    # @!attribute [r] external_id
    #   @return [String, nil] the ID you passed when creating the transaction
    # @!attribute [r] service
    #   @return [Symbol] the service of the transaction, one of {Models::SERVICES} or +:unknown+. The API currently
    #     reports a resource bundle as +:energy+; read {Models::TransactionParams#amounts} to see which resources
    #     it contains.
    # @!attribute [r] params
    #   @return [Models::TransactionParams] the parameters the transaction was created with
    # @!attribute [r] status
    #   @return [Symbol] the current state, one of {Models::TRANSACTION_STATUSES} or +:unknown+
    # @!attribute [r] amount
    #   @return [BigDecimal] the amount charged, in TRX
    # @!attribute [r] created_at
    #   @return [Models::Timestamp, nil] when the transaction was created, +nil+ when the API did not report it
    # @!attribute [r] transaction_hash
    #   @return [String, nil] the on-chain transaction hash, +nil+ when the API did not report one
    Transaction = Data.define(:id, :external_id, :service, :params, :status, :amount, :created_at,
                              :transaction_hash) do
      # @api private
      def self.from_api(value)
        data = Coerce.object(value, "result")
        service = Coerce.enum(data["service"], Models::SERVICES, "service")
        new(
          id: Coerce.text(data["id"], "id"),
          external_id: Coerce.optional_text(data["external_id"], "external_id"),
          service: service,
          params: Models::TransactionParams.from_api(data["params"], service),
          status: Coerce.enum(data["status"], Models::TRANSACTION_STATUSES, "status"),
          amount: Coerce.decimal(data["amount"], "amount"),
          created_at: Coerce.timestamp(data["created_at"], "created_at"),
          transaction_hash: Coerce.optional_text(data["hash"], "hash")
        )
      end
    end
  end
end
