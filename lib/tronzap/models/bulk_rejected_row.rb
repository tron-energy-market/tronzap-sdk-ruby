# frozen_string_literal: true

module Tronzap
  module Models
    # A row of a bulk calculation that was rejected and will not be ordered.
    #
    # @!attribute [r] row
    #   @return [Integer] the position of the row in the request, starting at 1
    # @!attribute [r] address
    #   @return [String] the address as it was sent
    # @!attribute [r] reason
    #   @return [String] why the row was rejected, for example +invalid_address+, +invalid_amount+ or +duplicate+
    BulkRejectedRow = Data.define(:row, :address, :reason) do
      # @api private
      def self.from_api(value)
        data = Coerce.object(value, "rejected row")
        new(
          row: Coerce.integer(data["row"], "row"),
          address: Coerce.text(data["address"], "address"),
          reason: Coerce.text(data["reason"], "reason")
        )
      end

      # @api private
      def self.list_from_api(value)
        Coerce.list(value, "rejected") { from_api(_1) }
      end
    end
  end
end
