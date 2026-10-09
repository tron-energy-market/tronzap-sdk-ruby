# frozen_string_literal: true

module Tronzap
  module Responses
    # An energy subscription for an address.
    #
    # {Client#start_subscription}, {Client#check_subscription} and {Client#stop_subscription} report the IDs,
    # status, dates and {params}. {Client#get_subscription_history} reports the usage counters
    # ({transactions_limit}, {transactions_used}, {energy_used}, {total_price}) instead of {params}. A field the
    # response does not carry is +nil+.
    #
    # @!attribute [r] id
    #   @return [String] the subscription ID assigned by TronZap
    # @!attribute [r] subscription_id
    #   @return [String] the plan the subscription belongs to, such as +unlimited_energy+
    # @!attribute [r] external_id
    #   @return [String, nil] the ID you passed when starting the subscription
    # @!attribute [r] address
    #   @return [String, nil] the TRON address the subscription serves, +nil+ when the API did not report it, as
    #     in the response of {Client#stop_subscription}; {params} still holds it there
    # @!attribute [r] status
    #   @return [Symbol] the current state, one of {Models::SUBSCRIPTION_STATUSES} or +:unknown+
    # @!attribute [r] params
    #   @return [Models::SubscriptionParams, nil] the parameters the subscription was started with, +nil+ in the
    #     history
    # @!attribute [r] transactions_limit
    #   @return [Integer, nil] how many transactions the subscription covers, 0 for no limit
    # @!attribute [r] transactions_used
    #   @return [Integer, nil] how many transactions the subscription has served
    # @!attribute [r] energy_used
    #   @return [Integer, nil] how much energy the subscription has delegated
    # @!attribute [r] total_price
    #   @return [BigDecimal, nil] the amount charged for the subscription so far, in TRX
    # @!attribute [r] created_at
    #   @return [Models::Timestamp, nil] when the subscription was created
    # @!attribute [r] started_at
    #   @return [Models::Timestamp, nil] when the subscription started
    # @!attribute [r] renewed_at
    #   @return [Models::Timestamp, nil] when the subscription was last renewed
    # @!attribute [r] stopped_at
    #   @return [Models::Timestamp, nil] when the subscription was stopped
    # @!attribute [r] expire_at
    #   @return [Models::Timestamp, nil] when the subscription ends, +nil+ when it has no time limit
    Subscription = Data.define(:id, :subscription_id, :external_id, :address, :status, :params,
                               :transactions_limit, :transactions_used, :energy_used, :total_price,
                               :created_at, :started_at, :renewed_at, :stopped_at, :expire_at) do
      # @api private
      def self.from_api(value)
        data = Coerce.object(value, "subscription")
        new(
          id: Coerce.text(data["id"], "id"),
          subscription_id: Coerce.text(data["subscription_id"], "subscription_id"),
          external_id: Coerce.optional_text(data["external_id"], "external_id"),
          address: Coerce.optional_text(data["address"], "address"),
          status: Coerce.enum(data["status"], Models::SUBSCRIPTION_STATUSES, "status"),
          params: data["params"].nil? ? nil : Models::SubscriptionParams.from_api(data["params"]),
          transactions_limit: Coerce.optional_integer(data["transactions_limit"], "transactions_limit"),
          transactions_used: Coerce.optional_integer(data["transactions_used"], "transactions_used"),
          energy_used: Coerce.optional_integer(data["energy_used"], "energy_used"),
          total_price: Coerce.optional_decimal(data["total_price"], "total_price"),
          **timestamps(data)
        )
      end

      def self.timestamps(data)
        %w[created_at started_at renewed_at stopped_at expire_at].to_h do |name|
          [name.to_sym, Coerce.timestamp(data[name], name)]
        end
      end
      private_class_method :timestamps
    end
  end
end
