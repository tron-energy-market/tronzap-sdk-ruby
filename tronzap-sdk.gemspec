# frozen_string_literal: true

require_relative "lib/tronzap/version"

Gem::Specification.new do |spec|
  spec.name = "tronzap-sdk"
  spec.version = Tronzap::VERSION
  spec.authors = ["TronZap"]
  spec.email = ["support@tronzap.com"]

  spec.summary = "Official Ruby SDK for the TronZap API: buy TRON energy and bandwidth."
  spec.description = "Official Ruby SDK for TronZap.com. The TRON Energy API lets you buy energy and bandwidth " \
                     "to lower USDT (TRC20) transfer fees, activate TRON addresses and run AML checks."
  spec.homepage = "https://tronzap.com/"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3"

  repository = "https://github.com/tron-energy-market/tronzap-sdk-ruby"
  spec.metadata = {
    "homepage_uri" => "https://tronzap.com/",
    "documentation_uri" => "https://docs.tronzap.com/",
    "source_code_uri" => repository,
    "changelog_uri" => "#{repository}/blob/main/CHANGELOG.md",
    "bug_tracker_uri" => "#{repository}/issues",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir["lib/**/*.rb", "README*.md", "CHANGELOG.md", "LICENSE"]
  spec.require_paths = ["lib"]

  spec.add_dependency "bigdecimal", ">= 3.1"
end
