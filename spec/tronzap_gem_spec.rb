# frozen_string_literal: true

require "open3"
require "rbconfig"

RSpec.describe Tronzap, "packaging" do
  let(:root) { File.expand_path("..", __dir__) }
  let(:spec) { Gem::Specification.load(File.join(root, "tronzap-sdk.gemspec")) }

  it "links to TronZap, the API documentation and the source code" do
    expect(spec.homepage).to eq("https://tronzap.com/")
    expect(spec.metadata).to include(
      "homepage_uri" => "https://tronzap.com/",
      "documentation_uri" => "https://docs.tronzap.com/",
      "source_code_uri" => "https://github.com/tron-energy-market/tronzap-sdk-ruby",
      "changelog_uri" => "https://github.com/tron-energy-market/tronzap-sdk-ruby/blob/main/CHANGELOG.md",
      "rubygems_mfa_required" => "true"
    )
  end

  it "declares the license, the Ruby version and its only runtime dependency" do
    expect(spec.license).to eq("MIT")
    expect(spec.required_ruby_version).to eq(Gem::Requirement.new(">= 3.3"))
    expect(spec.runtime_dependencies.map(&:name)).to eq(["bigdecimal"])
  end

  it "packages the library and its documents, not the tests" do
    expect(spec.files).to include("lib/tronzap.rb", "lib/tronzap-sdk.rb", "README.md", "CHANGELOG.md", "LICENSE")
    expect(spec.files.grep(%r{\Aspec/})).to be_empty
  end

  it "matches the version at the top of the changelog" do
    top = File.read(File.join(root, "CHANGELOG.md"))[/^## \[(\d+\.\d+\.\d+)\]/, 1]

    expect(top).to eq(Tronzap::VERSION)
  end

  it "loads under the gem name, as Bundler.require does" do
    output, status = Open3.capture2e(RbConfig.ruby, "-I", File.join(root, "lib"), "-e",
                                     'require "tronzap-sdk"; print Tronzap::Client.name')

    expect(status).to be_success, output
    expect(output).to eq("Tronzap::Client")
  end
end
