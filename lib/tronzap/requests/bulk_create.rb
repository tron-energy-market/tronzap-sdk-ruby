# frozen_string_literal: true

module Tronzap
  module Requests
    # A bulk order to start from a calculation.
    #
    # @!attribute [r] id
    #   @return [String] the {Responses::BulkCalculation#id} of the calculation to start
    # @!attribute [r] external_id
    #   @return [String, nil] your own ID for the order, unique per account. Starting an order again with the same
    #     external ID returns the order already started.
    # @!attribute [r] force
    #   @return [Boolean] whether to buy even if the price rises while the order runs, within {max_price_increase}.
    #     When +false+, an address whose price rose is skipped.
    # @!attribute [r] max_price_increase
    #   @return [Integer, nil] the allowed price increase in percent, 0 to 100, used only with {force}. The API
    #     default of 20 applies when it is +nil+.
    # @!attribute [r] webhook_url
    #   @return [String, nil] a public +https+ URL called once when the order becomes final. Check its
    #     +X-Signature+ header with {Client#verify_webhook_signature}.
    BulkCreate = Data.define(:id, :external_id, :force, :max_price_increase, :webhook_url) do
      # @param id [String]
      # @param external_id [String, nil]
      # @param force [Boolean]
      # @param max_price_increase [Integer, nil]
      # @param webhook_url [String, nil]
      # @raise [ArgumentError]
      def initialize(id:, external_id: nil, force: false, max_price_increase: nil, webhook_url: nil)
        unless max_price_increase.nil?
          max_price_increase = Validation.non_negative_integer(max_price_increase, "max_price_increase")
        end
        super(
          id: Validation.string(id, "id"),
          external_id: Validation.optional_string(external_id, "external_id"),
          force: Validation.boolean(force, "force"),
          max_price_increase: max_price_increase,
          webhook_url: Validation.optional_string(webhook_url, "webhook_url")
        )
      end

      # @api private
      def body
        body = { "id" => id }
        body["force"] = true if force
        body["max_price_increase"] = max_price_increase if max_price_increase
        body["webhook_url"] = webhook_url if webhook_url
        body["external_id"] = external_id if external_id
        body
      end
    end
  end
end
