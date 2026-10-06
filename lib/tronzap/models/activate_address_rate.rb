# frozen_string_literal: true

module Tronzap
  module Models
    # The price of activating a TRON address.
    #
    # @!attribute [r] price
    #   @return [BigDecimal] activation price, in TRX
    ActivateAddressRate = Data.define(:price)
  end
end
