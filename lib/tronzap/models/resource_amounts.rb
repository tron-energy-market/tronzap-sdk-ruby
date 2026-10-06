# frozen_string_literal: true

module Tronzap
  module Models
    # The resources a transaction buys. A resource the transaction does not include is 0.
    #
    # @!attribute [r] energy
    #   @return [Integer] energy bought
    # @!attribute [r] bandwidth
    #   @return [Integer] bandwidth bought
    ResourceAmounts = Data.define(:energy, :bandwidth)
  end
end
