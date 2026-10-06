# frozen_string_literal: true

RSpec.describe Tronzap::Client, "concurrent use" do
  include_context "with server"

  it "keeps requests and responses apart when one client is shared between threads" do
    server.handle do |request|
      external_id = JSON.parse(request.body)["external_id"]
      [200, {}, JSON.generate(ok("id" => "tx-#{external_id}", "external_id" => external_id))]
    end

    results = Array.new(8) do |thread|
      Thread.new do
        Array.new(10) do |call|
          external_id = "order-#{thread}-#{call}"
          [external_id, client.create_energy_transaction(address: "TAddress", energy: 65_000, external_id: external_id)]
        end
      end
    end.flat_map(&:value)

    expect(results.size).to eq(80)
    results.each do |external_id, transaction|
      expect(transaction).to have_attributes(id: "tx-#{external_id}", external_id: external_id)
    end
    expect(server.requests).to all(satisfy { |request| request.headers["x-signature"] == signature(request.body) })
  end
end
