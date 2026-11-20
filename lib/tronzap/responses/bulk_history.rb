# frozen_string_literal: true

module Tronzap
  module Responses
    # One page of your bulk orders, newest first.
    #
    # @!attribute [r] page
    #   @return [Integer] the page number, starting at 1
    # @!attribute [r] per_page
    #   @return [Integer] the page size
    # @!attribute [r] total
    #   @return [Integer] the number of bulk orders across all pages
    # @!attribute [r] items
    #   @return [Array<BulkOrder>] the orders on this page
    BulkHistory = Data.define(:page, :per_page, :total, :items) do
      # @api private
      def self.from_api(value)
        data = Coerce.object(value, "result")
        new(
          page: Coerce.integer(data["page"], "page"),
          per_page: Coerce.integer(data["per_page"], "per_page"),
          total: Coerce.integer(data["total"], "total"),
          items: Coerce.list(data["items"], "items") { BulkOrder.from_api(_1) }
        )
      end
    end
  end
end
