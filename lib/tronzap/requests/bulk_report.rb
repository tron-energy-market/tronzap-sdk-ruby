# frozen_string_literal: true

module Tronzap
  module Requests
    # The bulk order whose report to download, by its TronZap ID, your external ID, or both.
    #
    # @!attribute [r] id
    #   @return [String, nil] the bulk order ID assigned by TronZap
    # @!attribute [r] external_id
    #   @return [String, nil] the external ID you passed when starting the order
    # @!attribute [r] status
    #   @return [Symbol, nil] only rows with this result, one of {Models::BULK_ROW_STATUSES}, or every row when +nil+
    BulkReport = Data.define(:id, :external_id, :status) do
      # @param id [String, nil]
      # @param external_id [String, nil]
      # @param status [Symbol, String, nil]
      # @raise [ArgumentError]
      def initialize(id: nil, external_id: nil, status: nil)
        id = Validation.optional_string(id, "id")
        external_id = Validation.optional_string(external_id, "external_id")
        raise ArgumentError, "either id or external_id is required" if id.nil? && external_id.nil?

        super(id: id, external_id: external_id,
              status: Validation.optional_one_of(status, Models::BULK_ROW_STATUSES, "status"))
      end

      # Downloads the report of a bulk order by its TronZap ID.
      #
      # @param id [String]
      # @param status [Symbol, String, nil]
      # @return [BulkReport]
      def self.by_id(id, status: nil)
        new(id: id, status: status)
      end

      # Downloads the report of a bulk order by the external ID you passed when starting it.
      #
      # @param external_id [String]
      # @param status [Symbol, String, nil]
      # @return [BulkReport]
      def self.by_external_id(external_id, status: nil)
        new(external_id: external_id, status: status)
      end

      # @api private
      def body
        body = {}
        body["id"] = id if id
        body["external_id"] = external_id if external_id
        body["status"] = status.name if status
        body
      end
    end
  end
end
