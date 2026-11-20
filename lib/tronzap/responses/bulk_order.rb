# frozen_string_literal: true

module Tronzap
  module Responses
    # A bulk energy order and its progress.
    #
    # @!attribute [r] id
    #   @return [String] the bulk order ID assigned by TronZap
    # @!attribute [r] external_id
    #   @return [String, nil] the ID you passed when starting the order
    # @!attribute [r] status
    #   @return [Symbol] the current state, one of {Models::BULK_STATUSES} or +:unknown+. +:completed+, +:partial+
    #     and +:failed+ are final.
    # @!attribute [r] resource
    #   @return [String] the resource ordered, +energy+
    # @!attribute [r] duration
    #   @return [Integer] rental duration in hours
    # @!attribute [r] force
    #   @return [Boolean] whether rows are bought even if the price rose, within {max_price_increase}
    # @!attribute [r] max_price_increase
    #   @return [Integer] the allowed price increase in percent
    # @!attribute [r] webhook_url
    #   @return [String, nil] the URL called when the order becomes final
    # @!attribute [r] total
    #   @return [Integer] how many rows the order has
    # @!attribute [r] processed
    #   @return [Integer] how many rows are processed
    # @!attribute [r] delivered
    #   @return [Integer] how many rows received energy
    # @!attribute [r] failed
    #   @return [Integer] how many rows failed
    # @!attribute [r] in_review
    #   @return [Integer] how many rows wait for a manual check
    # @!attribute [r] skipped
    #   @return [Integer] how many rows were skipped without a charge
    # @!attribute [r] skipped_by_reason
    #   @return [Hash{String => Integer}] the skipped rows by reason, for example +address_not_activated+ or
    #     +price_increased+
    # @!attribute [r] rejected_count
    #   @return [Integer] how many rows the calculation rejected
    # @!attribute [r] total_amount
    #   @return [BigDecimal] the calculated price of the order, in TRX
    # @!attribute [r] charged_amount
    #   @return [BigDecimal] the amount charged so far, in TRX
    # @!attribute [r] created_at
    #   @return [Models::Timestamp, nil] when the order was created
    # @!attribute [r] started_at
    #   @return [Models::Timestamp, nil] when processing started
    # @!attribute [r] finalized_at
    #   @return [Models::Timestamp, nil] when the order became final, +nil+ while it runs
    BulkOrder = Data.define(:id, :external_id, :status, :resource, :duration, :force, :max_price_increase,
                            :webhook_url, :total, :processed, :delivered, :failed, :in_review, :skipped,
                            :skipped_by_reason, :rejected_count, :total_amount, :charged_amount, :created_at,
                            :started_at, :finalized_at) do
      # @api private
      def self.from_api(value)
        data = Coerce.object(value, "bulk order")
        new(
          id: Coerce.text(data["id"], "id"),
          external_id: Coerce.optional_text(data["external_id"], "external_id"),
          status: Coerce.enum(data["status"], Models::BULK_STATUSES, "status"),
          resource: Coerce.text(data["resource"], "resource"),
          duration: Coerce.integer(data["duration"], "duration"),
          force: Coerce.boolean(data["force"], "force"),
          max_price_increase: Coerce.integer(data["max_price_increase"], "max_price_increase"),
          webhook_url: Coerce.optional_text(data["webhook_url"], "webhook_url"),
          **counters(data),
          skipped_by_reason: Coerce.integer_map(data["skipped_by_reason"], "skipped_by_reason"),
          total_amount: Coerce.decimal(data["total_amount"], "total_amount"),
          charged_amount: Coerce.decimal(data["charged_amount"], "charged_amount"),
          **timestamps(data)
        )
      end

      def self.timestamps(data)
        %w[created_at started_at finalized_at].to_h { |name| [name.to_sym, Coerce.timestamp(data[name], name)] }
      end

      def self.counters(data)
        %w[total processed delivered failed in_review skipped rejected_count].to_h do |name|
          [name.to_sym, Coerce.integer(data[name], name)]
        end
      end
      private_class_method :counters, :timestamps
    end
  end
end
