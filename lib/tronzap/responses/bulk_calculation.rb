# frozen_string_literal: true

module Tronzap
  module Responses
    # The price of a bulk energy order. Nothing is charged until the order is started with {Client#bulk_create}.
    #
    # @!attribute [r] id
    #   @return [String] the calculation ID to pass to {Client#bulk_create}
    # @!attribute [r] status
    #   @return [Symbol] +:draft+, or another of {Models::BULK_STATUSES} or +:unknown+
    # @!attribute [r] resource
    #   @return [String] the resource ordered, +energy+
    # @!attribute [r] duration
    #   @return [Integer] rental duration in hours
    # @!attribute [r] total_amount
    #   @return [BigDecimal] the price of the accepted rows, in TRX
    # @!attribute [r] accepted
    #   @return [Integer] how many rows will be ordered
    # @!attribute [r] rejected_count
    #   @return [Integer] how many rows were rejected
    # @!attribute [r] rejected
    #   @return [Array<Models::BulkRejectedRow>] the rejected rows with their row numbers and reasons
    # @!attribute [r] expires_at
    #   @return [Models::Timestamp, nil] when the calculation expires, 10 minutes after it was made
    BulkCalculation = Data.define(:id, :status, :resource, :duration, :total_amount, :accepted, :rejected_count,
                                  :rejected, :expires_at) do
      # @api private
      def self.from_api(value)
        data = Coerce.object(value, "result")
        new(
          id: Coerce.text(data["id"], "id"),
          status: Coerce.enum(data["status"], Models::BULK_STATUSES, "status"),
          resource: Coerce.text(data["resource"], "resource"),
          duration: Coerce.integer(data["duration"], "duration"),
          total_amount: Coerce.decimal(data["total_amount"], "total_amount"),
          accepted: Coerce.integer(data["accepted"], "accepted"),
          rejected_count: Coerce.integer(data["rejected_count"], "rejected_count"),
          rejected: Models::BulkRejectedRow.list_from_api(data["rejected"]),
          expires_at: Coerce.timestamp(data["expires_at"], "expires_at")
        )
      end
    end
  end
end
