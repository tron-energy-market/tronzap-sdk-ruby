# frozen_string_literal: true

module Tronzap
  module Requests
    # A page of bulk orders to return.
    #
    # @!attribute [r] page
    #   @return [Integer] the page number, starting at 1
    # @!attribute [r] per_page
    #   @return [Integer] the page size, at most 50
    BulkHistory = Data.define(:page, :per_page) do
      # @param page [Integer]
      # @param per_page [Integer]
      # @raise [ArgumentError]
      def initialize(page: 1, per_page: 10)
        super(
          page: Validation.positive_integer(page, "page"),
          per_page: Validation.positive_integer(per_page, "per_page")
        )
      end

      # @api private
      def body
        { "page" => page, "per_page" => per_page }
      end
    end
  end
end
