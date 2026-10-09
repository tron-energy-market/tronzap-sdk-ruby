# Tron Energy Rental via API
## Ruby SDK by TronZap.com

**[English](README.md)** | [Español](README.es.md) | [Português](README.pt-br.md) | [Русский](README.ru.md)

[![Gem Version](https://img.shields.io/gem/v/tronzap-sdk.svg)](https://rubygems.org/gems/tronzap-sdk)
[![CI](https://github.com/tron-energy-market/tronzap-sdk-ruby/actions/workflows/ci.yml/badge.svg)](https://github.com/tron-energy-market/tronzap-sdk-ruby/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Official Ruby SDK for the TronZap API.
This SDK allows you to easily integrate with TronZap services for TRON energy rental.

TronZap.com allows you to [buy TRON energy](https://tronzap.com/), making USDT (TRC20) transfers cheaper by significantly reducing transaction fees.

👉 [Register for an API key](https://tronzap.com) to start using TronZap API and integrate it via the SDK.

- Website: https://tronzap.com/
- API reference: https://docs.tronzap.com/
- RubyGems: https://rubygems.org/gems/tronzap-sdk
- Source: https://github.com/tron-energy-market/tronzap-sdk-ruby

## Installation

Add the gem to your Gemfile:

```ruby
gem "tronzap-sdk"
```

or install it directly:

```bash
gem install tronzap-sdk
```

## Requirements

- Ruby 3.3 or newer
- One runtime dependency, `bigdecimal`. The SDK does not depend on Rails.

## Quick start

```ruby
require "tronzap"

client = Tronzap::Client.new(
  api_token: "your_api_token",
  api_secret: "your_api_secret"
)

begin
  balance = client.get_balance
  puts "balance: #{balance.balance.to_s("F")} (deposit to #{balance.address})"

  # Estimate how much energy a USDT transfer needs, then buy exactly that much.
  estimate = client.estimate_energy(from_address: "TSenderAddress", to_address: "TRecipientAddress")

  transaction = client.create_energy_transaction(
    address: "TRecipientAddress",
    energy: estimate.amount,
    duration: 1,
    external_id: "order-42",
    activate_address: true
  )
  puts "transaction #{transaction.id} costs #{transaction.amount.to_s("F")} and is #{transaction.status}"
rescue Tronzap::Error => e
  warn "TronZap call failed: #{e.message}"
end
```

`require "tronzap"` loads the SDK. With Bundler, `gem "tronzap-sdk"` in the Gemfile loads it as well.

A runnable walkthrough of every operation lives in
[`examples/basic_usage.rb`](examples/basic_usage.rb):

```bash
export TRONZAP_API_TOKEN=your_api_token
export TRONZAP_API_SECRET=your_api_secret
export TRONZAP_BASE_URL=api.tronzap.com   # optional
ruby -Ilib examples/basic_usage.rb
```

By default it only reads and spends nothing. Setting `TRONZAP_ALLOW_PURCHASES=1`
also exercises the endpoints that create transactions and AML checks, which debit
the account balance. See the comment at the top of the file for the other optional
variables.

## Configuration

The client takes the two credentials from your dashboard: the API token is sent as
a bearer token, and the API secret signs every request body and is never sent.
Everything else is optional. Pass the settings as keyword arguments, in a block,
or both; the block runs last:

```ruby
client = Tronzap::Client.new(
  api_token: api_token,
  api_secret: api_secret,
  base_url: "api.tronzap.com",   # defaults to Tronzap::Configuration::DEFAULT_BASE_URL
  timeout: 10,                   # seconds; defaults to 30
  user_agent: "my-app/1.0"
)

client = Tronzap::Client.new do |config|
  config.api_token = ENV.fetch("TRONZAP_API_TOKEN")
  config.api_secret = ENV.fetch("TRONZAP_API_SECRET")
  config.timeout = 10
end
```

`base_url` takes either a bare domain or a full URL: a missing scheme becomes
`https` and a trailing slash is trimmed, so `"api.tronzap.com"`,
`"api.tronzap.com/"` and `"https://api.tronzap.com"` are equivalent. Pass an
explicit scheme to opt out, for example `"http://localhost:8080"` against a local
mock.

`timeout` applies to opening the connection and to each read and write, not to
the request as a whole.

The SDK keeps no global state. Each client validates its settings when it is
created and freezes them, so a client is immutable and safe to share between
threads. Create one per set of credentials. `inspect` never shows the
credentials.

### Your own HTTP adapter

The default adapter uses `Net::HTTP` from the standard library, opens a new
connection for every request, always verifies TLS certificates, and honours the
`https_proxy` environment variable. To trust a private certificate authority, pass
its PEM file:

```ruby
adapter = Tronzap::HttpAdapter::NetHttp.new(ca_file: "/etc/ssl/corporate-ca.pem")
client = Tronzap::Client.new(api_token: api_token, api_secret: api_secret, adapter: adapter)
```

Any object with a `call` method can replace it. It receives a
`Tronzap::HttpAdapter::Request` (`http_method`, `url`, `headers`, `body`,
`timeout`) and returns a `Tronzap::HttpAdapter::Response` (`status`, `headers`,
`body`). Send the body unchanged: it is signed byte for byte.

```ruby
class FaradayAdapter
  def initialize(connection)
    @connection = connection
  end

  def call(request)
    response = @connection.post(request.url, request.body, request.headers) do |req|
      req.options.timeout = request.timeout
    end
    Tronzap::HttpAdapter::Response.new(status: response.status, headers: response.headers.to_h,
                                       body: response.body.to_s)
  rescue Faraday::TimeoutError => e
    raise Tronzap::TimeoutError, e.message
  rescue Faraday::SSLError => e
    raise Tronzap::SslError, e.message
  rescue Faraday::ConnectionFailed => e
    raise Tronzap::ConnectionError, e.message
  end
end
```

Standard Ruby network errors raised by an adapter (`Timeout::Error`,
`OpenSSL::SSL::SSLError`, `SocketError`, `SystemCallError`, `IOError`) are
reported as `Tronzap::NetworkError` subclasses automatically. Errors of other HTTP
libraries need to be translated by the adapter, as above.

## Available methods

| Method | Endpoint | Description |
|---|---|---|
| `get_services` | `/v1/services` | Available services and prices |
| `get_balance` | `/v1/balance` | Current account balance |
| `get_address_info(address)` | `/v1/address-info` | Address resources (energy, bandwidth) and balances (TRX, USDT) |
| `estimate_energy(from_address:, to_address:, contract_address: nil)` | `/v1/estimate-energy` | Energy a transfer needs, and its cost |
| `calculate(address:, energy:, duration: 1)` | `/v1/calculate` | Price a purchase without creating a transaction |
| `create_energy_transaction(address:, energy:, duration: 1, external_id: nil, activate_address: false)` | `/v1/transaction/new` | Buy energy |
| `create_bandwidth_transaction(address:, bandwidth:, external_id: nil)` | `/v1/transaction/new` | Buy bandwidth |
| `create_resource_bundle_transaction(address:, energy:, bandwidth:, duration: 1, external_id: nil, activate_address: false)` | `/v1/transaction/new` | Buy energy and bandwidth in one transaction |
| `create_address_activation_transaction(address:, external_id: nil)` | `/v1/transaction/new` | Activate a TRON address |
| `check_transaction(id: nil, external_id: nil)` | `/v1/transaction/check` | Status of a transaction, by id or external id |
| `get_direct_recharge_info` | `/v1/direct-recharge-info` | Direct recharge address and rates |
| `get_aml_services` | `/v1/aml-checks` | AML services and pricing |
| `create_aml_check(type:, network:, address:, transaction_hash: nil, direction: nil)` | `/v1/aml-checks/new` | Start an AML screening |
| `check_aml_status(id)` | `/v1/aml-checks/check` | Status and result of an AML check |
| `get_aml_history(page: 1, per_page: 10, status: nil)` | `/v1/aml-checks/history` | Paginated AML check history |
| `get_subscriptions` | `/v1/subscriptions` | Subscription plans and prices |
| `start_subscription(subscription_id:, address:, duration_days: 0, transactions_limit: 0, external_id: nil, activate_address: false)` | `/v1/subscription/start` | Subscribe an address to a plan |
| `check_subscription(id: nil, external_id: nil)` | `/v1/subscription/check` | Status of a subscription, by id or external id |
| `stop_subscription(id: nil, external_id: nil)` | `/v1/subscription/stop` | Stop a subscription |
| `get_subscription_history(page: 1, per_page: 10, status: nil)` | `/v1/subscriptions/history` | Paginated subscription history |

Methods with parameters take either keyword arguments or a request object from
`Tronzap::Requests`, so a request can be built, validated and passed around before
it is sent:

```ruby
request = Tronzap::Requests::EnergyTransaction.new(address: "TRecipientAddress", energy: 65000)
client.create_energy_transaction(request)
```

A request is validated when it is created, so an invalid one raises
`ArgumentError` and never reaches the API. Amounts must be positive `Integer`s.
Defaults match the API: `duration` is 1 hour, and AML and subscription history
start at page 1 with 10 items. The exception is `start_subscription`, where
`duration_days` and `transactions_limit` default to 0, which means no limit.

Results are immutable `Data` objects in `Tronzap::Responses` and
`Tronzap::Models`, not hashes: `transaction.status`, `estimate.amount`. Collections
are frozen and never `nil`, and values the API may omit are `nil`.

### Buying resources

```ruby
# Energy, optionally activating the address in the same call.
client.create_energy_transaction(
  address: "TRecipientAddress",
  energy: 65000,
  duration: 1,            # hours; see get_services for the durations on sale
  external_id: "order-42",
  activate_address: true
)

# Bandwidth.
client.create_bandwidth_transaction(address: "TRecipientAddress", bandwidth: 345, external_id: "bandwidth-1")

# Energy and bandwidth together in one transaction.
client.create_resource_bundle_transaction(
  address: "TRecipientAddress",
  energy: 65000,
  bandwidth: 345,
  external_id: "bundle-1"
)

# Activation on its own.
client.create_address_activation_transaction(address: "TRecipientAddress", external_id: "activation-1")
```

Energy and bandwidth prices in `get_services` are both per 1000 units, so a
purchase costs `price × amount / 1000`: 65000 energy at an `EnergyRate#price` of
0.03 costs 1.95, and 345 bandwidth at a `BandwidthRate#price` of 1 costs 0.345.

The API currently reports a resource bundle with `service` equal to `:energy`, not
`:resource_bundle`. Read `params.amounts` to see which resources a transaction
contains.

### Following a transaction

A transaction moves through `:new` → `:pending` → `:success` or `:failed`:

```ruby
transaction = nil
loop do
  sleep 2
  transaction = client.check_transaction(external_id: "order-42")
  break unless %i[new pending].include?(transaction.status)
end

puts "finished as #{transaction.status}, hash #{transaction.transaction_hash || "none"}"
```

### AML screening

```ruby
check = client.create_aml_check(Tronzap::Requests::AmlCheck.for_address("TRX", "TAddressToScreen"))
# or Tronzap::Requests::AmlCheck.for_hash("BTC", "bc1RecipientAddress", "TX_HASH", direction: :withdrawal)

result = client.check_aml_status(check.id)
if result.status == :completed
  puts "#{result.risk_level} #{result.risk_score.to_s("F")} #{result.risk_factors.size} factor(s)"
end
```

`risk_score` is `nil` until screening finishes. A completed check can have a score
of 0, which is not the same as having no score yet.

### Subscriptions

A subscription keeps an address supplied with energy for every transaction until
it is stopped or runs out of days or transactions. Pick a plan from
`get_subscriptions` and pass its `subscription_id`, such as `"unlimited_energy"`,
not its numeric `id`. Starting a subscription charges the plan's initial price.

```ruby
client.get_subscriptions.each do |plan|
  puts "#{plan.subscription_id} #{plan.initial_price.to_s("F")} #{plan.price.to_s("F")}"
end

subscription = client.start_subscription(
  subscription_id: "unlimited_energy",
  address: "TRecipientAddress",
  duration_days: 30,       # 0 for no time limit
  transactions_limit: 0,   # 0 for no limit
  external_id: "subscription-42"
)

subscription = client.check_subscription(external_id: "subscription-42")

subscription = client.stop_subscription(id: subscription.id)

history = client.get_subscription_history(status: :active)
```

Start, check and stop return the subscription with its `params`; the history
returns the usage counters `transactions_used`, `energy_used` and `total_price`
instead, and leaves `params` `nil`. A subscription moves through the statuses in
`Tronzap::Models::SUBSCRIPTION_STATUSES`. A subscription with a transactions limit
cannot be stopped (`CANNOT_STOP_SUBSCRIPTION`).

## Error handling

Every failure of an API call is a `Tronzap::Error`. Rescue a subclass to handle
one kind of failure:

```
Tronzap::Error
├── Tronzap::ApiError              — the API answered with a non-zero code
├── Tronzap::HttpError             — non-2xx response without an API payload
│   ├── Tronzap::RateLimitError    — HTTP 429
│   ├── Tronzap::UnauthorizedError — HTTP 401 or 403
│   └── Tronzap::ServerError       — HTTP 5xx
├── Tronzap::InvalidResponseError  — 2xx response the SDK could not read
└── Tronzap::NetworkError          — no response arrived
    ├── Tronzap::ConnectionError   — DNS failure, connection refused
    ├── Tronzap::TimeoutError      — the request exceeded its timeout
    └── Tronzap::SslError          — TLS handshake or certificate failure
```

`ApiError`, `HttpError` and `InvalidResponseError` carry the HTTP status
(`status`) and the raw response body (`response_body`). `ApiError` also carries
the API error code (`code`), the error key (`error_key`) and the request ID
(`request_id`). `RateLimitError#retry_after` holds the `Retry-After` delay in
seconds when the API sends one.

Invalid arguments are not API failures: they raise `ArgumentError` before anything
is sent.

```ruby
begin
  client.create_energy_transaction(address: "TRecipientAddress", energy: 65000)
rescue Tronzap::ApiError => e
  # Application-level failure: the code says exactly what went wrong.
  case e.code
  when Tronzap::ErrorCode::INVALID_TRON_ADDRESS
    # The key may narrow it down, e.g. "invalid_tron_address.from_address"
    warn "bad address: #{e.error_key}"
  when Tronzap::ErrorCode::INSUFFICIENT_FUNDS
    warn "top up the account"
  when Tronzap::ErrorCode::ADDRESS_NOT_ACTIVATED
    warn "activate the address first"
  else
    warn "api error #{e.code}: #{e.message} (request #{e.request_id || "-"})"
  end
rescue Tronzap::RateLimitError => e
  # Back off and retry, after e.retry_after seconds if the API sent it.
rescue Tronzap::UnauthorizedError
  # Bad token or signature.
rescue Tronzap::TimeoutError, Tronzap::ServerError
  # Transient; safe to retry.
rescue Tronzap::NetworkError
  # Unreachable.
end
```

`request_id` is the identifier the API assigns to each request. Quote it when
contacting support.

An API error takes precedence over the HTTP status: the API reports some failures
with a 2xx status and others with a 4xx or 5xx status, so a readable payload with
a non-zero code is always reported as `Tronzap::ApiError`, never as
`Tronzap::HttpError`.

### API error codes

| Code | Constant | Description |
|------|----------|-------------|
| 1 | `AUTH_ERROR` | Authentication error – invalid API token or signature |
| 2 | `INVALID_SERVICE_OR_PARAMS` | Invalid service or parameters |
| 5 | `WALLET_NOT_FOUND` | Internal wallet not found. Contact support. |
| 6 | `INSUFFICIENT_FUNDS` | Insufficient funds |
| 10 | `INVALID_TRON_ADDRESS` | Invalid TRON address, or the address already has an active subscription |
| 11 | `INVALID_ENERGY_AMOUNT` | Invalid energy amount |
| 12 | `INVALID_DURATION` | Invalid duration |
| 20 | `TRANSACTION_NOT_FOUND` | Transaction/subscription not found |
| 21 | `CANNOT_STOP_SUBSCRIPTION` | Cannot stop subscription, e.g. it has a transactions limit |
| 24 | `ADDRESS_NOT_ACTIVATED` | Address not activated |
| 25 | `ADDRESS_ALREADY_ACTIVATED` | Address already activated |
| 30 | `AML_CHECK_NOT_FOUND` | AML check not found |
| 35 | `SERVICE_NOT_AVAILABLE` | Service not available |
| 50 | `INVALID_BANDWIDTH_AMOUNT` | Invalid bandwidth amount |
| 500 | `INTERNAL_SERVER_ERROR` | Internal server error – contact support |

The constants live in `Tronzap::ErrorCode`. A code this SDK version does not know
is still available as a number from `ApiError#code`.

## Decimal and timestamp fields

Amounts and prices are `BigDecimal`, so they keep the exact value the API sent.
The API encodes money as a JSON number in some responses and as a JSON string in
others; both forms are read the same way. Use `to_s("F")` to print one without
exponent notation.

Timestamps are `Tronzap::Models::Timestamp` objects: `value` is the parsed `Time`
and `raw` is the text exactly as the API sent it. The several formats the API
emits are accepted, and times without an offset are read as UTC. An unrecognised
timestamp leaves `value` as `nil` instead of failing the whole response.

Enum-like fields are symbols, such as `:energy` or `:completed`. A value the API
may add in the future, such as a new transaction status, is reported as `:unknown`
instead of failing. The known values are listed in `Tronzap::Models`.

## Testing

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

The specs run against a local HTTP server: the exact request body and signature of
every endpoint, API and HTTP errors, malformed JSON, timeouts, network and TLS
failures, and concurrent use.

## License

The MIT License (MIT). Please see [License File](LICENSE) for more information.

## Support

For support, please contact [support@tronzap.com](mailto:support@tronzap.com).
