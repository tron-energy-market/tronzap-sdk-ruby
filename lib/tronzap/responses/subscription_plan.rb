# frozen_string_literal: true

module Tronzap
  module Responses
    # A subscription plan on sale.
    #
    # @!attribute [r] subscription_id
    #   @return [String] the plan's key, such as +unlimited_energy+. Pass it to {Client#start_subscription}.
    # @!attribute [r] id
    #   @return [Integer] the plan's numeric ID
    # @!attribute [r] name
    #   @return [String] the human-readable plan name
    # @!attribute [r] activation_fee
    #   @return [BigDecimal] the one-time fee charged when a subscription starts, in TRX
    # @!attribute [r] initial_price
    #   @return [BigDecimal] the amount charged when a subscription starts, in TRX
    # @!attribute [r] price
    #   @return [BigDecimal] the price of each transaction the subscription serves, in TRX
    # @!attribute [r] transactions_limit
    #   @return [Integer] how many transactions the plan covers, 0 for no limit
    # @!attribute [r] duration_days
    #   @return [Integer] how many days the plan runs, 0 for no time limit
    SubscriptionPlan = Data.define(:subscription_id, :id, :name, :activation_fee, :initial_price, :price,
                                   :transactions_limit, :duration_days) do
      # @api private
      def self.from_api(value, key = nil)
        data = Coerce.object(value, "subscription plan")
        new(
          subscription_id: Coerce.text(key || data["subscription_id"], "subscription_id"),
          id: Coerce.integer(data["id"], "id"),
          name: Coerce.text(data["name"], "name"),
          activation_fee: Coerce.decimal(data["activation_fee"], "activation_fee"),
          initial_price: Coerce.decimal(data["initial_price"], "initial_price"),
          price: Coerce.decimal(data["price"], "price"),
          transactions_limit: Coerce.integer(data["transactions_limit"], "transactions_limit"),
          duration_days: Coerce.integer(data["duration_days"], "duration_days")
        )
      end

      # The API lists plans as an object keyed by plan; an empty list arrives as [].
      #
      # @api private
      def self.list_from_api(value)
        case value
        when Hash then value.map { |key, plan| from_api(plan, key) }.freeze
        when Array then value.map { from_api(_1) }.freeze
        else raise Coerce::Error, "result is not an object"
        end
      end
    end
  end
end
