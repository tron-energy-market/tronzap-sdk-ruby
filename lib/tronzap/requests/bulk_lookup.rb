# frozen_string_literal: true

module Tronzap
  module Requests
    # The bulk order to check, by its TronZap ID, your external ID, or both.
    #
    # @!attribute [r] id
    #   @return [String, nil] the bulk order ID assigned by TronZap
    # @!attribute [r] external_id
    #   @return [String, nil] the external ID you passed when starting the order
    BulkLookup = Data.define(:id, :external_id) do
      # @param id [String, nil]
      # @param external_id [String, nil]
      # @raise [ArgumentError] when neither is given
      def initialize(id: nil, external_id: nil)
        id = Validation.optional_string(id, "id")
        external_id = Validation.optional_string(external_id, "external_id")
        raise ArgumentError, "either id or external_id is required" if id.nil? && external_id.nil?

        super
      end

      # Looks a bulk order up by its TronZap ID.
      #
      # @param id [String]
      # @return [BulkLookup]
      def self.by_id(id)
        new(id: id)
      end

      # Looks a bulk order up by the external ID you passed when starting it.
      #
      # @param external_id [String]
      # @return [BulkLookup]
      def self.by_external_id(external_id)
        new(external_id: external_id)
      end

      # @api private
      def body
        body = {}
        body["id"] = id if id
        body["external_id"] = external_id if external_id
        body
      end
    end
  end
end
