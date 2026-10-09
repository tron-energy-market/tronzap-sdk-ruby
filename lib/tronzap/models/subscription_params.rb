# frozen_string_literal: true

module Tronzap
  module Models
    # The parameters a subscription was started with.
    #
    # @!attribute [r] address
    #   @return [String] the TRON address the subscription serves
    # @!attribute [r] duration_days
    #   @return [Integer] how many days the subscription runs, 0 for no time limit
    # @!attribute [r] transactions_limit
    #   @return [Integer] how many transactions the subscription covers, 0 for no limit
    # @!attribute [r] activate_address
    #   @return [Boolean] whether activating the address was requested
    SubscriptionParams = Data.define(:address, :duration_days, :transactions_limit, :activate_address) do
      # @api private
      def self.from_api(value)
        data = Coerce.object(value, "params")
        new(
          address: Coerce.text(data["address"], "params.address"),
          duration_days: Coerce.integer(data["duration"], "params.duration"),
          transactions_limit: Coerce.integer(data["transactions_limit"], "params.transactions_limit"),
          activate_address: Coerce.boolean(data["activate_address"], "params.activate_address")
        )
      end
    end
  end
end
