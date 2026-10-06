# frozen_string_literal: true

module Tronzap
  module Requests
    # A page of AML check history to return.
    #
    # @!attribute [r] page
    #   @return [Integer] the page number, starting at 1
    # @!attribute [r] per_page
    #   @return [Integer] the page size
    # @!attribute [r] status
    #   @return [Symbol, nil] only checks in this state, one of {Models::AML_STATUSES}, or all checks when +nil+
    AmlHistory = Data.define(:page, :per_page, :status) do
      # @param page [Integer]
      # @param per_page [Integer]
      # @param status [Symbol, String, nil]
      # @raise [ArgumentError]
      def initialize(page: 1, per_page: 10, status: nil)
        super(
          page: Validation.positive_integer(page, "page"),
          per_page: Validation.positive_integer(per_page, "per_page"),
          status: Validation.optional_one_of(status, Models::AML_STATUSES, "status")
        )
      end

      # @api private
      def body
        body = { "page" => page, "per_page" => per_page }
        body["status"] = status.name if status
        body
      end
    end
  end
end
