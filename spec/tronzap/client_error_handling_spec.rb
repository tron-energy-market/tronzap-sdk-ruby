# frozen_string_literal: true

RSpec.describe Tronzap::Client, "error handling" do
  include_context "with server"

  describe "API errors" do
    let(:payload) do
      { "code" => 6, "error" => "Insufficient funds", "key" => "insufficient_funds", "request_id" => "req-1" }
    end

    [200, 400, 422, 500].each do |status|
      it "raises ApiError for a non-zero code with HTTP #{status}" do
        server.respond_json(payload, status: status)

        expect { client.get_balance }.to raise_error(Tronzap::ApiError, "Insufficient funds") { |error|
          expect(error).to have_attributes(code: Tronzap::ErrorCode::INSUFFICIENT_FUNDS, status: status,
                                           error_key: "insufficient_funds", request_id: "req-1",
                                           response_body: JSON.generate(payload))
        }
      end
    end

    it "reads a code sent as a string" do
      server.respond_json(payload.merge("code" => "25"))

      expect { client.get_balance }.to raise_error(Tronzap::ApiError) { |error|
        expect(error.code).to eq(Tronzap::ErrorCode::ADDRESS_ALREADY_ACTIVATED)
      }
    end

    it "keeps a code this SDK does not know" do
      server.respond_json({ "code" => 777, "error" => "Brand new error" })

      expect { client.get_balance }.to raise_error(Tronzap::ApiError) { |error| expect(error.code).to eq(777) }
    end

    it "keeps the field-specific error key" do
      server.respond_json({ "code" => 10, "error" => "Invalid TRON address",
                            "key" => "invalid_tron_address.from_address" })

      expect { client.estimate_energy(from_address: "x", to_address: "TRecipient") }
        .to raise_error(Tronzap::ApiError) { |error|
          expect(error.code).to eq(Tronzap::ErrorCode::INVALID_TRON_ADDRESS)
          expect(error.error_key).to eq("invalid_tron_address.from_address")
        }
    end

    it "keeps the result sent with an error" do
      server.respond_json({ "code" => 93, "error" => "Too many items", "result" => { "max" => 10_000 } })

      expect { client.get_balance }.to raise_error(Tronzap::ApiError) { |error|
        expect(error.code).to eq(Tronzap::ErrorCode::BULK_TOO_MANY_ITEMS)
        expect(error.result).to eq("max" => 10_000)
      }
    end

    it "reports no result and no retry_after when the API sent neither" do
      server.respond_json(payload)

      expect { client.get_balance }.to raise_error(Tronzap::ApiError) { |error|
        expect(error).to have_attributes(result: nil, retry_after: nil)
      }
    end

    it "reads a rate limit the API reports, with Retry-After" do
      server.respond_json({ "code" => 429, "error" => "Too many requests", "key" => "rate_limited" },
                          status: 429, headers: { "Retry-After" => "30" })

      expect { client.get_balance }.to raise_error(Tronzap::ApiError) { |error|
        expect(error).not_to be_a(Tronzap::HttpError)
        expect(error.code).to eq(Tronzap::ErrorCode::RATE_LIMITED)
        expect(error.retry_after).to eq(30.0)
      }
    end

    it "reads retry_after from the body when the header is missing" do
      server.respond_json({ "code" => 429, "error" => "Too many requests", "retry_after" => 12 }, status: 429)

      expect { client.get_balance }.to raise_error(Tronzap::ApiError) { |error| expect(error.retry_after).to eq(12.0) }
    end

    it "prefers the Retry-After header to the retry_after field" do
      server.respond_json({ "code" => 429, "error" => "Too many requests", "retry_after" => 12 },
                          status: 429, headers: { "Retry-After" => "3" })

      expect { client.get_balance }.to raise_error(Tronzap::ApiError) { |error| expect(error.retry_after).to eq(3.0) }
    end

    [-1, "12", 1.5, true].each do |value|
      it "ignores a retry_after field of #{value.inspect}" do
        server.respond_json({ "code" => 429, "error" => "Too many requests", "retry_after" => value }, status: 429)

        expect { client.get_balance }.to raise_error(Tronzap::ApiError) { |error| expect(error.retry_after).to be_nil }
      end
    end

    {
      90 => :BULK_NOT_FOUND, 91 => :BULK_EXPIRED, 92 => :BULK_PRICE_CHANGED, 93 => :BULK_TOO_MANY_ITEMS,
      94 => :BULK_NO_VALID_ITEMS, 95 => :BULK_RESOURCE_NOT_SUPPORTED, 96 => :PAYLOAD_TOO_LARGE, 429 => :RATE_LIMITED
    }.each do |code, name|
      it "names error code #{code} #{name}" do
        expect(Tronzap::ErrorCode.const_get(name)).to eq(code)
      end
    end

    it "treats a JSON object without a code as an unknown API error" do
      server.respond_json({ "result" => {} })

      expect { client.get_balance }.to raise_error(Tronzap::ApiError, "Unknown API error") { |error|
        expect(error.code).to eq(1)
        expect(error.error_key).to be_nil
      }
    end

    ["[]", '"text"', "null", "42"].each do |body|
      it "treats valid JSON that is not an object (#{body}) as an unknown API error" do
        server.respond(200, body)

        expect { client.get_balance }.to raise_error(Tronzap::ApiError, "Unknown API error") { |error|
          expect(error.response_body).to eq(body)
        }
      end
    end
  end

  describe "HTTP errors" do
    {
      401 => Tronzap::UnauthorizedError,
      403 => Tronzap::UnauthorizedError,
      429 => Tronzap::RateLimitError,
      500 => Tronzap::ServerError,
      502 => Tronzap::ServerError,
      503 => Tronzap::ServerError,
      404 => Tronzap::HttpError,
      418 => Tronzap::HttpError,
      301 => Tronzap::HttpError
    }.each do |status, error_class|
      it "raises #{error_class.name} for HTTP #{status} without an API payload" do
        server.respond(status, "<html>gateway</html>")

        expect { client.get_balance }.to raise_error(error_class) { |error|
          expect(error).to be_an_instance_of(error_class)
          expect(error.status).to eq(status)
          expect(error.response_body).to eq("<html>gateway</html>")
        }
      end
    end

    it "lets the HTTP status win over a successful code" do
      server.respond_json(ok({}), status: 500)

      expect { client.get_balance }.to raise_error(Tronzap::ServerError)
    end

    it "reads Retry-After in seconds" do
      server.respond(429, "", "Retry-After" => "7")

      expect { client.get_balance }.to raise_error(Tronzap::RateLimitError) { |error|
        expect(error.retry_after).to eq(7.0)
      }
    end

    it "reads Retry-After as an HTTP date" do
      server.respond(429, "", "Retry-After" => (Time.now + 120).httpdate)

      expect { client.get_balance }.to raise_error(Tronzap::RateLimitError) { |error|
        expect(error.retry_after).to be_within(5).of(120)
      }
    end

    it "reads Retry-After of a 503" do
      server.respond(503, "", "Retry-After" => "60")

      expect { client.get_balance }.to raise_error(Tronzap::ServerError) { |error|
        expect(error.retry_after).to eq(60.0)
      }
    end

    it "reads retry_after from a JSON body with a successful code" do
      server.respond_json({ "code" => 0, "retry_after" => 5 }, status: 429)

      expect { client.get_balance }.to raise_error(Tronzap::RateLimitError) { |error|
        expect(error.retry_after).to eq(5.0)
      }
    end

    it "ignores a Retry-After it cannot read" do
      server.respond(429, "", "Retry-After" => "soon")

      expect { client.get_balance }.to raise_error(Tronzap::RateLimitError) { |error|
        expect(error.retry_after).to be_nil
      }
    end
  end

  describe "unreadable responses" do
    it "raises InvalidResponseError for malformed JSON with a 2xx status" do
      server.respond(200, '{"code":0,"result":')

      expect { client.get_balance }.to raise_error(Tronzap::InvalidResponseError, /Invalid JSON/) { |error|
        expect(error.status).to eq(200)
        expect(error.response_body).to eq('{"code":0,"result":')
        expect(error.cause).to be_nil.or be_a(JSON::ParserError)
      }
    end

    it "raises InvalidResponseError for an empty 2xx body" do
      server.respond(200, "")

      expect { client.get_balance }.to raise_error(Tronzap::InvalidResponseError)
    end

    it "raises InvalidResponseError for a body that is not UTF-8" do
      server.respond(200, "\xFF\xFE{".b)

      expect { client.get_balance }.to raise_error(Tronzap::InvalidResponseError) { |error|
        expect(error.response_body).to be_valid_encoding
      }
    end

    it "raises InvalidResponseError when result is missing" do
      server.respond_json({ "code" => 0 })

      expect { client.get_balance }.to raise_error(Tronzap::InvalidResponseError, /Missing result/)
    end

    it "raises InvalidResponseError when result is null" do
      server.respond_json({ "code" => 0, "result" => nil })

      expect { client.get_balance }.to raise_error(Tronzap::InvalidResponseError, /Missing result/)
    end

    it "raises InvalidResponseError for a body larger than the limit" do
      server.respond(200, "a" * (Tronzap::HttpAdapter::MAX_RESPONSE_BYTES + 1))

      expect { client.get_balance }.to raise_error(Tronzap::InvalidResponseError, /exceeds/)
    end
  end

  it "reports every failure as a Tronzap::Error" do
    [Tronzap::ApiError, Tronzap::HttpError, Tronzap::RateLimitError, Tronzap::UnauthorizedError,
     Tronzap::ServerError, Tronzap::InvalidResponseError, Tronzap::NetworkError, Tronzap::ConnectionError,
     Tronzap::TimeoutError, Tronzap::SslError].each do |error_class|
      expect(error_class.ancestors).to include(Tronzap::Error)
    end
    expect(Tronzap::Error.superclass).to eq(StandardError)
  end
end
