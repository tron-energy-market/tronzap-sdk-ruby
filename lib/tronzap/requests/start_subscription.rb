# frozen_string_literal: true

module Tronzap
  module Requests
    # A subscription to start for an address.
    #
    # @!attribute [r] subscription_id
    #   @return [String] the plan to subscribe to, the {Responses::SubscriptionPlan#subscription_id} of a plan from
    #     {Client#get_subscriptions}, such as +unlimited_energy+. Not the plan's numeric
    #     {Responses::SubscriptionPlan#id}.
    # @!attribute [r] address
    #   @return [String] the TRON address the subscription serves
    # @!attribute [r] duration_days
    #   @return [Integer] how many days the subscription runs, 0 for no time limit
    # @!attribute [r] transactions_limit
    #   @return [Integer] how many transactions the subscription covers, 0 for no limit
    # @!attribute [r] external_id
    #   @return [String, nil] your own ID for the subscription, to look it up with
    #     {SubscriptionLookup.by_external_id}
    # @!attribute [r] activate_address
    #   @return [Boolean] whether to also activate the address if it is not active yet
    StartSubscription = Data.define(:subscription_id, :address, :duration_days, :transactions_limit, :external_id,
                                    :activate_address) do
      # @param subscription_id [String]
      # @param address [String]
      # @param duration_days [Integer]
      # @param transactions_limit [Integer]
      # @param external_id [String, nil]
      # @param activate_address [Boolean]
      # @raise [ArgumentError]
      def initialize(subscription_id:, address:, duration_days: 0, transactions_limit: 0, external_id: nil,
                     activate_address: false)
        super(
          subscription_id: Validation.string(subscription_id, "subscription_id"),
          address: Validation.string(address, "address"),
          duration_days: Validation.non_negative_integer(duration_days, "duration_days"),
          transactions_limit: Validation.non_negative_integer(transactions_limit, "transactions_limit"),
          external_id: Validation.optional_string(external_id, "external_id"),
          activate_address: Validation.boolean(activate_address, "activate_address")
        )
      end

      # @api private
      def body
        params = { "address" => address, "duration" => duration_days, "transactions_limit" => transactions_limit }
        params["activate_address"] = true if activate_address
        body = { "subscription_id" => subscription_id }
        body["external_id"] = external_id if external_id
        body["params"] = params
        body
      end
    end
  end
end
