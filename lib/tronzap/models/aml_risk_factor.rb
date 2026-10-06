# frozen_string_literal: true

module Tronzap
  module Models
    # One factor that contributed to an AML risk score.
    #
    # @!attribute [r] name
    #   @return [String] machine-readable factor name
    # @!attribute [r] label
    #   @return [String] human-readable factor label
    # @!attribute [r] group
    #   @return [String] the group the factor belongs to
    # @!attribute [r] score
    #   @return [BigDecimal] the factor's share of the risk score
    AmlRiskFactor = Data.define(:name, :label, :group, :score) do
      # @api private
      def self.from_api(value)
        data = Coerce.object(value, "risk factor")
        new(
          name: Coerce.text(data["name"], "name"),
          label: Coerce.text(data["label"], "label"),
          group: Coerce.text(data["group"], "group"),
          score: Coerce.decimal(data["score"], "score")
        )
      end
    end
  end
end
