# Changelog

All notable changes to this project are documented in this file. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Energy subscriptions: `Client#get_subscriptions`, `#start_subscription`, `#check_subscription`,
  `#stop_subscription` and `#get_subscription_history`, with the requests `Requests::StartSubscription`,
  `Requests::SubscriptionLookup` and `Requests::SubscriptionHistory`, the results `Responses::SubscriptionPlan`,
  `Responses::Subscription` and `Responses::SubscriptionHistory`, `Models::SubscriptionParams` and
  `Models::SUBSCRIPTION_STATUSES`. `get_subscriptions` returns the plans in the API's order, each with its key as
  `subscription_id`.
- The example program lists subscription plans and history, checks `TRONZAP_SUBSCRIPTION_ID`, and with purchases
  allowed and `TRONZAP_SUBSCRIPTION_PLAN` set starts a one-day subscription and always stops it.

### Changed

- A hash AML check without a `direction` now sends `deposit` explicitly instead of leaving the direction to the API.
  An address check still sends a direction only when one is given.
- The documentation of AML checks: for a hash check, `address` is the recipient address of the transaction, and
  `direction` says which side you are on (`:deposit` if the funds were sent to your address, `:withdrawal` if you
  sent them); the risk is scored for the counterparty.
- The documentation of error codes 10 and 21: `INVALID_TRON_ADDRESS` is also reported when the address already has
  an active subscription, and `CANNOT_STOP_SUBSCRIPTION` covers, for example, a subscription with a transactions
  limit.

### Deprecated

- `Models::EnergyRate#min_energy` and `#max_energy`: use `#min_amount` and `#max_amount`. They now hold the same
  values, read from the API's `min_amount` and `max_amount`.
- `Responses::Calculation#energy`: use `#amount`. It now holds the same value, read from the API's `amount`.
- `Responses::EnergyEstimate#energy`: use `#amount`. It now holds the same value, read from the API's `amount`.

### Fixed

- The documentation of `get_services` prices: energy, like bandwidth, is priced per 1000 units, so a purchase costs
  `price × amount / 1000`. It was described as priced per unit.
- `Models::DirectRechargeRate#price` is the price of 1000 units of energy as well, not of one unit.

## [1.0.0] - 2026-10-06

First release of the official Ruby SDK for the [TronZap API](https://docs.tronzap.com/).

### Added

- `Tronzap::Client` with every TronZap API operation: services and prices, account balance, address info, energy
  estimates and price calculation, energy, bandwidth, resource bundle and address activation purchases,
  transaction status, direct recharge info, and AML services, checks and history.
- Configuration through keyword arguments or a block; every client owns a frozen configuration.
- Immutable request and response value objects built on `Data`, with money as `BigDecimal` and timestamps that keep
  the raw text next to the parsed `Time`.
- A pluggable HTTP adapter; the default uses `Net::HTTP` and always verifies TLS certificates.
- An error hierarchy under `Tronzap::Error` that separates API, HTTP, response and network failures, with the HTTP
  status, API error code, error key, request ID and raw response body.

[Unreleased]: https://github.com/tron-energy-market/tronzap-sdk-ruby/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/tron-energy-market/tronzap-sdk-ruby/releases/tag/v1.0.0
