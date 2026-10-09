# frozen_string_literal: true

RSpec.describe Tronzap::Client, "response mapping" do
  include_context "with server"

  def answer(result)
    server.respond_json(ok(result))
  end

  def decimal(text)
    BigDecimal(text)
  end

  describe "#get_services" do
    it "maps energy and bandwidth tiers and the activation price" do
      answer(
        "energy" => [{ "duration" => 1, "min_amount" => 32_000, "max_amount" => 5_000_000, "price" => 0.0841,
                       "price_32k" => "2.6912", "price_65k" => 5.4665, "price_131k" => 11.0171 }],
        "bandwidth" => [{ "duration" => 1, "min_amount" => 300, "max_amount" => 100_000, "price" => "1" }],
        "activate_address" => { "price" => 1.4 }
      )
      services = client.get_services

      expect(services.energy.first).to eq(
        Tronzap::Models::EnergyRate.new(duration: 1, min_amount: 32_000, max_amount: 5_000_000, min_energy: 32_000,
                                        max_energy: 5_000_000, price: decimal("0.0841"), price_32k: decimal("2.6912"),
                                        price_65k: decimal("5.4665"), price_131k: decimal("11.0171"))
      )
      expect(services.bandwidth.first.price).to eq(decimal("1"))
      expect(services.activate_address.price).to eq(decimal("1.4"))
    end

    it "fills the deprecated min_energy and max_energy from min_amount and max_amount" do
      answer("energy" => [{ "min_amount" => 32_000, "max_amount" => 5_000_000, "min_energy" => 1,
                            "max_energy" => 2 }])
      rate = client.get_services.energy.first

      expect([rate.min_energy, rate.max_energy]).to eq([32_000, 5_000_000])
    end

    it "prices energy per 1000 units" do
      answer("energy" => [{ "price" => 0.03, "price_65k" => 1.95 }])
      rate = client.get_services.energy.first

      expect(rate.price * 65_000 / 1000).to eq(rate.price_65k)
    end

    it "keeps decimal prices exact" do
      answer("energy" => [{ "price" => 0.1 }])

      expect(client.get_services.energy.first.price * 3).to eq(decimal("0.3"))
    end

    it "reports a missing activation price as nil and missing tiers as empty lists" do
      answer({})
      services = client.get_services

      expect(services.activate_address).to be_nil
      expect(services.energy).to eq([])
      expect(services.bandwidth).to eq([])
    end
  end

  it "maps the account balance" do
    answer("balance" => "12.345678", "address" => "TDepositAddress")

    expect(client.get_balance).to eq(
      Tronzap::Responses::AccountBalance.new(balance: decimal("12.345678"), address: "TDepositAddress")
    )
  end

  describe "#get_address_info" do
    it "maps resources and balances" do
      answer("resources" => { "energy" => 65_000, "bandwidth" => "345" },
             "balances" => { "TRX" => "1.5", "USDT" => 20 })
      info = client.get_address_info("TAddress")

      expect(info.resources).to eq(Tronzap::Models::AddressResources.new(energy: 65_000, bandwidth: 345))
      expect(info.balances).to eq("TRX" => decimal("1.5"), "USDT" => decimal("20"))
    end

    it "reads an empty PHP array as an empty object" do
      answer("resources" => [], "balances" => [])
      info = client.get_address_info("TAddress")

      expect(info.resources.energy).to eq(0)
      expect(info.balances).to eq({})
    end
  end

  it "maps an energy estimate" do
    answer("amount" => 65_000, "duration" => 1, "price" => 5.4665, "activation_fee" => 0,
           "total" => "5.4665", "from_address" => "TSender", "to_address" => "TRecipient",
           "contract_address" => Tronzap::USDT_CONTRACT_ADDRESS)
    estimate = client.estimate_energy(from_address: "TSender", to_address: "TRecipient")

    expect(estimate.amount).to eq(65_000)
    expect(estimate.energy).to eq(65_000)
    expect(estimate.total).to eq(decimal("5.4665"))
    expect(estimate.activation_fee).to eq(0)
    expect(estimate.contract_address).to eq(Tronzap::USDT_CONTRACT_ADDRESS)
  end

  it "fills the deprecated estimate energy from amount" do
    answer("amount" => 65_000, "energy" => 64_285)

    expect(client.estimate_energy(from_address: "TSender", to_address: "TRecipient").energy).to eq(65_000)
  end

  it "maps a calculation, reading the service from the type field" do
    answer("address" => "TAddress", "type" => "energy", "amount" => 65_000, "duration" => 1,
           "price" => 5.4665, "activation_fee" => 1.4, "total" => 6.8665)
    calculation = client.calculate(address: "TAddress", energy: 65_000)

    expect(calculation.service).to eq(:energy)
    expect(calculation.amount).to eq(65_000)
    expect(calculation.energy).to eq(65_000)
    expect(calculation.total).to eq(decimal("6.8665"))
  end

  it "fills the deprecated calculation energy from amount" do
    answer("amount" => 65_000, "energy" => 64_285)

    expect(client.calculate(address: "TAddress", energy: 65_000).energy).to eq(65_000)
  end

  describe "transactions" do
    let(:created) do
      {
        "id" => "tx-1", "external_id" => "order-42", "service" => "energy",
        "params" => { "address" => "TAddress", "amounts" => { "energy" => 65_000 }, "duration" => 1,
                      "activate_address" => true },
        "status" => "new", "amount" => 5.4665, "created_at" => "2026-08-01T12:00:00+00:00", "hash" => nil
      }
    end

    it "maps a created transaction" do
      answer(created)
      transaction = client.create_energy_transaction(address: "TAddress", energy: 65_000)

      expect(transaction).to have_attributes(id: "tx-1", external_id: "order-42", service: :energy, status: :new,
                                             amount: decimal("5.4665"), transaction_hash: nil)
      expect(transaction.params).to eq(
        Tronzap::Models::TransactionParams.new(
          address: "TAddress", duration: 1, activate_address: true,
          amounts: Tronzap::Models::ResourceAmounts.new(energy: 65_000, bandwidth: 0)
        )
      )
      expect(transaction.created_at.value).to eq(Time.utc(2026, 8, 1, 12))
      expect(transaction.created_at.raw).to eq("2026-08-01T12:00:00+00:00")
    end

    it "reads an amount sent as a string the same as one sent as a number" do
      answer(created)
      from_number = client.create_energy_transaction(address: "TAddress", energy: 65_000)
      answer(created.merge("amount" => "5.4665", "status" => "success", "hash" => "abc123"))
      from_string = client.check_transaction(id: "tx-1")

      expect(from_string.amount).to eq(from_number.amount)
      expect(from_string.status).to eq(:success)
      expect(from_string.transaction_hash).to eq("abc123")
    end

    it "reports a status this SDK does not know as :unknown" do
      answer(created.merge("status" => "refunded", "service" => "something_new"))
      transaction = client.check_transaction(id: "tx-1")

      expect(transaction.status).to eq(:unknown)
      expect(transaction.service).to eq(:unknown)
    end

    it "reads a bundle the API reports as an energy transaction" do
      answer(created.merge("params" => { "address" => "TAddress", "amounts" => { "energy" => 65_000,
                                                                                 "bandwidth" => 345 } }))
      transaction = client.check_transaction(id: "tx-1")

      expect(transaction.service).to eq(:energy)
      expect(transaction.params.amounts).to eq(Tronzap::Models::ResourceAmounts.new(energy: 65_000, bandwidth: 345))
    end

    it "reads the amounts of older transactions" do
      answer(created.merge("service" => "bandwidth", "params" => { "address" => "TAddress", "amount" => "345" }))
      bandwidth = client.check_transaction(id: "tx-1")
      answer(created.merge("params" => { "address" => "TAddress", "energy_amount" => 65_000 }))
      energy = client.check_transaction(id: "tx-2")

      expect(bandwidth.params.amounts).to eq(Tronzap::Models::ResourceAmounts.new(energy: 0, bandwidth: 345))
      expect(energy.params.amounts).to eq(Tronzap::Models::ResourceAmounts.new(energy: 65_000, bandwidth: 0))
    end

    it "keeps an unparseable timestamp instead of failing the response" do
      answer(created.merge("created_at" => "yesterday"))
      created_at = client.check_transaction(id: "tx-1").created_at

      expect(created_at.value).to be_nil
      expect(created_at.raw).to eq("yesterday")
    end
  end

  it "maps the direct recharge info" do
    answer("address" => "TPayHere",
           "rates" => [{ "duration" => 1, "min_energy" => 32_000, "max_energy" => 200_000, "price" => "0.09",
                         "price_32k" => 2.88, "price_65k" => 5.85, "price_131k" => 11.79 }])
    info = client.get_direct_recharge_info

    expect(info.address).to eq("TPayHere")
    expect(info.rates.first.price_65k).to eq(decimal("5.85"))
  end

  it "maps the AML services list" do
    answer([{ "id" => "aml-address", "type" => "address", "price" => "2" },
            { "id" => "aml-hash", "type" => "hash", "price" => 3 }])

    expect(client.get_aml_services.map { [_1.id, _1.type, _1.price] }).to eq(
      [["aml-address", :address, decimal("2")], ["aml-hash", :hash, decimal("3")]]
    )
  end

  describe "AML checks" do
    let(:completed) do
      {
        "id" => "aml-1", "type" => "hash", "address" => "bc1Address", "hash" => "TX_HASH", "direction" => "deposit",
        "network" => "BTC", "status" => "completed", "risk_score" => "35.3", "risk_level" => "medium",
        "blacklist" => false, "checked_at" => "2026-08-01 12:00:00",
        "risk_factors" => [{ "name" => "exchange", "label" => "Exchange", "group" => "trusted", "score" => 0.2 }]
      }
    end

    it "maps a completed check" do
      answer(completed)
      check = client.check_aml_status("aml-1")

      expect(check).to have_attributes(type: :hash, transaction_hash: "TX_HASH", direction: :deposit,
                                       status: :completed, risk_score: decimal("35.3"), risk_level: :medium,
                                       blacklist: false)
      expect(check.risk_factors).to eq(
        [Tronzap::Models::AmlRiskFactor.new(name: "exchange", label: "Exchange", group: "trusted",
                                            score: decimal("0.2"))]
      )
      expect(check.checked_at.value).to eq(Time.utc(2026, 8, 1, 12))
    end

    it "keeps a score of 0 apart from no score yet" do
      answer(completed.merge("risk_score" => "0"))
      scored = client.check_aml_status("aml-1")
      answer(completed.merge("status" => "pending", "risk_score" => nil, "risk_level" => nil, "checked_at" => nil))
      pending = client.check_aml_status("aml-1")

      expect(scored.risk_score).to eq(0)
      expect(pending.risk_score).to be_nil
      expect(pending.risk_level).to be_nil
      expect(pending.checked_at).to be_nil
    end

    it "maps a page of history" do
      answer("page" => 1, "per_page" => 10, "total" => 1, "items" => [completed])
      history = client.get_aml_history

      expect(history).to have_attributes(page: 1, per_page: 10, total: 1)
      expect(history.items.map(&:id)).to eq(["aml-1"])
    end
  end

  describe "subscriptions" do
    let(:plan) do
      { "id" => 8, "name" => "Unlimited Energy", "activation_fee" => 0, "initial_price" => 8, "price" => 2.8,
        "transactions_limit" => 0, "duration_days" => 0 }
    end
    let(:params) do
      { "address" => "TAddress", "duration" => 30, "transactions_limit" => 0, "activate_address" => false }
    end
    let(:started) do
      { "id" => "01m4e1z3q0r7x225zc6p63m5ey", "subscription_id" => "unlimited_energy",
        "created_at" => "2026-10-08T15:26:32+00:00", "expire_at" => "2026-11-07T15:26:32+00:00",
        "address" => "TAddress", "status" => "active", "external_id" => "sub-1", "params" => params }
    end
    let(:stopped) do
      { "id" => "01m4e1z3q0r7x225zc6p63m5ey", "subscription_id" => "unlimited_energy",
        "created_at" => "2026-10-08T15:26:32+00:00", "stopped_at" => "2026-10-08T15:28:44+00:00",
        "status" => "stopped", "external_id" => "sub-1", "params" => params }
    end
    let(:history_item) do
      { "id" => "01m4e1z3q0r7x225zc6p63m5ey", "status" => "active", "subscription_id" => "unlimited_energy",
        "address" => "TAddress", "transactions_limit" => 0, "transactions_used" => 4, "energy_used" => 262_000,
        "total_price" => 13.6, "started_at" => "2026-10-08T15:26:33+00:00",
        "renewed_at" => "2026-10-08T15:27:35+00:00", "stopped_at" => nil, "expire_at" => "2026-11-07T15:26:32+00:00",
        "created_at" => "2026-10-08T15:26:32+00:00" }
    end

    it "maps the plans in the order the API lists them, keyed by subscription_id" do
      answer("unlimited_energy" => plan,
             "energy_pack_100" => { "id" => 2, "name" => "Energy Pack", "activation_fee" => "2.0",
                                    "initial_price" => "10", "price" => "0", "transactions_limit" => 10,
                                    "duration_days" => 5 })
      plans = client.get_subscriptions

      expect(plans.map(&:subscription_id)).to eq(%w[unlimited_energy energy_pack_100])
      expect(plans.first).to eq(
        Tronzap::Responses::SubscriptionPlan.new(subscription_id: "unlimited_energy", id: 8, name: "Unlimited Energy",
                                                 activation_fee: decimal("0"), initial_price: decimal("8"),
                                                 price: decimal("2.8"), transactions_limit: 0, duration_days: 0)
      )
      expect(plans.last).to have_attributes(id: 2, activation_fee: decimal("2"), transactions_limit: 10,
                                            duration_days: 5)
    end

    it "keeps the API order of plans whose keys are not sorted" do
      answer("zeta" => plan, "alpha" => plan, "mid" => plan)

      plans = client.get_subscriptions

      expect(plans.map(&:subscription_id)).to eq(%w[zeta alpha mid])
      expect(plans).to be_frozen
    end

    [{}, []].each do |empty|
      it "reads #{JSON.generate(empty)} as no plans" do
        answer(empty)

        expect(client.get_subscriptions).to eq([])
      end
    end

    it "maps a started subscription" do
      answer(started)
      subscription = client.start_subscription(subscription_id: "unlimited_energy", address: "TAddress",
                                               duration_days: 30, external_id: "sub-1")

      expect(subscription).to have_attributes(id: "01m4e1z3q0r7x225zc6p63m5ey", subscription_id: "unlimited_energy",
                                              external_id: "sub-1", address: "TAddress", status: :active,
                                              transactions_used: nil, total_price: nil, stopped_at: nil)
      expect(subscription.params).to eq(
        Tronzap::Models::SubscriptionParams.new(address: "TAddress", duration_days: 30, transactions_limit: 0,
                                                activate_address: false)
      )
      expect(subscription.created_at.value).to eq(Time.utc(2026, 10, 8, 15, 26, 32))
      expect(subscription.expire_at.value).to eq(Time.utc(2026, 11, 7, 15, 26, 32))
    end

    it "maps a checked subscription the same as a started one" do
      answer(started)
      from_start = client.start_subscription(subscription_id: "unlimited_energy", address: "TAddress")
      from_check = client.check_subscription(external_id: "sub-1")

      expect(from_check).to eq(from_start)
    end

    it "maps a stopped subscription without an address or expiry" do
      answer(stopped)
      subscription = client.stop_subscription(id: "01m4e1z3q0r7x225zc6p63m5ey")

      expect(subscription).to have_attributes(status: :stopped, address: nil, expire_at: nil)
      expect(subscription.stopped_at.value).to eq(Time.utc(2026, 10, 8, 15, 28, 44))
      expect(subscription.params.address).to eq("TAddress")
    end

    it "reports a subscription status this SDK does not know as :unknown" do
      answer(started.merge("status" => "paused"))

      expect(client.check_subscription(id: "sub-id").status).to eq(:unknown)
    end

    it "maps a page of history with usage counters and without params" do
      answer("page" => 1, "per_page" => 10, "total" => 1, "items" => [history_item])
      history = client.get_subscription_history
      item = history.items.first

      expect(history).to have_attributes(page: 1, per_page: 10, total: 1)
      expect(item).to have_attributes(status: :active, transactions_limit: 0, transactions_used: 4,
                                      energy_used: 262_000, total_price: decimal("13.6"), params: nil,
                                      external_id: nil, stopped_at: nil)
      expect(item.started_at.value).to eq(Time.utc(2026, 10, 8, 15, 26, 33))
      expect(item.renewed_at.value).to eq(Time.utc(2026, 10, 8, 15, 27, 35))
    end

    it "reads a history total price sent as a string" do
      answer("page" => 1, "items" => [history_item.merge("total_price" => "8.00")])

      expect(client.get_subscription_history.items.first.total_price).to eq(decimal("8"))
    end
  end

  describe "immutability" do
    it "returns frozen results with frozen collections" do
      server.respond_json(ok("page" => 1, "items" => [{ "id" => "aml-1", "risk_factors" => [{ "name" => "x" }] }]))
      history = client.get_aml_history

      expect(history).to be_frozen
      expect(history.items).to be_frozen
      expect(history.items.first.risk_factors).to be_frozen
      expect { history.items << nil }.to raise_error(FrozenError)
    end
  end

  describe "a result of the wrong shape" do
    {
      "a result that is not an object" => ["text", lambda(&:get_balance)],
      "an amount that is not a number" => [{ "balance" => "a lot" }, lambda(&:get_balance)],
      "an infinite amount" => [{ "balance" => "Infinity" }, lambda(&:get_balance)],
      "a fractional integer" => [{ "resources" => { "energy" => "12.5" } }, ->(c) { c.get_address_info("TAddress") }],
      "a list that is an object" => [{ "energy" => { "price" => 1 } }, lambda(&:get_services)],
      "a boolean that is a word" => [{ "blacklist" => "maybe" }, ->(c) { c.check_aml_status("aml-1") }],
      "subscription plans that are text" => ["plans", lambda(&:get_subscriptions)],
      "subscription plans that are a number" => [42, lambda(&:get_subscriptions)],
      "a subscription plan that is not an object" => [{ "unlimited_energy" => "x" }, lambda(&:get_subscriptions)]
    }.each do |name, (result, call)|
      it "raises InvalidResponseError for #{name}" do
        answer(result)

        expect { call.call(client) }.to raise_error(Tronzap::InvalidResponseError) { |error|
          expect(error.status).to eq(200)
          expect(error.response_body).to eq(JSON.generate(ok(result)))
        }
      end
    end
  end
end
