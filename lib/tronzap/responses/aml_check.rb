# frozen_string_literal: true

module Tronzap
  module Responses
    # An AML screening of an address or a transaction hash.
    #
    # @!attribute [r] id
    #   @return [String] the AML check ID
    # @!attribute [r] type
    #   @return [Symbol] what is screened, one of {Models::AML_CHECK_TYPES} or +:unknown+
    # @!attribute [r] address
    #   @return [String] the screened wallet address
    # @!attribute [r] transaction_hash
    #   @return [String, nil] the screened transaction hash, +nil+ for an address check
    # @!attribute [r] direction
    #   @return [Symbol, nil] the direction of the screened transaction, one of {Models::AML_DIRECTIONS} or
    #     +:unknown+, +nil+ when not given
    # @!attribute [r] network
    #   @return [String] the network code, for example +TRX+, +BTC+ or +ETH+
    # @!attribute [r] status
    #   @return [Symbol] the state of the check, one of {Models::AML_STATUSES} or +:unknown+
    # @!attribute [r] risk_score
    #   @return [BigDecimal, nil] the risk score, +nil+ until the check completes. A completed check can have a
    #     score of 0, which is not the same as having no score yet.
    # @!attribute [r] risk_level
    #   @return [Symbol, nil] the risk level, one of {Models::AML_RISK_LEVELS} or +:unknown+, +nil+ until the
    #     check completes
    # @!attribute [r] blacklist
    #   @return [Boolean] whether the subject is blacklisted
    # @!attribute [r] risk_factors
    #   @return [Array<Models::AmlRiskFactor>] the factors that contributed to the risk score
    # @!attribute [r] checked_at
    #   @return [Models::Timestamp, nil] when the check completed, +nil+ when the API did not report it
    AmlCheck = Data.define(:id, :type, :address, :transaction_hash, :direction, :network, :status,
                           :risk_score, :risk_level, :blacklist, :risk_factors, :checked_at) do
      # @api private
      def self.from_api(value)
        data = Coerce.object(value, "AML check")
        new(
          id: Coerce.text(data["id"], "id"),
          type: Coerce.enum(data["type"], Models::AML_CHECK_TYPES, "type"),
          address: Coerce.text(data["address"], "address"),
          transaction_hash: Coerce.optional_text(data["hash"], "hash"),
          direction: Coerce.optional_enum(data["direction"], Models::AML_DIRECTIONS, "direction"),
          network: Coerce.text(data["network"], "network"),
          status: Coerce.enum(data["status"], Models::AML_STATUSES, "status"),
          risk_score: Coerce.optional_decimal(data["risk_score"], "risk_score"),
          risk_level: Coerce.optional_enum(data["risk_level"], Models::AML_RISK_LEVELS, "risk_level"),
          blacklist: Coerce.boolean(data["blacklist"], "blacklist"),
          risk_factors: Coerce.list(data["risk_factors"], "risk_factors") { Models::AmlRiskFactor.from_api(_1) },
          checked_at: Coerce.timestamp(data["checked_at"], "checked_at")
        )
      end
    end
  end
end
