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

    # Which side of a screened transaction you are on; the risk is scored for the counterparty. +:deposit+: the
    # funds were sent to your address, the screened address is yours and the sender is scored. +:withdrawal+: you
    # sent the funds, the screened address is the external recipient's and the recipient is scored.
    AML_DIRECTIONS = %i[deposit withdrawal].freeze

    # AML check states.
    AML_STATUSES = %i[pending processing completed failed].freeze

    # AML risk levels.
    AML_RISK_LEVELS = %i[low medium high].freeze

    # Subscription states: +:new+ → +:pending+ → +:active+, then +:stopped+ or +:expired+; +:error+ when it could
    # not be started.
    SUBSCRIPTION_STATUSES = %i[new pending error active stopped expired].freeze

    # Bulk order states: a calculation is +:draft+; a started order is +:processing+, then +:completed+ (every row
    # delivered), +:partial+ (some rows delivered) or +:failed+ (none delivered).
    BULK_STATUSES = %i[draft processing completed partial failed].freeze

    # Row results in a bulk order report. +:in_review+ rows wait for a manual check; +:pending+ rows are not
    # processed yet.
    BULK_ROW_STATUSES = %i[delivered failed in_review skipped pending].freeze
  end
end
