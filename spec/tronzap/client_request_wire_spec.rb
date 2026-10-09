# frozen_string_literal: true

RSpec.describe Tronzap::Client, "requests on the wire" do
  include_context "with server"

  {
    "get_services" => [lambda(&:get_services), "/v1/services", {}],
    "get_balance" => [lambda(&:get_balance), "/v1/balance", {}],
    "get_address_info" => [lambda { |c|
      c.get_address_info(SpecHelpers::ADDRESS)
    }, "/v1/address-info", { "address" => SpecHelpers::ADDRESS }],
    "estimate_energy" => [
      ->(c) { c.estimate_energy(from_address: "TSender", to_address: SpecHelpers::ADDRESS) },
      "/v1/estimate-energy", { "from_address" => "TSender", "to_address" => SpecHelpers::ADDRESS }
    ],
    "estimate_energy with a contract" => [
      lambda { |c|
        c.estimate_energy(from_address: "TSender", to_address: SpecHelpers::ADDRESS, contract_address: "TContract")
      },
      "/v1/estimate-energy", { "from_address" => "TSender", "to_address" => SpecHelpers::ADDRESS, "contract_address" => "TContract" }
    ],
    "calculate" => [
      ->(c) { c.calculate(address: SpecHelpers::ADDRESS, energy: 65_000) },
      "/v1/calculate", { "address" => SpecHelpers::ADDRESS, "amount" => 65_000, "duration" => 1 }
    ],
    "create_energy_transaction with defaults" => [
      ->(c) { c.create_energy_transaction(address: SpecHelpers::ADDRESS, energy: 65_000) },
      "/v1/transaction/new",
      { "service" => "energy",
        "params" => { "address" => SpecHelpers::ADDRESS, "amounts" => { "energy" => 65_000 }, "duration" => 1 } }
    ],
    "create_energy_transaction with every option" => [
      lambda { |c|
        c.create_energy_transaction(address: SpecHelpers::ADDRESS, energy: 65_000, duration: 24,
                                    external_id: "order-42", activate_address: true)
      },
      "/v1/transaction/new",
      {
        "service" => "energy",
        "params" => { "address" => SpecHelpers::ADDRESS, "amounts" => { "energy" => 65_000 }, "duration" => 24,
                      "activate_address" => true },
        "external_id" => "order-42"
      }
    ],
    "create_bandwidth_transaction" => [
      lambda { |c|
        c.create_bandwidth_transaction(address: SpecHelpers::ADDRESS, bandwidth: 345, external_id: "bandwidth-1")
      },
      "/v1/transaction/new",
      {
        "service" => "bandwidth",
        "params" => { "address" => SpecHelpers::ADDRESS, "amounts" => { "bandwidth" => 345 }, "duration" => 1 },
        "external_id" => "bandwidth-1"
      }
    ],
    "create_resource_bundle_transaction" => [
      lambda { |c|
        c.create_resource_bundle_transaction(address: SpecHelpers::ADDRESS, energy: 65_000, bandwidth: 345,
                                             external_id: "bundle-1", activate_address: true)
      },
      "/v1/transaction/new",
      {
        "service" => "resource_bundle",
        "params" => { "address" => SpecHelpers::ADDRESS, "amounts" => { "energy" => 65_000, "bandwidth" => 345 },
                      "duration" => 1, "activate_address" => true },
        "external_id" => "bundle-1"
      }
    ],
    "create_address_activation_transaction" => [
      ->(c) { c.create_address_activation_transaction(address: SpecHelpers::ADDRESS, external_id: "activation-1") },
      "/v1/transaction/new",
      { "service" => "activate_address", "params" => { "address" => SpecHelpers::ADDRESS }, "external_id" => "activation-1" }
    ],
    "check_transaction by id" => [
      ->(c) { c.check_transaction(id: "tx-1") }, "/v1/transaction/check", { "id" => "tx-1" }
    ],
    "check_transaction by external id" => [
      ->(c) { c.check_transaction(Tronzap::Requests::CheckTransaction.by_external_id("order-42")) },
      "/v1/transaction/check", { "external_id" => "order-42" }
    ],
    "check_transaction by both" => [
      ->(c) { c.check_transaction(id: "tx-1", external_id: "order-42") },
      "/v1/transaction/check", { "id" => "tx-1", "external_id" => "order-42" }
    ],
    "get_direct_recharge_info" => [lambda(&:get_direct_recharge_info), "/v1/direct-recharge-info", {}],
    "get_aml_services" => [lambda(&:get_aml_services), "/v1/aml-checks", {}],
    "create_aml_check for an address" => [
      ->(c) { c.create_aml_check(Tronzap::Requests::AmlCheck.for_address("TRX", SpecHelpers::ADDRESS)) },
      "/v1/aml-checks/new", { "type" => "address", "network" => "TRX", "address" => SpecHelpers::ADDRESS }
    ],
    "create_aml_check for a hash" => [
      lambda { |c|
        c.create_aml_check(Tronzap::Requests::AmlCheck.for_hash("BTC", "bc1Address", "TX_HASH", direction: :withdrawal))
      },
      "/v1/aml-checks/new",
      { "type" => "hash", "network" => "BTC", "address" => "bc1Address", "hash" => "TX_HASH",
        "direction" => "withdrawal" }
    ],
    "check_aml_status" => [->(c) { c.check_aml_status("aml-1") }, "/v1/aml-checks/check", { "id" => "aml-1" }],
    "get_aml_history with defaults" => [
      lambda(&:get_aml_history), "/v1/aml-checks/history", { "page" => 1, "per_page" => 10 }
    ],
    "get_aml_history with a filter" => [
      ->(c) { c.get_aml_history(page: 2, per_page: 50, status: "completed") },
      "/v1/aml-checks/history", { "page" => 2, "per_page" => 50, "status" => "completed" }
    ],
    "get_subscriptions" => [lambda(&:get_subscriptions), "/v1/subscriptions", {}],
    "start_subscription with defaults" => [
      ->(c) { c.start_subscription(subscription_id: "unlimited_energy", address: "TAddress") },
      "/v1/subscription/start",
      { "subscription_id" => "unlimited_energy",
        "params" => { "address" => "TAddress", "duration" => 0, "transactions_limit" => 0 } }
    ],
    "start_subscription with every option" => [
      lambda { |c|
        c.start_subscription(subscription_id: "energy_pack_100", address: "TAddress", duration_days: 30,
                             transactions_limit: 10, external_id: "sub-1", activate_address: true)
      },
      "/v1/subscription/start",
      { "subscription_id" => "energy_pack_100", "external_id" => "sub-1",
        "params" => { "address" => "TAddress", "duration" => 30, "transactions_limit" => 10,
                      "activate_address" => true } }
    ],
    "start_subscription with an external id of 0" => [
      ->(c) { c.start_subscription(subscription_id: "unlimited_energy", address: "TAddress", external_id: "0") },
      "/v1/subscription/start",
      { "subscription_id" => "unlimited_energy", "external_id" => "0",
        "params" => { "address" => "TAddress", "duration" => 0, "transactions_limit" => 0 } }
    ],
    "check_subscription by id" => [
      ->(c) { c.check_subscription(id: "sub-id") }, "/v1/subscription/check", { "id" => "sub-id" }
    ],
    "check_subscription by external id" => [
      ->(c) { c.check_subscription(Tronzap::Requests::SubscriptionLookup.by_external_id("sub-1")) },
      "/v1/subscription/check", { "external_id" => "sub-1" }
    ],
    "stop_subscription by id" => [
      ->(c) { c.stop_subscription(Tronzap::Requests::SubscriptionLookup.by_id("sub-id")) },
      "/v1/subscription/stop", { "id" => "sub-id" }
    ],
    "stop_subscription by both" => [
      ->(c) { c.stop_subscription(id: "sub-id", external_id: "sub-1") },
      "/v1/subscription/stop", { "id" => "sub-id", "external_id" => "sub-1" }
    ],
    "get_subscription_history with defaults" => [
      lambda(&:get_subscription_history), "/v1/subscriptions/history", { "page" => 1, "per_page" => 10 }
    ],
    "get_subscription_history with a filter" => [
      ->(c) { c.get_subscription_history(page: 2, per_page: 50, status: :active) },
      "/v1/subscriptions/history", { "page" => 2, "per_page" => 50, "status" => "active" }
    ]
  }.each do |name, (call, path, expected_body)|
    it "sends #{name} to #{path}" do
      call.call(client)
      request = server.last_request

      expect(request.http_method).to eq("POST")
      expect(request.path).to eq(path)
      expect(JSON.parse(request.body)).to eq(expected_body)
      expect(request.headers["x-signature"]).to eq(signature(request.body))
    end
  end

  it "sends an empty JSON object to endpoints without parameters" do
    client.get_balance

    expect(server.last_request.body).to eq("{}")
  end

  it "sends the credentials and content headers" do
    client.get_balance
    headers = server.last_request.headers

    expect(headers["authorization"]).to eq("Bearer #{SpecHelpers::API_TOKEN}")
    expect(headers["content-type"]).to eq("application/json")
    expect(headers["accept"]).to eq("application/json")
    expect(headers["user-agent"]).to eq("tronzap-sdk-ruby/#{Tronzap::VERSION}")
  end

  it "never sends the API secret" do
    client.create_energy_transaction(address: SpecHelpers::ADDRESS, energy: 65_000)
    request = server.last_request

    expect(request.body).not_to include(SpecHelpers::API_SECRET)
    expect(request.headers.values.join).not_to include(SpecHelpers::API_SECRET)
  end

  it "signs the exact bytes the server received, including non-ASCII text" do
    client.create_energy_transaction(address: SpecHelpers::ADDRESS, energy: 65_000, external_id: "pedido-año-订单-😀")
    request = server.last_request

    expect(JSON.parse(request.body)["external_id"]).to eq("pedido-año-订单-😀")
    expect(request.headers["x-signature"]).to eq(signature(request.body))
  end

  it "signs with a non-ASCII secret" do
    secret = "clé/秘密+1"
    unicode_client = described_class.new(api_token: "t", api_secret: secret, base_url: server.url)
    unicode_client.get_balance
    request = server.last_request

    expect(request.headers["x-signature"]).to eq(Digest::SHA256.hexdigest(request.body + secret.b))
  end

  it "keeps a path prefix of the base URL" do
    prefixed = build_client(server, base_url: "#{server.url}/proxy/")
    prefixed.get_balance

    expect(server.last_request.path).to eq("/proxy/v1/balance")
  end

  it "accepts a request object or a hash of parameters" do
    client.create_energy_transaction(Tronzap::Requests::EnergyTransaction.new(address: SpecHelpers::ADDRESS,
                                                                              energy: 65_000))
    from_object = JSON.parse(server.last_request.body)
    client.create_energy_transaction({ "address" => SpecHelpers::ADDRESS, "energy" => 65_000 })

    expect(JSON.parse(server.last_request.body)).to eq(from_object)
  end
end
