# frozen_string_literal: true

RSpec.describe Tronzap::HttpAdapter do
  let(:recording_adapter) do
    Class.new do
      attr_reader :requests

      def initialize(response)
        @response = response
        @requests = []
      end

      def call(request)
        @requests << request
        @response
      end
    end
  end

  def client_with(adapter)
    Tronzap::Client.new(api_token: "token", api_secret: "secret", base_url: "api.example.com", timeout: 7,
                        user_agent: "my-app/2.0", adapter: adapter)
  end

  def raising(error)
    ->(_request) { raise error }
  end

  it "hands a custom adapter the signed request" do
    adapter = recording_adapter.new(
      Tronzap::HttpAdapter::Response.new(status: 200, headers: {}, body: '{"code":0,"result":{"balance":"2"}}')
    )
    balance = client_with(adapter).get_balance
    request = adapter.requests.first

    expect(balance.balance).to eq(2)
    expect(request).to have_attributes(http_method: :post, url: "https://api.example.com/v1/balance", body: "{}",
                                       timeout: 7)
    expect(request.headers).to include("Authorization" => "Bearer token", "User-Agent" => "my-app/2.0",
                                       "X-Signature" => Digest::SHA256.hexdigest("{}secret"))
  end

  it "accepts any response object with status, headers and body" do
    response = Struct.new(:status, :headers, :body).new("429", { "RETRY-AFTER" => ["3"] }, "")

    expect { client_with(recording_adapter.new(response)).get_balance }
      .to raise_error(Tronzap::RateLimitError) { |error| expect(error.retry_after).to eq(3.0) }
  end

  {
    Errno::ECONNREFUSED.new => Tronzap::ConnectionError,
    SocketError.new("getaddrinfo: nodename nor servname provided") => Tronzap::ConnectionError,
    Net::OpenTimeout.new => Tronzap::TimeoutError,
    Timeout::Error.new => Tronzap::TimeoutError,
    Errno::ETIMEDOUT.new => Tronzap::TimeoutError,
    OpenSSL::SSL::SSLError.new("certificate verify failed") => Tronzap::SslError,
    Errno::ECONNRESET.new => Tronzap::NetworkError,
    EOFError.new => Tronzap::NetworkError
  }.each do |raised, expected|
    it "reports #{raised.class} from an adapter as #{expected.name}" do
      expect { client_with(raising(raised)).get_balance }.to raise_error(expected) { |error|
        expect(error).to be_an_instance_of(expected)
        expect(error.cause).to be(raised)
      }
    end
  end

  it "passes through a Tronzap error raised by an adapter" do
    error = Tronzap::TimeoutError.new("deadline")

    expect { client_with(raising(error)).get_balance }.to raise_error(error)
  end

  it "does not hide unrelated errors raised by an adapter" do
    expect { client_with(raising(NoMethodError.new("bug"))).get_balance }.to raise_error(NoMethodError, "bug")
  end
end
