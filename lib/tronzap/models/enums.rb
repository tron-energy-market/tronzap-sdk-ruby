# frozen_string_literal: true

module Tronzap
  # Value objects nested in API responses, and the symbols enum-like fields take.
  #
  # Enum-like fields are symbols. A value this SDK version does not recognise is reported as +:unknown+.
  module Models
    # Services a transaction is created for.
    SERVICES = %i[energy bandwidth resource_bundle activate_address].freeze

    # Transaction states: +:new+ → +:pending+ → +:success+ or +:failed+.
    TRANSACTION_STATUSES = %i[new pending success failed].freeze

    # What an AML check screens: a wallet address or a transaction hash.
    AML_CHECK_TYPES = %i[address hash].freeze

    # Directions of a screened transaction: incoming (+:deposit+) or outgoing (+:withdrawal+) funds.
    AML_DIRECTIONS = %i[deposit withdrawal].freeze

    # AML check states.
    AML_STATUSES = %i[pending processing completed failed].freeze

    # AML risk levels.
    AML_RISK_LEVELS = %i[low medium high].freeze
  end
end
