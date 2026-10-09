# frozen_string_literal: true

module Tronzap
  module Requests
    # A page of subscription history to return.
    #
    # @!attribute [r] page
    #   @return [Integer] the page number, starting at 1
    # @!attribute [r] per_page
    #   @return [Integer] the page size, at most 50
    # @!attribute [r] status
    #   @return [Symbol, nil] only subscriptions in this state, one of {Models::SUBSCRIPTION_STATUSES}, or all
    #     subscriptions when +nil+
    SubscriptionHistory = Data.define(:page, :per_page, :status) do
      # @param page [Integer]
      # @param per_page [Integer]
      # @param status [Symbol, String, nil]
      # @raise [ArgumentError]
      def initialize(page: 1, per_page: 10, status: nil)
        super(
          page: Validation.positive_integer(page, "page"),
          per_page: Validation.positive_integer(per_page, "per_page"),
          status: Validation.optional_one_of(status, Models::SUBSCRIPTION_STATUSES, "status")
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
