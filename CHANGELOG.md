# Changelog

All notable changes to this project are documented in this file. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
