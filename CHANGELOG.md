# Changelog

All notable changes to this project are documented in this file. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[1.0.0]: https://github.com/tron-energy-market/tronzap-sdk-ruby/releases/tag/v1.0.0
