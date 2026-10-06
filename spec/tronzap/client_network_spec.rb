# frozen_string_literal: true

RSpec.describe Tronzap::Client, "network failures" do
  def client_at(url, **options)
    Tronzap::Client.new(api_token: "t", api_secret: "s", base_url: url, timeout: 2, **options)
  end

  context "with a server" do
    include_context "with server"

    it "raises TimeoutError when the server does not answer in time" do
      server.handle { :hang }
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      expect { build_client(server, timeout: 0.3).get_balance }.to raise_error(Tronzap::TimeoutError) { |error|
        expect(error.cause).to be_a(Timeout::Error)
      }
      expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 1.5
    end

    it "raises NetworkError, not a timeout or connection error, when the connection drops mid-request" do
      server.handle { :close }

      expect { client.get_balance }.to raise_error(Tronzap::NetworkError) { |error|
        expect(error).to be_an_instance_of(Tronzap::NetworkError)
      }
    end
  end

  it "raises ConnectionError when the connection is refused" do
    closed = TCPServer.new("127.0.0.1", 0)
    port = closed.addr[1]
    closed.close

    expect { client_at("http://127.0.0.1:#{port}").get_balance }.to raise_error(Tronzap::ConnectionError)
  end

  it "raises ConnectionError when the host name does not resolve" do
    expect { client_at("https://tronzap-sdk-test.invalid").get_balance }.to raise_error(Tronzap::ConnectionError)
  end

  context "with TLS" do
    let(:server) { TestServer.new(tls: true) }

    after { server.stop }

    it "raises SslError for a certificate that is not trusted" do
      expect { client_at(server.url).get_balance }.to raise_error(Tronzap::SslError, /certificate/) { |error|
        expect(error.cause).to be_a(OpenSSL::SSL::SSLError)
      }
      expect(server.requests).to be_empty
    end

    it "succeeds when the certificate is trusted through ca_file" do
      server.respond_json(ok("balance" => "1", "address" => "TDeposit"))
      adapter = Tronzap::HttpAdapter::NetHttp.new(ca_file: TestServer.ca_file.path)

      expect(client_at(server.url, adapter: adapter).get_balance.address).to eq("TDeposit")
    end
  end
end
