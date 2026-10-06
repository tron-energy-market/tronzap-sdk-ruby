# frozen_string_literal: true

# Walks through the TronZap API operations. By default it only reads and spends nothing.
#
#   export TRONZAP_API_TOKEN=your_api_token
#   export TRONZAP_API_SECRET=your_api_secret
#   export TRONZAP_BASE_URL=api.tronzap.com      # optional, e.g. a dev host
#   export TRONZAP_ADDRESS=TRON_ADDRESS          # optional
#   export TRONZAP_FROM_ADDRESS=TRON_ADDRESS     # optional, with TO_ADDRESS
#   export TRONZAP_TO_ADDRESS=TRON_ADDRESS       # optional, with FROM_ADDRESS
#   export TRONZAP_TRANSACTION_ID=id             # optional
#   export TRONZAP_AML_CHECK_ID=id               # optional
#   ruby -Ilib examples/basic_usage.rb
#
# Setting TRONZAP_ALLOW_PURCHASES=1 additionally exercises the endpoints that create transactions and AML checks.
# Those DEBIT THE ACCOUNT BALANCE. It is meant for verifying an integration against a development environment, and
# it also needs TRONZAP_ADDRESS.

require "tronzap"

ENERGY = 65_000
BANDWIDTH = 345

def env(name)
  value = ENV.fetch(name, nil)
  value unless value.nil? || value.strip.empty?
end

def money(value)
  value.to_s("F")
end

def describe_time(timestamp)
  return "unknown" if timestamp.nil?

  timestamp.value ? timestamp.value.iso8601 : "UNPARSED(#{timestamp.raw})"
end

def print_transaction(transaction)
  puts "  #{transaction.id} #{transaction.service} #{transaction.status}, charged #{money(transaction.amount)}, " \
       "created #{describe_time(transaction.created_at)}"
end

token = env("TRONZAP_API_TOKEN")
secret = env("TRONZAP_API_SECRET")
abort "set TRONZAP_API_TOKEN and TRONZAP_API_SECRET" unless token && secret

client = Tronzap::Client.new(api_token: token, api_secret: secret, timeout: 20) do |config|
  config.user_agent = "tronzap-example/1.0"
  config.base_url = env("TRONZAP_BASE_URL") if env("TRONZAP_BASE_URL")
end
puts "Calling #{client.config.base_url}"

failed = []

step = lambda do |name, &call|
  puts "\n#{name}"
  call.call
rescue Tronzap::Error => e
  puts "  FAILED: #{e.class}: #{e.message}"
  failed << name
end

optional_step = lambda do |name, subject, &call|
  next puts("\n#{name}\n  skipped: its environment variable is not set") if subject.nil?

  step.call(name) { call.call(subject) }
end

step.call("get_balance") do
  balance = client.get_balance
  puts "  balance #{money(balance.balance)}, deposit address #{balance.address}"
end

step.call("get_services") do
  services = client.get_services
  services.energy.each do |rate|
    puts "  energy #{rate.duration}h #{rate.min_energy}..#{rate.max_energy} at #{money(rate.price)} per unit " \
         "(65k = #{money(rate.price_65k)})"
  end
  services.bandwidth.each do |rate|
    puts "  bandwidth #{rate.duration}h #{rate.min_amount}..#{rate.max_amount} at #{money(rate.price)} per 1000 units"
  end
  puts "  activation #{money(services.activate_address.price)}" if services.activate_address
end

step.call("get_direct_recharge_info") do
  info = client.get_direct_recharge_info
  puts "  pay to #{info.address}, #{info.rates.size} rate(s)"
end

step.call("get_aml_services") do
  client.get_aml_services.each { |service| puts "  #{service.id} #{service.type} at #{money(service.price)}" }
end

step.call("get_aml_history") do
  history = client.get_aml_history
  puts "  page #{history.page}, #{history.items.size} of #{history.total} check(s)"
end

address = env("TRONZAP_ADDRESS")
optional_step.call("get_address_info", address) do |value|
  info = client.get_address_info(value)
  balances = info.balances.map { |symbol, amount| "#{symbol} #{money(amount)}" }.join(", ")
  puts "  energy #{info.resources.energy}, bandwidth #{info.resources.bandwidth}, balances #{balances}"
end

optional_step.call("calculate", address) do |value|
  calculation = client.calculate(address: value, energy: ENERGY)
  puts "  #{calculation.energy} energy for #{calculation.duration}h costs #{money(calculation.total)}"
end

from = env("TRONZAP_FROM_ADDRESS")
to = env("TRONZAP_TO_ADDRESS")
optional_step.call("estimate_energy", to && from) do |value|
  estimate = client.estimate_energy(from_address: value, to_address: to)
  puts "  #{estimate.energy} energy, total #{money(estimate.total)}"
end

optional_step.call("check_transaction", env("TRONZAP_TRANSACTION_ID")) do |value|
  print_transaction(client.check_transaction(id: value))
end

optional_step.call("check_aml_status", env("TRONZAP_AML_CHECK_ID")) do |value|
  check = client.check_aml_status(value)
  puts "  #{check.status}, risk #{check.risk_score ? money(check.risk_score) : "not scored yet"}"
end

if env("TRONZAP_ALLOW_PURCHASES") != "1"
  puts "\nSkipping purchases: set TRONZAP_ALLOW_PURCHASES=1 to create transactions (debits the balance)"
elsif address.nil?
  puts "\nSkipping purchases: TRONZAP_ADDRESS is not set"
else
  run_id = "ruby-example-#{(Time.now.to_f * 1000).to_i}"

  step.call("create_address_activation_transaction") do
    print_transaction(client.create_address_activation_transaction(address: address,
                                                                   external_id: "#{run_id}-activate"))
  rescue Tronzap::ApiError => e
    raise unless e.code == Tronzap::ErrorCode::ADDRESS_ALREADY_ACTIVATED

    puts "  already activated"
  end

  step.call("create_energy_transaction") do
    print_transaction(client.create_energy_transaction(address: address, energy: ENERGY,
                                                       external_id: "#{run_id}-energy"))
    print_transaction(client.check_transaction(external_id: "#{run_id}-energy"))
  end

  step.call("create_bandwidth_transaction") do
    print_transaction(client.create_bandwidth_transaction(address: address, bandwidth: BANDWIDTH,
                                                          external_id: "#{run_id}-bandwidth"))
  end

  step.call("create_resource_bundle_transaction") do
    print_transaction(client.create_resource_bundle_transaction(address: address, energy: ENERGY,
                                                                bandwidth: BANDWIDTH, external_id: "#{run_id}-bundle"))
  end

  step.call("create_aml_check") do
    check = client.create_aml_check(Tronzap::Requests::AmlCheck.for_address("TRX", address))
    puts "  AML check #{check.id} is #{check.status}"
  end
end

if failed.empty?
  puts "\nAll calls succeeded"
else
  warn "\nFailed: #{failed.join(", ")}"
  exit 1
end
