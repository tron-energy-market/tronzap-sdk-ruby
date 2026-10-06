# frozen_string_literal: true

RSpec.describe Tronzap::Configuration do
  def client(**options, &)
    Tronzap::Client.new(api_token: "token", api_secret: "secret", **options, &)
  end

  it "uses the production endpoint and a 30 second timeout by default" do
    config = client.config

    expect(config.base_url).to eq("https://api.tronzap.com")
    expect(config.timeout).to eq(30)
    expect(config.adapter).to be_a(Tronzap::HttpAdapter::NetHttp)
  end

  it "takes the settings from a block" do
    configured = Tronzap::Client.new do |config|
      config.api_token = "token"
      config.api_secret = "secret"
      config.base_url = "dev.example.com"
      config.timeout = 5
    end

    expect(configured.config).to have_attributes(base_url: "https://dev.example.com", timeout: 5)
  end

  it "lets the block override constructor arguments" do
    configured = client(timeout: 10) { |config| config.timeout = 3 }

    expect(configured.config.timeout).to eq(3)
  end

  {
    "api.tronzap.com" => "https://api.tronzap.com",
    "api.tronzap.com/" => "https://api.tronzap.com",
    " https://api.tronzap.com// " => "https://api.tronzap.com",
    "http://localhost:8080" => "http://localhost:8080",
    "https://gateway.example.com/tronzap/" => "https://gateway.example.com/tronzap"
  }.each do |given, expected|
    it "normalizes the base URL #{given.inspect} to #{expected}" do
      expect(client(base_url: given).config.base_url).to eq(expected)
    end
  end

  ["", "   ", "ftp://api.tronzap.com", "https://", "https://api.tronzap.com?x=1", "https://api.tronzap.com#top",
   "https://exa mple.com", nil].each do |given|
    it "rejects the base URL #{given.inspect}" do
      expect { client(base_url: given) }.to raise_error(ArgumentError, /base_url/)
    end
  end

  [nil, "", "  ", 42].each do |given|
    it "requires the API token (rejects #{given.inspect})" do
      expect { Tronzap::Client.new(api_token: given, api_secret: "secret") }.to raise_error(ArgumentError, /api_token/)
    end

    it "requires the API secret (rejects #{given.inspect})" do
      expect { Tronzap::Client.new(api_token: "token", api_secret: given) }.to raise_error(ArgumentError, /api_secret/)
    end
  end

  [0, -1, "5", nil, Float::INFINITY, Float::NAN, Complex(1, 1)].each do |given|
    it "rejects the timeout #{given.inspect}" do
      expect { client(timeout: given) }.to raise_error(ArgumentError, /timeout/)
    end
  end

  it "accepts a fractional timeout" do
    expect(client(timeout: 0.5).config.timeout).to eq(0.5)
  end

  ["", "agent\r\nX-Injected: 1", nil].each do |given|
    it "rejects the user agent #{given.inspect}" do
      expect { client(user_agent: given) }.to raise_error(ArgumentError, /user_agent/)
    end
  end

  it "rejects an adapter without #call" do
    expect { client(adapter: Object.new) }.to raise_error(ArgumentError, /adapter/)
  end

  it "is frozen once the client exists" do
    kept = nil
    created = client { |config| kept = config }

    expect(created).to be_frozen
    expect(created.config).to be(kept)
    expect { kept.timeout = 1 }.to raise_error(FrozenError)
  end

  it "does not share settings between clients" do
    first = client(timeout: 1)
    second = client(timeout: 2)

    expect([first.config.timeout, second.config.timeout]).to eq([1, 2])
  end

  it "copies the credentials so later changes to the strings do not leak in" do
    token = +"token"
    created = Tronzap::Client.new(api_token: token, api_secret: "secret")
    token << "-changed"

    expect(created.config.api_token).to eq("token")
  end

  it "keeps the credentials out of inspect" do
    created = Tronzap::Client.new(api_token: "visible-token", api_secret: "visible-secret")

    expect(created.inspect).not_to include("visible-token", "visible-secret")
    expect(created.config.inspect).not_to include("visible-token", "visible-secret")
  end
end
