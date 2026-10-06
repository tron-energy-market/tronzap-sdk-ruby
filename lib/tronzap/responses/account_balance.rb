# frozen_string_literal: true

module Tronzap
  # Results returned by {Client} methods. They are immutable; collections are frozen and never +nil+.
  module Responses
    # The account balance and the address that tops it up.
    #
    # @!attribute [r] balance
    #   @return [BigDecimal] available balance, in TRX
    # @!attribute [r] address
    #   @return [String] the TRON address to send TRX to in order to top up the balance
    AccountBalance = Data.define(:balance, :address) do
      # @api private
      def self.from_api(value)
        data = Coerce.object(value, "result")
        new(balance: Coerce.decimal(data["balance"], "balance"), address: Coerce.text(data["address"], "address"))
      end
    end
  end
end
