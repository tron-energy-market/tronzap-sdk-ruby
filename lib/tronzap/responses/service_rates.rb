# frozen_string_literal: true

module Tronzap
  module Responses
    # The resources on sale and their current prices.
    #
    # Energy and bandwidth are both priced per 1000 units, so a purchase costs price × amount / 1000: 65000 energy
    # at a {Models::EnergyRate#price} of 0.03 costs 1.95, and 345 bandwidth at a {Models::BandwidthRate#price} of 1
    # costs 0.345.
    #
    # @!attribute [r] energy
    #   @return [Array<Models::EnergyRate>] energy price tiers
    # @!attribute [r] bandwidth
    #   @return [Array<Models::BandwidthRate>] bandwidth price tiers
    # @!attribute [r] activate_address
    #   @return [Models::ActivateAddressRate, nil] the address activation price, +nil+ when the API did not
    #     report one
    ServiceRates = Data.define(:energy, :bandwidth, :activate_address) do
      # @api private
      def self.from_api(value)
        data = Coerce.object(value, "result")
        activation = data["activate_address"]
        new(
          energy: Coerce.list(data["energy"], "energy") { Models::EnergyRate.from_api(_1) },
          bandwidth: Coerce.list(data["bandwidth"], "bandwidth") { Models::BandwidthRate.from_api(_1) },
          activate_address: activation.nil? ? nil : activation_rate(activation)
        )
      end

      def self.activation_rate(value)
        data = Coerce.object(value, "activate_address")
        Models::ActivateAddressRate.new(price: Coerce.decimal(data["price"], "activate_address.price"))
      end
      private_class_method :activation_rate
    end
  end
end
