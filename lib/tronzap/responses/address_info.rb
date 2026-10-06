# frozen_string_literal: true

module Tronzap
  module Responses
    # The on-chain resources and token balances of a TRON address.
    #
    # @!attribute [r] resources
    #   @return [Models::AddressResources] available energy and bandwidth
    # @!attribute [r] balances
    #   @return [Hash{String => BigDecimal}] token balances by token symbol, for example +TRX+ and +USDT+
    AddressInfo = Data.define(:resources, :balances) do
      # @api private
      def self.from_api(value)
        data = Coerce.object(value, "result")
        resources = Coerce.object(data["resources"], "resources")
        new(
          resources: Models::AddressResources.new(
            energy: Coerce.integer(resources["energy"], "resources.energy"),
            bandwidth: Coerce.integer(resources["bandwidth"], "resources.bandwidth")
          ),
          balances: Coerce.decimal_map(data["balances"], "balances")
        )
      end
    end
  end
end
