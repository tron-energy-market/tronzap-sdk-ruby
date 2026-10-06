# frozen_string_literal: true

module Tronzap
  module Requests
    # An energy purchase to price.
    #
    # @!attribute [r] address
    #   @return [String] the TRON address that would receive the energy
    # @!attribute [r] energy
    #   @return [Integer] the amount of energy
    # @!attribute [r] duration
    #   @return [Integer] rental duration in hours, one of the durations {Client#get_services} lists
    Calculate = Data.define(:address, :energy, :duration) do
      # @param address [String]
      # @param energy [Integer]
      # @param duration [Integer]
      # @raise [ArgumentError]
      def initialize(address:, energy:, duration: 1)
        super(
          address: Validation.string(address, "address"),
          energy: Validation.positive_integer(energy, "energy"),
          duration: Validation.positive_integer(duration, "duration")
        )
      end

      # @api private
      def body
        { "address" => address, "amount" => energy, "duration" => duration }
      end
    end
  end
end
