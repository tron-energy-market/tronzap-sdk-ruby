# frozen_string_literal: true

require "digest"
require "json"

module Tronzap
  # Client for the {https://docs.tronzap.com/ TronZap API}: buy TRON energy and bandwidth, activate addresses, run
  # AML checks and manage energy subscriptions.
  #
  # A client is immutable and safe to share between threads. Create one per set of credentials.
  #
  # Methods that take parameters accept either a request object from {Requests} or the same values as keyword
  # arguments. Invalid values raise +ArgumentError+ before anything is sent. Every failure of the call itself raises
  # a {Tronzap::Error}: {ApiError} when the API rejected the request, {HttpError} for a non-2xx response without an
  # API error code, {InvalidResponseError} for a response the SDK cannot read, and {NetworkError} when no response
  # arrived.
  #
  # @example
  #   client = Tronzap::Client.new(api_token: ENV.fetch("TRONZAP_API_TOKEN"),
  #                                api_secret: ENV.fetch("TRONZAP_API_SECRET"))
  #   transaction = client.create_energy_transaction(address: "TRecipientAddress", energy: 65000)
  #   transaction.status # => :new
  class Client
    # @return [Configuration] the frozen configuration
    attr_reader :config

    # @param options [Hash] the settings of {Configuration#initialize}
    # @yieldparam config [Configuration] the configuration to change before the client is created
    # @raise [ArgumentError] when a setting is invalid
    def initialize(**)
      config = Configuration.new(**)
      yield config if block_given?
      @config = config.finalize!
      freeze
    end

    # Available services and their prices.
    #
    # @return [Responses::ServiceRates]
    # @raise [Error]
    def get_services
      post("/v1/services", {}) { Responses::ServiceRates.from_api(_1) }
    end

    # The current account balance.
    #
    # @return [Responses::AccountBalance]
    # @raise [Error]
    def get_balance
      post("/v1/balance", {}) { Responses::AccountBalance.from_api(_1) }
    end

    # The resources (energy, bandwidth) and token balances (TRX, USDT) of a TRON address.
    #
    # @param address [String] the TRON address
    # @return [Responses::AddressInfo]
    # @raise [ArgumentError, Error]
    def get_address_info(address)
      body = { "address" => Requests::Validation.string(address, "address") }
      post("/v1/address-info", body) { Responses::AddressInfo.from_api(_1) }
    end

    # The energy a token transfer needs, and its cost.
    #
    # @overload estimate_energy(request)
    #   @param request [Requests::EstimateEnergy]
    # @overload estimate_energy(from_address:, to_address:, contract_address: nil)
    # @return [Responses::EnergyEstimate]
    # @raise [ArgumentError, Error]
    def estimate_energy(request = nil, **params)
      body = build(Requests::EstimateEnergy, request, params).body
      post("/v1/estimate-energy", body) { Responses::EnergyEstimate.from_api(_1) }
    end

    # Prices an energy purchase without creating a transaction.
    #
    # @overload calculate(request)
    #   @param request [Requests::Calculate]
    # @overload calculate(address:, energy:, duration: 1)
    # @return [Responses::Calculation]
    # @raise [ArgumentError, Error]
    def calculate(request = nil, **params)
      body = build(Requests::Calculate, request, params).body
      post("/v1/calculate", body) { Responses::Calculation.from_api(_1) }
    end

    # Buys energy.
    #
    # @overload create_energy_transaction(request)
    #   @param request [Requests::EnergyTransaction]
    # @overload create_energy_transaction(address:, energy:, duration: 1, external_id: nil, activate_address: false)
    # @return [Responses::Transaction]
    # @raise [ArgumentError, Error]
    def create_energy_transaction(request = nil, **params)
      create_transaction(build(Requests::EnergyTransaction, request, params))
    end

    # Buys bandwidth.
    #
    # @overload create_bandwidth_transaction(request)
    #   @param request [Requests::BandwidthTransaction]
    # @overload create_bandwidth_transaction(address:, bandwidth:, external_id: nil)
    # @return [Responses::Transaction]
    # @raise [ArgumentError, Error]
    def create_bandwidth_transaction(request = nil, **params)
      create_transaction(build(Requests::BandwidthTransaction, request, params))
    end

    # Buys energy and bandwidth in one transaction.
    #
    # @overload create_resource_bundle_transaction(request)
    #   @param request [Requests::ResourceBundleTransaction]
    # @overload create_resource_bundle_transaction(address:, energy:, bandwidth:, duration: 1, external_id: nil,
    #                                              activate_address: false)
    # @return [Responses::Transaction]
    # @raise [ArgumentError, Error]
    def create_resource_bundle_transaction(request = nil, **params)
      create_transaction(build(Requests::ResourceBundleTransaction, request, params))
    end

    # Activates a TRON address.
    #
    # @overload create_address_activation_transaction(request)
    #   @param request [Requests::AddressActivation]
    # @overload create_address_activation_transaction(address:, external_id: nil)
    # @return [Responses::Transaction]
    # @raise [ArgumentError, Error]
    def create_address_activation_transaction(request = nil, **params)
      create_transaction(build(Requests::AddressActivation, request, params))
    end

    # The status of a transaction, by its TronZap ID or by your external ID.
    #
    # @overload check_transaction(request)
    #   @param request [Requests::CheckTransaction]
    # @overload check_transaction(id: nil, external_id: nil)
    # @return [Responses::Transaction]
    # @raise [ArgumentError, Error]
    def check_transaction(request = nil, **params)
      body = build(Requests::CheckTransaction, request, params).body
      post("/v1/transaction/check", body) { Responses::Transaction.from_api(_1) }
    end

    # The address to pay for a direct energy recharge and the rates energy is delivered at.
    #
    # @return [Responses::DirectRechargeInfo]
    # @raise [Error]
    def get_direct_recharge_info
      post("/v1/direct-recharge-info", {}) { Responses::DirectRechargeInfo.from_api(_1) }
    end

    # AML services and their prices.
    #
    # @return [Array<Responses::AmlService>]
    # @raise [Error]
    def get_aml_services
      post("/v1/aml-checks", {}) { Responses::AmlService.list_from_api(_1) }
    end

    # Starts an AML screening of an address or a transaction. A hash check without a direction sends +deposit+.
    #
    # @overload create_aml_check(request)
    #   @param request [Requests::AmlCheck] see {Requests::AmlCheck.for_address} and {Requests::AmlCheck.for_hash}
    # @overload create_aml_check(type:, network:, address:, transaction_hash: nil, direction: nil)
    # @return [Responses::AmlCheck]
    # @raise [ArgumentError, Error]
    def create_aml_check(request = nil, **params)
      body = build(Requests::AmlCheck, request, params).body
      post("/v1/aml-checks/new", body) { Responses::AmlCheck.from_api(_1) }
    end

    # The status and result of an AML check.
    #
    # @param id [String] the AML check ID
    # @return [Responses::AmlCheck]
    # @raise [ArgumentError, Error]
    def check_aml_status(id)
      body = { "id" => Requests::Validation.string(id, "id") }
      post("/v1/aml-checks/check", body) { Responses::AmlCheck.from_api(_1) }
    end

    # One page of past AML checks.
    #
    # @overload get_aml_history(request)
    #   @param request [Requests::AmlHistory]
    # @overload get_aml_history(page: 1, per_page: 10, status: nil)
    # @return [Responses::AmlHistory]
    # @raise [ArgumentError, Error]
    def get_aml_history(request = nil, **params)
      body = build(Requests::AmlHistory, request, params).body
      post("/v1/aml-checks/history", body) { Responses::AmlHistory.from_api(_1) }
    end

    # Subscription plans on sale, in the order the API lists them.
    #
    # @return [Array<Responses::SubscriptionPlan>]
    # @raise [Error]
    def get_subscriptions
      post("/v1/subscriptions", {}) { Responses::SubscriptionPlan.list_from_api(_1) }
    end

    # Subscribes an address to a plan from {#get_subscriptions}. Starting a subscription charges the plan's initial
    # price.
    #
    # @overload start_subscription(request)
    #   @param request [Requests::StartSubscription]
    # @overload start_subscription(subscription_id:, address:, duration_days: 0, transactions_limit: 0,
    #                              external_id: nil, activate_address: false)
    # @return [Responses::Subscription]
    # @raise [ArgumentError, Error]
    def start_subscription(request = nil, **params)
      body = build(Requests::StartSubscription, request, params).body
      post("/v1/subscription/start", body) { Responses::Subscription.from_api(_1) }
    end

    # The current state of a subscription, by its TronZap ID or by your external ID.
    #
    # @overload check_subscription(request)
    #   @param request [Requests::SubscriptionLookup]
    # @overload check_subscription(id: nil, external_id: nil)
    # @return [Responses::Subscription]
    # @raise [ArgumentError, Error]
    def check_subscription(request = nil, **params)
      body = build(Requests::SubscriptionLookup, request, params).body
      post("/v1/subscription/check", body) { Responses::Subscription.from_api(_1) }
    end

    # Stops a subscription, by its TronZap ID or by your external ID. A subscription with a transactions limit
    # cannot be stopped and fails with {ErrorCode::CANNOT_STOP_SUBSCRIPTION}.
    #
    # @overload stop_subscription(request)
    #   @param request [Requests::SubscriptionLookup]
    # @overload stop_subscription(id: nil, external_id: nil)
    # @return [Responses::Subscription]
    # @raise [ArgumentError, Error]
    def stop_subscription(request = nil, **params)
      body = build(Requests::SubscriptionLookup, request, params).body
      post("/v1/subscription/stop", body) { Responses::Subscription.from_api(_1) }
    end

    # One page of your subscriptions, newest first.
    #
    # @overload get_subscription_history(request)
    #   @param request [Requests::SubscriptionHistory]
    # @overload get_subscription_history(page: 1, per_page: 10, status: nil)
    # @return [Responses::SubscriptionHistory]
    # @raise [ArgumentError, Error]
    def get_subscription_history(request = nil, **params)
      body = build(Requests::SubscriptionHistory, request, params).body
      post("/v1/subscriptions/history", body) { Responses::SubscriptionHistory.from_api(_1) }
    end

    # @return [String] a description that leaves out the credentials
    def inspect
      "#<#{self.class.name} base_url=#{config.base_url.inspect}>"
    end

    private

    def build(type, request, params)
      raise ArgumentError, "pass either a #{type.name} or keyword arguments, not both" if request && !params.empty?

      case request
      when nil then type.new(**params)
      when type then request
      when Hash then type.new(**request.transform_keys(&:to_sym))
      else raise ArgumentError, "expected a #{type.name}, got #{request.class}"
      end
    end

    def create_transaction(request)
      post("/v1/transaction/new", request.body) { Responses::Transaction.from_api(_1) }
    end

    def post(path, payload, &)
      body = JSON.generate(payload)
      request = HttpAdapter::Request.new(
        http_method: :post,
        url: "#{config.base_url}#{path}",
        headers: headers(body),
        body: body,
        timeout: config.timeout
      )
      response = HttpAdapter.translate_errors { config.adapter.call(request) }
      ResponseDecoder.decode(response, &)
    end

    def headers(body)
      {
        "Authorization" => "Bearer #{config.api_token}",
        "X-Signature" => Digest::SHA256.hexdigest(body.b + config.api_secret.b),
        "Content-Type" => "application/json",
        "Accept" => "application/json",
        "User-Agent" => config.user_agent
      }.freeze
    end
  end
end
