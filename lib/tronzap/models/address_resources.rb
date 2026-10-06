# frozen_string_literal: true

module Tronzap
  module Models
    # The resources a TRON address has available.
    #
    # @!attribute [r] energy
    #   @return [Integer] available energy
    # @!attribute [r] bandwidth
    #   @return [Integer] available bandwidth
    AddressResources = Data.define(:energy, :bandwidth)
  end
end
