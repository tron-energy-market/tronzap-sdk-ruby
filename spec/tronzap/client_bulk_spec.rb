# frozen_string_literal: true

RSpec.describe Tronzap::Client, "bulk orders" do
  include_context "with server"

  let(:calculation) do
    { "id" => "01kb2m7a1bc2de3fg4hj5km6np", "status" => "draft", "resource" => "energy", "duration" => 1,
      "total_amount" => 1240.1, "accepted" => 2, "rejected_count" => 1,
      "rejected" => [{ "row" => 3, "address" => "abc", "reason" => "invalid_address" }],
      "expires_at" => "2026-11-16T12:15:00+00:00" }
  end

  let(:order) do
    { "id" => "01kb2m5x9qj4v8n3c7d6e5f4g3", "external_id" => "my-order-42", "status" => "partial",
      "resource" => "energy", "duration" => 1, "force" => true, "max_price_increase" => 20,
      "webhook_url" => "https://example.com/tronzap/bulk", "total" => 4, "processed" => 4, "delivered" => 2,
      "failed" => 0, "in_review" => 0, "skipped" => 2,
      "skipped_by_reason" => { "address_not_activated" => 1, "price_increased" => 1 }, "rejected_count" => 1,
      "total_amount" => "1240.10", "charged_amount" => "620.05", "created_at" => "2026-11-16T12:05:00+00:00",
      "started_at" => "2026-11-16T12:06:00+00:00", "finalized_at" => "2026-11-16T12:09:00+00:00" }
  end

  let(:csv) do
    "row,address,amount,status,reason,charged,transaction_id\n" \
      "1,TPY1Kb8cKAZQfm95gXQQs2Mh8Uygtos21D,65000,delivered,,3.25,01kb2m9c4de5fg6hj7km8np9qr\n" \
      "2,TQn9Y2khEsLJW1ChVWFMSMeRDow5KcbLSE,131000,skipped,address_not_activated,,\n"
  end

  describe "#bulk_calculate" do
    it "sends the rows and maps the calculation" do
      server.respond_json(ok(calculation))
      result = client.bulk_calculate(items: [{ address: SpecHelpers::ADDRESS, amount: 65_000 },
                                             Tronzap::Requests::BulkItem.new(address: "abc", amount: 1)],
                                     duration: 24)

      expect(JSON.parse(server.last_request.body)).to eq(
        "resource" => "energy", "duration" => 24,
        "items" => [{ "address" => SpecHelpers::ADDRESS, "amount" => 65_000 }, { "address" => "abc", "amount" => 1 }]
      )
      expect(server.last_request.path).to eq("/v1/bulk/calculate")
      expect(result).to have_attributes(id: "01kb2m7a1bc2de3fg4hj5km6np", status: :draft, resource: "energy",
                                        duration: 1, total_amount: BigDecimal("1240.1"), accepted: 2,
                                        rejected_count: 1)
      expect(result.rejected).to eq([Tronzap::Models::BulkRejectedRow.new(row: 3, address: "abc",
                                                                          reason: "invalid_address")])
      expect(result.expires_at.value).to eq(Time.utc(2026, 11, 16, 12, 15))
    end

    it "raises BulkNoValidItemsError with the rejected rows" do
      rejected = [{ "row" => 1, "address" => "abc", "reason" => "invalid_address" },
                  { "row" => 2, "address" => "abc", "reason" => "duplicate" }]
      server.respond_json({ "code" => 94, "error" => "No valid items", "key" => "bulk_no_valid_items",
                            "result" => { "rejected" => rejected } })

      expect { client.bulk_calculate(items: [{ address: "abc", amount: 1 }, { address: "abc", amount: 1 }]) }
        .to raise_error(Tronzap::BulkNoValidItemsError, "No valid items") { |error|
          expect(error.code).to eq(Tronzap::ErrorCode::BULK_NO_VALID_ITEMS)
          expect(error.error_key).to eq("bulk_no_valid_items")
          expect(error.rejected.map(&:reason)).to eq(%w[invalid_address duplicate])
          expect(error.result["rejected"].size).to eq(2)
        }
    end
  end

  describe "#bulk_create" do
    it "sends every option and maps the order" do
      server.respond_json(ok(order))
      result = client.bulk_create(id: "calc-1", external_id: "my-order-42", force: true, max_price_increase: 0,
                                  webhook_url: "https://example.com/tronzap/bulk")

      expect(JSON.parse(server.last_request.body)).to eq(
        "id" => "calc-1", "external_id" => "my-order-42", "force" => true, "max_price_increase" => 0,
        "webhook_url" => "https://example.com/tronzap/bulk"
      )
      expect(result).to have_attributes(
        id: "01kb2m5x9qj4v8n3c7d6e5f4g3", external_id: "my-order-42", status: :partial, force: true,
        max_price_increase: 20, webhook_url: "https://example.com/tronzap/bulk", total: 4, processed: 4,
        delivered: 2, failed: 0, in_review: 0, skipped: 2, rejected_count: 1,
        skipped_by_reason: { "address_not_activated" => 1, "price_increased" => 1 },
        total_amount: BigDecimal("1240.10"), charged_amount: BigDecimal("620.05")
      )
      expect(result.finalized_at.value).to eq(Time.utc(2026, 11, 16, 12, 9))
    end

    it "sends only the id by default" do
      server.respond_json(ok(order))
      client.bulk_create(Tronzap::Requests::BulkCreate.new(id: "calc-1"))

      expect(JSON.parse(server.last_request.body)).to eq("id" => "calc-1")
    end

    it "raises BulkPriceChangedError with the new calculation" do
      server.respond_json({ "code" => 92, "error" => "Price changed", "key" => "bulk_price_changed",
                            "result" => calculation.merge("id" => "calc-2", "total_amount" => "1300.5") })

      expect { client.bulk_create(id: "calc-1") }.to raise_error(Tronzap::BulkPriceChangedError) { |error|
        expect(error).to be_a(Tronzap::ApiError)
        expect(error.code).to eq(Tronzap::ErrorCode::BULK_PRICE_CHANGED)
        expect(error.calculation).to have_attributes(id: "calc-2", total_amount: BigDecimal("1300.5"))
        expect(error.result["id"]).to eq("calc-2")
      }
    end

    [[92, '"text"'], [94, '{"rejected":"none"}'], [92, '{"total_amount":"a lot"}']].each do |code, result|
      it "keeps error #{code} with a result of an unexpected shape (#{result}) as an ApiError" do
        server.respond(200, %({"code":#{code},"error":"Bulk error","result":#{result}}))

        expect { client.bulk_create(id: "calc-1") }.to raise_error(Tronzap::ApiError) { |error|
          expect(error).to be_an_instance_of(Tronzap::ApiError)
          expect(error.code).to eq(code)
          expect(error.result).to eq(JSON.parse(result))
        }
      end
    end
  end

  describe "#bulk_check" do
    it "sends the ids and reads a running order" do
      server.respond_json(ok(order.merge("status" => "processing", "skipped" => 0, "skipped_by_reason" => [],
                                         "finalized_at" => nil, "external_id" => nil, "webhook_url" => nil)))
      result = client.bulk_check(Tronzap::Requests::BulkLookup.by_external_id("my-order-42"))

      expect(server.last_request.path).to eq("/v1/bulk/check")
      expect(JSON.parse(server.last_request.body)).to eq("external_id" => "my-order-42")
      expect(result).to have_attributes(status: :processing, skipped_by_reason: {}, finalized_at: nil,
                                        external_id: nil, webhook_url: nil)
    end

    it "raises ApiError for an unknown order" do
      server.respond_json({ "code" => 90, "error" => "Bulk order not found" }, status: 404)

      expect { client.bulk_check(id: "missing") }.to raise_error(Tronzap::ApiError) { |error|
        expect(error.code).to eq(Tronzap::ErrorCode::BULK_NOT_FOUND)
        expect(error.result).to be_nil
      }
    end

    %w[draft processing completed partial failed].each do |status|
      it "reads the #{status} status" do
        server.respond_json(ok(order.merge("status" => status)))

        expect(client.bulk_check(id: "bulk-1").status).to eq(status.to_sym)
      end
    end

    it "reports a status this SDK does not know as :unknown" do
      server.respond_json(ok(order.merge("status" => "paused")))

      expect(client.bulk_check(id: "bulk-1").status).to eq(:unknown)
    end
  end

  describe "#get_bulk_history" do
    it "sends the page and maps the orders" do
      server.respond_json(ok("page" => 2, "per_page" => 5, "total" => 6, "items" => [order]))
      history = client.get_bulk_history(page: 2, per_page: 5)

      expect(server.last_request.path).to eq("/v1/bulk/history")
      expect(JSON.parse(server.last_request.body)).to eq("page" => 2, "per_page" => 5)
      expect(history).to have_attributes(page: 2, per_page: 5, total: 6)
      expect(history.items.map(&:id)).to eq(["01kb2m5x9qj4v8n3c7d6e5f4g3"])
      expect(history).to be_frozen
      expect(history.items.first.skipped_by_reason).to be_frozen
    end

    it "sends the defaults" do
      server.respond_json(ok("items" => []))
      client.get_bulk_history

      expect(JSON.parse(server.last_request.body)).to eq("page" => 1, "per_page" => 10)
    end
  end

  describe "#bulk_report" do
    [[nil, { "id" => "bulk-1" }], [:skipped, { "id" => "bulk-1", "status" => "skipped" }],
     ["in_review", { "id" => "bulk-1", "status" => "in_review" }]].each do |status, body|
      it "returns the CSV for status #{status.inspect}" do
        server.respond(200, csv, "Content-Type" => "text/csv; charset=UTF-8")

        expect(client.bulk_report(Tronzap::Requests::BulkReport.by_id("bulk-1", status: status))).to eq(csv)
        expect(server.last_request.path).to eq("/v1/bulk/report")
        expect(JSON.parse(server.last_request.body)).to eq(body)
      end
    end

    it "reads the CSV as UTF-8 without a charset" do
      text = "row,address\n1,адреса-😀\n"
      server.respond(200, text, "Content-Type" => "text/csv")
      report = client.bulk_report(external_id: "my-order-42")

      expect(report).to eq(text)
      expect(report.encoding).to eq(Encoding::UTF_8)
    end

    it "raises ApiError for a JSON error" do
      server.respond_json({ "code" => 90, "error" => "Bulk order not found" }, status: 404)

      expect { client.bulk_report(id: "missing") }.to raise_error(Tronzap::ApiError) { |error|
        expect(error.code).to eq(Tronzap::ErrorCode::BULK_NOT_FOUND)
      }
    end

    it "raises HttpError for an error without an API payload" do
      server.respond(502, "<html>gateway</html>", "Content-Type" => "text/html")

      expect { client.bulk_report(id: "bulk-1") }.to raise_error(Tronzap::ServerError)
    end

    [["row,address\n", "text/plain"], ['{"code":0,"result":{}}', "application/json"]].each do |body, type|
      it "raises InvalidResponseError for a #{type} 2xx answer" do
        server.respond(200, body, "Content-Type" => type)

        expect { client.bulk_report(id: "bulk-1") }.to raise_error(Tronzap::InvalidResponseError) { |error|
          expect(error.response_body).to eq(body)
        }
      end
    end
  end

  describe "#verify_webhook_signature" do
    let(:body) { '{"id":"bulk-1","status":"completed","note":"año"}' }
    let(:signed) { Digest::SHA256.hexdigest(body.b + SpecHelpers::API_SECRET) }

    it "accepts the signature of the raw body" do
      expect(client.verify_webhook_signature(body, signed)).to be(true)
      expect(client.verify_webhook_signature(body.b, " #{signed.upcase} ")).to be(true)
    end

    it "rejects a wrong, missing or truncated signature" do
      expect(client.verify_webhook_signature("#{body} ", signed)).to be(false)
      expect(client.verify_webhook_signature(body, nil)).to be(false)
      expect(client.verify_webhook_signature(body, "")).to be(false)
      expect(client.verify_webhook_signature(body, signed[0, 32])).to be(false)
    end

    it "rejects a body that is not a String" do
      expect { client.verify_webhook_signature(nil, signed) }.to raise_error(ArgumentError)
    end
  end

  describe "validation" do
    {
      "no items" => ->(c) { c.bulk_calculate(items: []) },
      "items that are not a list" => ->(c) { c.bulk_calculate(items: "TAddress") },
      "an item without an address" => ->(c) { c.bulk_calculate(items: [{ amount: 1 }]) },
      "an item with a string amount" => ->(c) { c.bulk_calculate(items: [{ address: "T", amount: "1" }]) },
      "an item that is not a row" => ->(c) { c.bulk_calculate(items: ["TAddress"]) },
      "a zero bulk duration" => ->(c) { c.bulk_calculate(items: [{ address: "T", amount: 1 }], duration: 0) },
      "bulk_create without an id" => ->(c) { c.bulk_create(id: " ") },
      "a negative max_price_increase" => ->(c) { c.bulk_create(id: "calc-1", max_price_increase: -1) },
      "a non-boolean force" => ->(c) { c.bulk_create(id: "calc-1", force: "yes") },
      "bulk_check without any id" => lambda(&:bulk_check),
      "bulk_report without any id" => ->(c) { c.bulk_report(status: :skipped) },
      "an unknown report status" => ->(c) { c.bulk_report(id: "bulk-1", status: :lost) },
      "a zero bulk history page" => ->(c) { c.get_bulk_history(page: 0) }
    }.each do |name, call|
      it "rejects #{name} without sending a request" do
        expect { call.call(client) }.to raise_error(ArgumentError)
        expect(server.requests).to be_empty
      end
    end

    it "fills in the defaults" do
      expect(Tronzap::Requests::BulkCalculate.new(items: [{ "address" => "T", "amount" => 1 }]))
        .to have_attributes(duration: 1, items: [Tronzap::Requests::BulkItem.new(address: "T", amount: 1)])
      expect(Tronzap::Requests::BulkCreate.new(id: "calc-1"))
        .to have_attributes(external_id: nil, force: false, max_price_increase: nil, webhook_url: nil)
      expect(Tronzap::Requests::BulkHistory.new).to have_attributes(page: 1, per_page: 10)
    end
  end
end
