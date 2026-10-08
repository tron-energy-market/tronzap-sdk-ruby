# Alquiler de Energía Tron vía API
## SDK Ruby por TronZap.com

[English](README.md) | **[Español](README.es.md)** | [Português](README.pt-br.md) | [Русский](README.ru.md)

[![Gem Version](https://img.shields.io/gem/v/tronzap-sdk.svg)](https://rubygems.org/gems/tronzap-sdk)
[![CI](https://github.com/tron-energy-market/tronzap-sdk-ruby/actions/workflows/ci.yml/badge.svg)](https://github.com/tron-energy-market/tronzap-sdk-ruby/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

SDK oficial en Ruby para la API de TronZap.
Este SDK permite integrar fácilmente los servicios de TronZap para alquilar energía TRON.

TronZap.com permite [comprar energía TRON](https://tronzap.com/), reduciendo significativamente las comisiones en transferencias de USDT (TRC20).

👉 [Regístrate para obtener una clave API](https://tronzap.com) para comenzar a usar la API de TronZap e integrarla a través del SDK.

- Sitio web: https://tronzap.com/
- Referencia de la API: https://docs.tronzap.com/
- RubyGems: https://rubygems.org/gems/tronzap-sdk
- Código fuente: https://github.com/tron-energy-market/tronzap-sdk-ruby

## Instalación

Añade la gema a tu Gemfile:

```ruby
gem "tronzap-sdk"
```

o instálala directamente:

```bash
gem install tronzap-sdk
```

## Requisitos

- Ruby 3.3 o superior
- Una sola dependencia en tiempo de ejecución, `bigdecimal`. El SDK no depende de Rails.

## Inicio rápido

```ruby
require "tronzap"

client = Tronzap::Client.new(
  api_token: "su_api_token",
  api_secret: "su_api_secret"
)

begin
  balance = client.get_balance
  puts "balance: #{balance.balance.to_s("F")} (deposit to #{balance.address})"

  # Estima cuánta energía necesita una transferencia de USDT y compra exactamente esa cantidad.
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

`require "tronzap"` carga el SDK. Con Bundler, `gem "tronzap-sdk"` en el Gemfile también lo carga.

Un recorrido ejecutable por todas las operaciones está en
[`examples/basic_usage.rb`](examples/basic_usage.rb):

```bash
export TRONZAP_API_TOKEN=su_api_token
export TRONZAP_API_SECRET=su_api_secret
export TRONZAP_BASE_URL=api.tronzap.com   # opcional
ruby -Ilib examples/basic_usage.rb
```

Por defecto solo lee y no gasta nada. Con `TRONZAP_ALLOW_PURCHASES=1` también
ejecuta los endpoints que crean transacciones y verificaciones AML, que debitan el
saldo de la cuenta. Consulta el comentario al inicio del archivo para ver las
demás variables opcionales.

## Configuración

El cliente recibe las dos credenciales de tu panel: el token de API se envía como
bearer token y el secreto de API firma el cuerpo de cada solicitud y nunca se envía.
Todo lo demás es opcional. Pasa la configuración como argumentos de palabra clave,
en un bloque o de ambas formas; el bloque se ejecuta al final:

```ruby
client = Tronzap::Client.new(
  api_token: api_token,
  api_secret: api_secret,
  base_url: "api.tronzap.com",   # por defecto Tronzap::Configuration::DEFAULT_BASE_URL
  timeout: 10,                   # segundos; por defecto 30
  user_agent: "my-app/1.0"
)

client = Tronzap::Client.new do |config|
  config.api_token = ENV.fetch("TRONZAP_API_TOKEN")
  config.api_secret = ENV.fetch("TRONZAP_API_SECRET")
  config.timeout = 10
end
```

`base_url` acepta un dominio o una URL completa: si falta el esquema se usa
`https` y se elimina la barra final, así que `"api.tronzap.com"`,
`"api.tronzap.com/"` y `"https://api.tronzap.com"` son equivalentes. Indica un
esquema explícito para evitarlo, por ejemplo `"http://localhost:8080"` con un mock
local.

`timeout` se aplica a la apertura de la conexión y a cada lectura y escritura, no
a la solicitud en su conjunto.

El SDK no mantiene estado global. Cada cliente valida su configuración al crearse
y la congela, así que un cliente es inmutable y seguro para compartir entre hilos.
Crea uno por cada juego de credenciales. `inspect` nunca muestra las
credenciales.

### Tu propio adaptador HTTP

El adaptador por defecto usa `Net::HTTP` de la biblioteca estándar, abre una nueva
conexión para cada solicitud, siempre verifica los certificados TLS y respeta la
variable de entorno `https_proxy`. Para confiar en una autoridad de certificación
privada, pasa su archivo PEM:

```ruby
adapter = Tronzap::HttpAdapter::NetHttp.new(ca_file: "/etc/ssl/corporate-ca.pem")
client = Tronzap::Client.new(api_token: api_token, api_secret: api_secret, adapter: adapter)
```

Cualquier objeto con un método `call` puede sustituirlo. Recibe un
`Tronzap::HttpAdapter::Request` (`http_method`, `url`, `headers`, `body`,
`timeout`) y devuelve un `Tronzap::HttpAdapter::Response` (`status`, `headers`,
`body`). Envía el cuerpo sin modificarlo: se firma byte a byte.

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

Los errores de red estándar de Ruby que lance un adaptador (`Timeout::Error`,
`OpenSSL::SSL::SSLError`, `SocketError`, `SystemCallError`, `IOError`) se informan
automáticamente como subclases de `Tronzap::NetworkError`. Los errores de otras
bibliotecas HTTP debe traducirlos el adaptador, como en el ejemplo anterior.

## Métodos disponibles

| Método | Endpoint | Descripción |
|---|---|---|
| `get_services` | `/v1/services` | Servicios disponibles y precios |
| `get_balance` | `/v1/balance` | Saldo actual de la cuenta |
| `get_address_info(address)` | `/v1/address-info` | Recursos (energía, ancho de banda) y saldos (TRX, USDT) de una dirección |
| `estimate_energy(from_address:, to_address:, contract_address: nil)` | `/v1/estimate-energy` | Energía que necesita una transferencia y su coste |
| `calculate(address:, energy:, duration: 1)` | `/v1/calculate` | Precio de una compra sin crear la transacción |
| `create_energy_transaction(address:, energy:, duration: 1, external_id: nil, activate_address: false)` | `/v1/transaction/new` | Comprar energía |
| `create_bandwidth_transaction(address:, bandwidth:, external_id: nil)` | `/v1/transaction/new` | Comprar ancho de banda |
| `create_resource_bundle_transaction(address:, energy:, bandwidth:, duration: 1, external_id: nil, activate_address: false)` | `/v1/transaction/new` | Comprar energía y ancho de banda en una sola transacción |
| `create_address_activation_transaction(address:, external_id: nil)` | `/v1/transaction/new` | Activar una dirección TRON |
| `check_transaction(id: nil, external_id: nil)` | `/v1/transaction/check` | Estado de una transacción, por id o id externo |
| `get_direct_recharge_info` | `/v1/direct-recharge-info` | Dirección y tarifas de recarga directa |
| `get_aml_services` | `/v1/aml-checks` | Servicios AML y precios |
| `create_aml_check(type:, network:, address:, transaction_hash: nil, direction: nil)` | `/v1/aml-checks/new` | Iniciar una verificación AML |
| `check_aml_status(id)` | `/v1/aml-checks/check` | Estado y resultado de una verificación AML |
| `get_aml_history(page: 1, per_page: 10, status: nil)` | `/v1/aml-checks/history` | Historial paginado de verificaciones AML |

Los métodos con parámetros aceptan argumentos de palabra clave o un objeto de
solicitud de `Tronzap::Requests`, así que una solicitud se puede construir, validar
y pasar de un sitio a otro antes de enviarla:

```ruby
request = Tronzap::Requests::EnergyTransaction.new(address: "TRecipientAddress", energy: 65000)
client.create_energy_transaction(request)
```

Una solicitud se valida al crearse, así que una solicitud inválida lanza
`ArgumentError` y nunca llega a la API. Las cantidades deben ser `Integer`
positivos. Los valores por defecto coinciden con la API: `duration` es 1 hora y el
historial AML empieza en la página 1 con 10 elementos.

Los resultados son objetos `Data` inmutables en `Tronzap::Responses` y
`Tronzap::Models`, no hashes: `transaction.status`, `estimate.amount`. Las
colecciones están congeladas y nunca son `nil`, y los valores que la API puede
omitir son `nil`.

### Comprar recursos

```ruby
# Energía, con activación opcional de la dirección en la misma llamada.
client.create_energy_transaction(
  address: "TRecipientAddress",
  energy: 65000,
  duration: 1,            # horas; consulta get_services para las duraciones disponibles
  external_id: "order-42",
  activate_address: true
)

# Ancho de banda.
client.create_bandwidth_transaction(address: "TRecipientAddress", bandwidth: 345, external_id: "bandwidth-1")

# Energía y ancho de banda juntos en una sola transacción.
client.create_resource_bundle_transaction(
  address: "TRecipientAddress",
  energy: 65000,
  bandwidth: 345,
  external_id: "bundle-1"
)

# Solo la activación.
client.create_address_activation_transaction(address: "TRecipientAddress", external_id: "activation-1")
```

En `get_services`, los precios de la energía y del ancho de banda son ambos por
1000 unidades, así que una compra cuesta `price × amount / 1000`: 65000 de energía
con un `EnergyRate#price` de 0.03 cuestan 1.95, y 345 de ancho de banda con un
`BandwidthRate#price` de 1 cuestan 0.345.

Actualmente la API informa un paquete de recursos con `service` igual a `:energy`,
no `:resource_bundle`. Consulta `params.amounts` para saber qué recursos contiene
una transacción.

### Seguir una transacción

Una transacción pasa por `:new` → `:pending` → `:success` o `:failed`:

```ruby
transaction = nil
loop do
  sleep 2
  transaction = client.check_transaction(external_id: "order-42")
  break unless %i[new pending].include?(transaction.status)
end

puts "finished as #{transaction.status}, hash #{transaction.transaction_hash || "none"}"
```

### Verificación AML

```ruby
check = client.create_aml_check(Tronzap::Requests::AmlCheck.for_address("TRX", "TAddressToScreen"))
# o Tronzap::Requests::AmlCheck.for_hash("BTC", "bc1RecipientAddress", "TX_HASH", direction: :withdrawal)

result = client.check_aml_status(check.id)
if result.status == :completed
  puts "#{result.risk_level} #{result.risk_score.to_s("F")} #{result.risk_factors.size} factor(s)"
end
```

`risk_score` es `nil` hasta que termina la verificación. Una verificación
completada puede tener una puntuación de 0, que no es lo mismo que no tener
puntuación todavía.

## Gestión de errores

Todo fallo de una llamada a la API es un `Tronzap::Error`. Captura una subclase
para tratar un tipo concreto de fallo:

```
Tronzap::Error
├── Tronzap::ApiError              — la API respondió con un código distinto de cero
├── Tronzap::HttpError             — respuesta no 2xx sin payload de la API
│   ├── Tronzap::RateLimitError    — HTTP 429
│   ├── Tronzap::UnauthorizedError — HTTP 401 o 403
│   └── Tronzap::ServerError       — HTTP 5xx
├── Tronzap::InvalidResponseError  — respuesta 2xx que el SDK no pudo leer
└── Tronzap::NetworkError          — no llegó ninguna respuesta
    ├── Tronzap::ConnectionError   — fallo de DNS, conexión rechazada
    ├── Tronzap::TimeoutError      — la solicitud superó su timeout
    └── Tronzap::SslError          — fallo del handshake TLS o del certificado
```

`ApiError`, `HttpError` e `InvalidResponseError` incluyen el estado HTTP
(`status`) y el cuerpo de la respuesta sin procesar (`response_body`). `ApiError`
incluye además el código de error de la API (`code`), la clave del error
(`error_key`) y el ID de la solicitud (`request_id`). `RateLimitError#retry_after`
contiene el retraso de `Retry-After` en segundos cuando la API lo envía.

Los argumentos inválidos no son fallos de la API: lanzan `ArgumentError` antes de
enviar nada.

```ruby
begin
  client.create_energy_transaction(address: "TRecipientAddress", energy: 65000)
rescue Tronzap::ApiError => e
  # Fallo a nivel de aplicación: el código indica exactamente qué salió mal.
  case e.code
  when Tronzap::ErrorCode::INVALID_TRON_ADDRESS
    # La clave puede precisarlo, p. ej. "invalid_tron_address.from_address"
    warn "bad address: #{e.error_key}"
  when Tronzap::ErrorCode::INSUFFICIENT_FUNDS
    warn "top up the account"
  when Tronzap::ErrorCode::ADDRESS_NOT_ACTIVATED
    warn "activate the address first"
  else
    warn "api error #{e.code}: #{e.message} (request #{e.request_id || "-"})"
  end
rescue Tronzap::RateLimitError => e
  # Espera y reintenta, tras e.retry_after segundos si la API lo envió.
rescue Tronzap::UnauthorizedError
  # Token o firma incorrectos.
rescue Tronzap::TimeoutError, Tronzap::ServerError
  # Transitorio; se puede reintentar.
rescue Tronzap::NetworkError
  # Inalcanzable.
end
```

`request_id` es el identificador que la API asigna a cada solicitud. Indícalo al
contactar con soporte.

Un error de la API tiene prioridad sobre el estado HTTP: la API informa de
algunos fallos con estado 2xx y de otros con 4xx o 5xx, así que un payload legible
con un código distinto de cero siempre se informa como `Tronzap::ApiError`, nunca
como `Tronzap::HttpError`.

### Códigos de error de la API

| Código | Constante | Descripción |
|------|----------|-------------|
| 1 | `AUTH_ERROR` | Error de autenticación: token de API o firma inválidos |
| 2 | `INVALID_SERVICE_OR_PARAMS` | Servicio o parámetros inválidos |
| 5 | `WALLET_NOT_FOUND` | Billetera interna no encontrada. Contacta con soporte. |
| 6 | `INSUFFICIENT_FUNDS` | Fondos insuficientes |
| 10 | `INVALID_TRON_ADDRESS` | Dirección TRON inválida |
| 11 | `INVALID_ENERGY_AMOUNT` | Cantidad de energía inválida |
| 12 | `INVALID_DURATION` | Duración inválida |
| 20 | `TRANSACTION_NOT_FOUND` | Transacción/suscripción no encontrada |
| 21 | `CANNOT_STOP_SUBSCRIPTION` | No se puede detener la suscripción |
| 24 | `ADDRESS_NOT_ACTIVATED` | Dirección no activada |
| 25 | `ADDRESS_ALREADY_ACTIVATED` | Dirección ya activada |
| 30 | `AML_CHECK_NOT_FOUND` | Verificación AML no encontrada |
| 35 | `SERVICE_NOT_AVAILABLE` | Servicio no disponible |
| 50 | `INVALID_BANDWIDTH_AMOUNT` | Cantidad de ancho de banda inválida |
| 500 | `INTERNAL_SERVER_ERROR` | Error interno del servidor: contacta con soporte |

Las constantes están en `Tronzap::ErrorCode`. Un código que esta versión del SDK
no conoce sigue disponible como número en `ApiError#code`.

## Campos decimales y de fecha

Los importes y precios son `BigDecimal`, así que conservan el valor exacto que
envió la API. La API codifica el dinero como número JSON en algunas respuestas y
como cadena JSON en otras; ambas formas se leen igual. Usa `to_s("F")` para
imprimir uno sin notación exponencial.

Las fechas son objetos `Tronzap::Models::Timestamp`: `value` es el `Time`
interpretado y `raw` es el texto tal como lo envió la API. Se aceptan los distintos
formatos que usa la API, y las horas sin desplazamiento se leen como UTC. Una fecha
no reconocida deja `value` como `nil` en lugar de hacer fallar toda la respuesta.

Los campos similares a enumeraciones son símbolos, como `:energy` o `:completed`. Un valor
que la API pueda añadir en el futuro, como un nuevo estado de transacción, se
informa como `:unknown` en lugar de fallar. Los valores conocidos se enumeran en
`Tronzap::Models`.

## Pruebas

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

Las pruebas se ejecutan contra un servidor HTTP local: el cuerpo exacto de la
solicitud y la firma de cada endpoint, errores de la API y HTTP, JSON malformado,
timeouts, fallos de red y de TLS, y uso concurrente.

## Licencia

Licencia MIT (MIT). Consulta el [archivo de licencia](LICENSE) para más información.

## Soporte

Para soporte, contacta con [support@tronzap.com](mailto:support@tronzap.com).
