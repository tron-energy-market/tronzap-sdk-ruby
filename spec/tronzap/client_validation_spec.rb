# frozen_string_literal: true

RSpec.describe Tronzap::Client, "argument validation" do
  include_context "with server"

  {
    "a blank address" => ->(c) { c.create_energy_transaction(address: " ", energy: 65_000) },
    "a missing address" => ->(c) { c.create_energy_transaction(energy: 65_000) },
    "a zero energy amount" => ->(c) { c.create_energy_transaction(address: SpecHelpers::ADDRESS, energy: 0) },
    "a negative bandwidth amount" => lambda { |c|
      c.create_bandwidth_transaction(address: SpecHelpers::ADDRESS, bandwidth: -345)
    },
    "an energy amount given as a string" => lambda { |c|
      c.create_energy_transaction(address: SpecHelpers::ADDRESS, energy: "65000")
    },
    "an energy amount given as a float" => ->(c) { c.calculate(address: SpecHelpers::ADDRESS, energy: 65_000.0) },
    "a zero duration" => lambda { |c|
      c.create_energy_transaction(address: SpecHelpers::ADDRESS, energy: 65_000, duration: 0)
    },
    "a blank external id" => lambda { |c|
      c.create_address_activation_transaction(address: SpecHelpers::ADDRESS, external_id: "")
    },
    "a non-boolean activate_address" => lambda { |c|
      c.create_resource_bundle_transaction(address: SpecHelpers::ADDRESS, energy: 65_000, bandwidth: 345,
                                           activate_address: "yes")
    },
    "a bundle without bandwidth" => lambda { |c|
      c.create_resource_bundle_transaction(address: SpecHelpers::ADDRESS, energy: 65_000)
    },
    "check_transaction without any id" => lambda(&:check_transaction),
    "an unknown keyword" => lambda { |c|
      c.create_energy_transaction(address: SpecHelpers::ADDRESS, energy: 65_000, speed: :fast)
    },
    "a request and keywords together" => lambda { |c|
      c.calculate(Tronzap::Requests::Calculate.new(address: SpecHelpers::ADDRESS, energy: 65_000), duration: 24)
    },
    "a request of the wrong type" => lambda { |c|
      c.create_energy_transaction(Tronzap::Requests::Calculate.new(address: SpecHelpers::ADDRESS, energy: 65_000))
    },
    "a nil address for get_address_info" => ->(c) { c.get_address_info(nil) },
    "a blank AML check id" => ->(c) { c.check_aml_status("") },
    "an unknown AML check type" => lambda { |c|
      c.create_aml_check(type: :wallet, network: "TRX", address: SpecHelpers::ADDRESS)
    },
    "a hash check without a hash" => ->(c) { c.create_aml_check(type: :hash, network: "BTC", address: "bc1") },
    "an unknown direction" => lambda { |c|
      c.create_aml_check(Tronzap::Requests::AmlCheck.for_hash("BTC", "bc1", "TX_HASH", direction: :sideways))
    },
    "a zero history page" => ->(c) { c.get_aml_history(page: 0) },
    "an unknown history status" => ->(c) { c.get_aml_history(status: :bogus) },
    "an estimate without a recipient" => ->(c) { c.estimate_energy(from_address: SpecHelpers::ADDRESS) }
  }.each do |name, call|
    it "rejects #{name} without sending a request" do
      expect { call.call(client) }.to raise_error(ArgumentError)
      expect(server.requests).to be_empty
    end
  end

  it "names the invalid field" do
    expect { client.create_energy_transaction(address: SpecHelpers::ADDRESS, energy: 0) }
      .to raise_error(ArgumentError, /energy must be a positive Integer, got 0/)
  end

  it "accepts enum values given as strings" do
    request = Tronzap::Requests::AmlCheck.new(type: "hash", network: "BTC", address: "bc1",
                                              transaction_hash: "TX_HASH", direction: "deposit")

    expect(request).to have_attributes(type: :hash, direction: :deposit)
  end

  it "fills in the defaults the API expects" do
    expect(Tronzap::Requests::EnergyTransaction.new(address: SpecHelpers::ADDRESS, energy: 65_000))
      .to have_attributes(duration: 1, external_id: nil, activate_address: false)
    expect(Tronzap::Requests::AmlHistory.new).to have_attributes(page: 1, per_page: 10, status: nil)
  end

  it "keeps validating when a request is copied with #with" do
    request = Tronzap::Requests::EnergyTransaction.new(address: SpecHelpers::ADDRESS, energy: 65_000)

    expect(request.with(energy: 345).energy).to eq(345)
    expect { request.with(energy: -1) }.to raise_error(ArgumentError)
  end

  it "does not let later changes to a passed string leak into a request" do
    text = +"TRecipientAddress"
    request = Tronzap::Requests::AddressActivation.new(address: text)
    text << "X"

    expect(request.address).to eq(SpecHelpers::ADDRESS)
    expect(request.address).to be_frozen
  end
end
