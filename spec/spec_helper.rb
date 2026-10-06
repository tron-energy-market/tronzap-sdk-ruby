# frozen_string_literal: true

require "tronzap"

Dir[File.join(__dir__, "support", "**", "*.rb")].each { |file| require file }

module SpecHelpers
  API_TOKEN = "test-token"
  API_SECRET = "test-secret"
  ADDRESS = "TRecipientAddress"

  def build_client(server, **)
    Tronzap::Client.new(api_token: API_TOKEN, api_secret: API_SECRET, base_url: server.url, timeout: 2, **)
  end

  def ok(result)
    { "code" => 0, "result" => result }
  end

  def signature(body)
    Digest::SHA256.hexdigest(body + API_SECRET)
  end
end

RSpec.shared_context "with server" do
  let(:server) { TestServer.new }
  let(:client) { build_client(server) }

  after { server.stop }
end

RSpec.configure do |config|
  config.include SpecHelpers
  config.disable_monkey_patching!
  config.expect_with(:rspec) { |expectations| expectations.syntax = :expect }
  config.mock_with(:rspec) { |mocks| mocks.verify_partial_doubles = true }
  config.order = :random
  Kernel.srand config.seed
end
