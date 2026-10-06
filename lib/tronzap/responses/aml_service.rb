# frozen_string_literal: true

module Tronzap
  module Responses
    # An AML screening product and its price.
    #
    # @!attribute [r] id
    #   @return [String] the service ID
    # @!attribute [r] type
    #   @return [Symbol] what the service screens, one of {Models::AML_CHECK_TYPES} or +:unknown+
    # @!attribute [r] price
    #   @return [BigDecimal] price of one check, in TRX
    AmlService = Data.define(:id, :type, :price) do
      # @api private
      def self.from_api(value)
        data = Coerce.object(value, "AML service")
        new(
          id: Coerce.text(data["id"], "id"),
          type: Coerce.enum(data["type"], Models::AML_CHECK_TYPES, "type"),
          price: Coerce.decimal(data["price"], "price")
        )
      end

      # @api private
      def self.list_from_api(value)
        Coerce.list(value, "result") { from_api(_1) }
      end
    end
  end
end
