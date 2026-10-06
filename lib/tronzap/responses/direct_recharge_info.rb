# frozen_string_literal: true

module Tronzap
  module Responses
    # The address to pay for a direct energy recharge and the rates energy is delivered at.
    #
    # @!attribute [r] address
    #   @return [String] the TRON address to send TRX to
    # @!attribute [r] rates
    #   @return [Array<Models::DirectRechargeRate>] the rates energy is delivered at
    DirectRechargeInfo = Data.define(:address, :rates) do
      # @api private
      def self.from_api(value)
        data = Coerce.object(value, "result")
        new(
          address: Coerce.text(data["address"], "address"),
          rates: Coerce.list(data["rates"], "rates") { Models::DirectRechargeRate.from_api(_1) }
        )
      end
    end
  end
end
