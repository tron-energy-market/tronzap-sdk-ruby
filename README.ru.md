# Покупка энергии Tron через API
## Ruby SDK от TronZap.com

[English](README.md) | [Español](README.es.md) | [Português](README.pt-br.md) | **[Русский](README.ru.md)**

[![Gem Version](https://img.shields.io/gem/v/tronzap-sdk.svg)](https://rubygems.org/gems/tronzap-sdk)
[![CI](https://github.com/tron-energy-market/tronzap-sdk-ruby/actions/workflows/ci.yml/badge.svg)](https://github.com/tron-energy-market/tronzap-sdk-ruby/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Официальный Ruby SDK для API TronZap.
Этот SDK позволяет легко интегрировать сервисы TronZap для аренды энергии TRON.

TronZap.com позволяет [покупать энергию TRON](https://tronzap.com/), существенно снижая комиссии при переводах USDT (TRC20).

👉 [Зарегистрируйтесь для получения API ключа](https://tronzap.com), чтобы начать использовать TronZap API и интегрировать его через SDK.

- Сайт: https://tronzap.com/
- Справочник API: https://docs.tronzap.com/
- RubyGems: https://rubygems.org/gems/tronzap-sdk
- Исходный код: https://github.com/tron-energy-market/tronzap-sdk-ruby

## Установка

Добавьте gem в Gemfile:

```ruby
gem "tronzap-sdk"
```

или установите его напрямую:

```bash
gem install tronzap-sdk
```

## Требования

- Ruby 3.3 или новее
- Одна runtime-зависимость, `bigdecimal`. SDK не зависит от Rails.

## Быстрый старт

```ruby
require "tronzap"

client = Tronzap::Client.new(
  api_token: "ваш_api_token",
  api_secret: "ваш_api_secret"
)

begin
  balance = client.get_balance
  puts "balance: #{balance.balance.to_s("F")} (deposit to #{balance.address})"

  # Оцениваем, сколько энергии нужно для перевода USDT, и покупаем ровно столько.
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

`require "tronzap"` загружает SDK. С Bundler его также загружает строка `gem "tronzap-sdk"` в Gemfile.

Запускаемый пример со всеми операциями находится в
[`examples/basic_usage.rb`](examples/basic_usage.rb):

```bash
export TRONZAP_API_TOKEN=ваш_api_token
export TRONZAP_API_SECRET=ваш_api_secret
export TRONZAP_BASE_URL=api.tronzap.com   # необязательно
ruby -Ilib examples/basic_usage.rb
```

По умолчанию пример только читает данные и ничего не тратит. С
`TRONZAP_ALLOW_PURCHASES=1` он также вызывает endpoints, которые создают транзакции
и AML-проверки и списывают средства с баланса. Остальные необязательные переменные
описаны в комментарии в начале файла.

## Настройка

Клиент принимает два ключа из личного кабинета: API-токен передаётся как bearer
token, а API-секрет подписывает тело каждого запроса и никогда не передаётся.
Всё остальное необязательно. Настройки можно передать именованными аргументами,
в блоке или обоими способами; блок выполняется последним:

```ruby
client = Tronzap::Client.new(
  api_token: api_token,
  api_secret: api_secret,
  base_url: "api.tronzap.com",   # по умолчанию Tronzap::Configuration::DEFAULT_BASE_URL
  timeout: 10,                   # секунды; по умолчанию 30
  user_agent: "my-app/1.0"
)

client = Tronzap::Client.new do |config|
  config.api_token = ENV.fetch("TRONZAP_API_TOKEN")
  config.api_secret = ENV.fetch("TRONZAP_API_SECRET")
  config.timeout = 10
end
```

`base_url` принимает домен или полный URL: если схема не указана, используется
`https`, а завершающий слэш удаляется, поэтому `"api.tronzap.com"`,
`"api.tronzap.com/"` и `"https://api.tronzap.com"` равнозначны. Чтобы этого
избежать, укажите схему явно, например `"http://localhost:8080"` для локального
мока.

`timeout` действует на установку соединения и на каждое чтение и запись, а не на
запрос целиком.

SDK не хранит глобального состояния. Каждый клиент проверяет свои настройки при
создании и замораживает их, поэтому клиент неизменяем и безопасен для
использования из нескольких потоков. Создайте один клиент на набор ключей.
`inspect` никогда не показывает ключи.

### Свой HTTP-адаптер

Адаптер по умолчанию использует `Net::HTTP` из стандартной библиотеки, открывает
новое соединение для каждого запроса, всегда проверяет TLS-сертификаты и учитывает
переменную окружения `https_proxy`. Чтобы доверять частному центру сертификации,
передайте его PEM-файл:

```ruby
adapter = Tronzap::HttpAdapter::NetHttp.new(ca_file: "/etc/ssl/corporate-ca.pem")
client = Tronzap::Client.new(api_token: api_token, api_secret: api_secret, adapter: adapter)
```

Его можно заменить любым объектом с методом `call`. Он получает
`Tronzap::HttpAdapter::Request` (`http_method`, `url`, `headers`, `body`,
`timeout`) и возвращает `Tronzap::HttpAdapter::Response` (`status`, `headers`,
`body`). Отправляйте тело без изменений: оно подписывается побайтно.

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

Стандартные сетевые ошибки Ruby, которые выбрасывает адаптер (`Timeout::Error`,
`OpenSSL::SSL::SSLError`, `SocketError`, `SystemCallError`, `IOError`),
автоматически сообщаются как подклассы `Tronzap::NetworkError`. Ошибки других
HTTP-библиотек адаптер должен преобразовать сам, как в примере выше.

## Доступные методы

| Метод | Endpoint | Описание |
|---|---|---|
| `get_services` | `/v1/services` | Доступные сервисы и цены |
| `get_balance` | `/v1/balance` | Текущий баланс аккаунта |
| `get_address_info(address)` | `/v1/address-info` | Ресурсы (энергия, bandwidth) и балансы (TRX, USDT) адреса |
| `estimate_energy(from_address:, to_address:, contract_address: nil)` | `/v1/estimate-energy` | Сколько энергии нужно для перевода и сколько она стоит |
| `calculate(address:, energy:, duration: 1)` | `/v1/calculate` | Стоимость покупки без создания транзакции |
| `create_energy_transaction(address:, energy:, duration: 1, external_id: nil, activate_address: false)` | `/v1/transaction/new` | Купить энергию |
| `create_bandwidth_transaction(address:, bandwidth:, external_id: nil)` | `/v1/transaction/new` | Купить bandwidth |
| `create_resource_bundle_transaction(address:, energy:, bandwidth:, duration: 1, external_id: nil, activate_address: false)` | `/v1/transaction/new` | Купить энергию и bandwidth одной транзакцией |
| `create_address_activation_transaction(address:, external_id: nil)` | `/v1/transaction/new` | Активировать адрес TRON |
| `check_transaction(id: nil, external_id: nil)` | `/v1/transaction/check` | Статус транзакции по id или внешнему id |
| `get_direct_recharge_info` | `/v1/direct-recharge-info` | Адрес и тарифы прямого пополнения |
| `get_aml_services` | `/v1/aml-checks` | AML-сервисы и цены |
| `create_aml_check(type:, network:, address:, transaction_hash: nil, direction: nil)` | `/v1/aml-checks/new` | Запустить AML-проверку |
| `check_aml_status(id)` | `/v1/aml-checks/check` | Статус и результат AML-проверки |
| `get_aml_history(page: 1, per_page: 10, status: nil)` | `/v1/aml-checks/history` | История AML-проверок с пагинацией |
| `get_subscriptions` | `/v1/subscriptions` | Планы подписок и цены |
| `start_subscription(subscription_id:, address:, duration_days: 0, transactions_limit: 0, external_id: nil, activate_address: false)` | `/v1/subscription/start` | Подписать адрес на план |
| `check_subscription(id: nil, external_id: nil)` | `/v1/subscription/check` | Статус подписки по id или внешнему id |
| `stop_subscription(id: nil, external_id: nil)` | `/v1/subscription/stop` | Остановить подписку |
| `get_subscription_history(page: 1, per_page: 10, status: nil)` | `/v1/subscriptions/history` | История подписок с пагинацией |

Методы с параметрами принимают либо именованные аргументы, либо объект запроса из
`Tronzap::Requests`, поэтому запрос можно создать, проверить и передать дальше до
отправки:

```ruby
request = Tronzap::Requests::EnergyTransaction.new(address: "TRecipientAddress", energy: 65000)
client.create_energy_transaction(request)
```

Запрос проверяется при создании, поэтому невалидный запрос вызывает
`ArgumentError` и никогда не доходит до API. Количества должны быть
положительными `Integer`. Значения по умолчанию совпадают с API: `duration` —
1 час, история AML и подписок начинается со страницы 1 по 10 элементов.
Исключение — `start_subscription`: `duration_days` и `transactions_limit` по
умолчанию равны 0, что означает отсутствие ограничения.

Результаты — неизменяемые объекты `Data` в `Tronzap::Responses` и
`Tronzap::Models`, а не хеши: `transaction.status`, `estimate.amount`. Коллекции
заморожены и никогда не бывают `nil`, а значения, которые API может не прислать,
равны `nil`.

### Покупка ресурсов

```ruby
# Энергия, при необходимости с активацией адреса в том же вызове.
client.create_energy_transaction(
  address: "TRecipientAddress",
  energy: 65000,
  duration: 1,            # часы; доступные сроки смотрите в get_services
  external_id: "order-42",
  activate_address: true
)

# Bandwidth.
client.create_bandwidth_transaction(address: "TRecipientAddress", bandwidth: 345, external_id: "bandwidth-1")

# Энергия и bandwidth вместе одной транзакцией.
client.create_resource_bundle_transaction(
  address: "TRecipientAddress",
  energy: 65000,
  bandwidth: 345,
  external_id: "bundle-1"
)

# Только активация.
client.create_address_activation_transaction(address: "TRecipientAddress", external_id: "activation-1")
```

В `get_services` цены энергии и bandwidth указаны за 1000 единиц, поэтому покупка
стоит `price × amount / 1000`: 65000 энергии при `EnergyRate#price`, равном 0.03,
стоят 1.95, а 345 bandwidth при `BandwidthRate#price`, равном 1, стоят 0.345.

Сейчас API возвращает пакет ресурсов с `service`, равным `:energy`, а не
`:resource_bundle`. Состав покупки смотрите в `params.amounts`.

### Отслеживание транзакции

Транзакция проходит путь `:new` → `:pending` → `:success` или `:failed`:

```ruby
transaction = nil
loop do
  sleep 2
  transaction = client.check_transaction(external_id: "order-42")
  break unless %i[new pending].include?(transaction.status)
end

puts "finished as #{transaction.status}, hash #{transaction.transaction_hash || "none"}"
```

### AML-проверка

```ruby
check = client.create_aml_check(Tronzap::Requests::AmlCheck.for_address("TRX", "TAddressToScreen"))
# или Tronzap::Requests::AmlCheck.for_hash("BTC", "bc1RecipientAddress", "TX_HASH", direction: :withdrawal)

result = client.check_aml_status(check.id)
if result.status == :completed
  puts "#{result.risk_level} #{result.risk_score.to_s("F")} #{result.risk_factors.size} factor(s)"
end
```

`risk_score` равен `nil`, пока проверка не завершится. У завершённой проверки score
может быть равен 0, и это не то же самое, что отсутствие результата.

### Подписки

Подписка обеспечивает адрес энергией для каждой транзакции, пока её не
остановят или не закончатся её дни или транзакции. Выберите план из
`get_subscriptions` и передайте его `subscription_id`, например
`"unlimited_energy"`, а не числовой `id`. Запуск подписки списывает начальную
цену плана.

```ruby
client.get_subscriptions.each do |plan|
  puts "#{plan.subscription_id} #{plan.initial_price.to_s("F")} #{plan.price.to_s("F")}"
end

subscription = client.start_subscription(
  subscription_id: "unlimited_energy",
  address: "TRecipientAddress",
  duration_days: 30,       # 0 — без ограничения по времени
  transactions_limit: 0,   # 0 — без ограничения
  external_id: "subscription-42"
)

subscription = client.check_subscription(external_id: "subscription-42")

subscription = client.stop_subscription(id: subscription.id)

history = client.get_subscription_history(status: :active)
```

Запуск, проверка и остановка возвращают подписку с её `params`, а история
вместо них — счётчики использования `transactions_used`, `energy_used` и
`total_price`, и `params` в ней равен `nil`. Статусы подписки перечислены в
`Tronzap::Models::SUBSCRIPTION_STATUSES`. Подписку с лимитом транзакций
остановить нельзя (`CANNOT_STOP_SUBSCRIPTION`).

## Обработка ошибок

Любой сбой вызова API — исключение `Tronzap::Error`. Перехватывайте подкласс, чтобы
обработать конкретный вид сбоя:

```
Tronzap::Error
├── Tronzap::ApiError              — API ответил ненулевым code
├── Tronzap::HttpError             — ответ не 2xx без payload API
│   ├── Tronzap::RateLimitError    — HTTP 429
│   ├── Tronzap::UnauthorizedError — HTTP 401 или 403
│   └── Tronzap::ServerError       — HTTP 5xx
├── Tronzap::InvalidResponseError  — ответ 2xx, который SDK не смог прочитать
└── Tronzap::NetworkError          — ответ не пришёл
    ├── Tronzap::ConnectionError   — ошибка DNS, соединение отклонено
    ├── Tronzap::TimeoutError      — запрос превысил timeout
    └── Tronzap::SslError          — сбой TLS-рукопожатия или сертификата
```

`ApiError`, `HttpError` и `InvalidResponseError` содержат HTTP-статус
(`status`) и сырое тело ответа (`response_body`). `ApiError` также содержит код
ошибки API (`code`), ключ ошибки (`error_key`) и ID запроса (`request_id`).
`RateLimitError#retry_after` хранит задержку из `Retry-After` в секундах, если API
её прислал.

Невалидные аргументы не являются сбоями API: они вызывают `ArgumentError` ещё до
отправки.

```ruby
begin
  client.create_energy_transaction(address: "TRecipientAddress", energy: 65000)
rescue Tronzap::ApiError => e
  # Ошибка уровня приложения: код точно говорит, что пошло не так.
  case e.code
  when Tronzap::ErrorCode::INVALID_TRON_ADDRESS
    # Ключ может уточнить, например "invalid_tron_address.from_address"
    warn "bad address: #{e.error_key}"
  when Tronzap::ErrorCode::INSUFFICIENT_FUNDS
    warn "top up the account"
  when Tronzap::ErrorCode::ADDRESS_NOT_ACTIVATED
    warn "activate the address first"
  else
    warn "api error #{e.code}: #{e.message} (request #{e.request_id || "-"})"
  end
rescue Tronzap::RateLimitError => e
  # Подождите и повторите, через e.retry_after секунд, если API его прислал.
rescue Tronzap::UnauthorizedError
  # Неверный токен или подпись.
rescue Tronzap::TimeoutError, Tronzap::ServerError
  # Временный сбой; можно повторить.
rescue Tronzap::NetworkError
  # Сервер недоступен.
end
```

`request_id` — идентификатор, который API присваивает каждому запросу. Указывайте
его при обращении в поддержку.

Ошибка API важнее HTTP-статуса: часть сбоев API возвращает со статусом 2xx, а
часть — с 4xx или 5xx, поэтому читаемый payload с ненулевым кодом всегда
сообщается как `Tronzap::ApiError`, а не как `Tronzap::HttpError`.

### Коды ошибок API

| Код | Константа | Описание |
|------|----------|-------------|
| 1 | `AUTH_ERROR` | Ошибка аутентификации: неверный API-токен или подпись |
| 2 | `INVALID_SERVICE_OR_PARAMS` | Неверный сервис или параметры |
| 5 | `WALLET_NOT_FOUND` | Внутренний кошелёк не найден. Обратитесь в поддержку. |
| 6 | `INSUFFICIENT_FUNDS` | Недостаточно средств |
| 10 | `INVALID_TRON_ADDRESS` | Неверный адрес TRON, или у адреса уже есть активная подписка |
| 11 | `INVALID_ENERGY_AMOUNT` | Неверное количество энергии |
| 12 | `INVALID_DURATION` | Неверная длительность |
| 20 | `TRANSACTION_NOT_FOUND` | Транзакция/подписка не найдена |
| 21 | `CANNOT_STOP_SUBSCRIPTION` | Невозможно остановить подписку, например, у неё есть лимит транзакций |
| 24 | `ADDRESS_NOT_ACTIVATED` | Адрес не активирован |
| 25 | `ADDRESS_ALREADY_ACTIVATED` | Адрес уже активирован |
| 30 | `AML_CHECK_NOT_FOUND` | AML-проверка не найдена |
| 35 | `SERVICE_NOT_AVAILABLE` | Сервис недоступен |
| 50 | `INVALID_BANDWIDTH_AMOUNT` | Неверное количество bandwidth |
| 500 | `INTERNAL_SERVER_ERROR` | Внутренняя ошибка сервера: обратитесь в поддержку |

Константы находятся в `Tronzap::ErrorCode`. Код, который эта версия SDK не знает,
по-прежнему доступен как число через `ApiError#code`.

## Числовые поля и даты

Суммы и цены — `BigDecimal`, поэтому сохраняют ровно то значение, которое прислал
API. В одних ответах API кодирует деньги JSON-числом, в других — JSON-строкой; обе
формы читаются одинаково. Чтобы вывести значение без экспоненциальной записи,
используйте `to_s("F")`.

Даты — объекты `Tronzap::Models::Timestamp`: `value` — разобранный `Time`, `raw` —
текст ровно в том виде, в каком его прислал API. Поддерживаются все форматы,
которые использует API, а время без смещения читается как UTC. Нераспознанная дата
оставляет `value` равным `nil` и не ломает весь ответ.

Поля-перечисления — символы, например `:energy` или `:completed`. Значение,
которое API может добавить в будущем, например новый статус транзакции,
сообщается как `:unknown` и не приводит к ошибке. Известные значения перечислены
в `Tronzap::Models`.

## Тестирование

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

Тесты запускаются против локального HTTP-сервера: точное тело запроса и
подпись для каждого endpoint, ошибки API и HTTP, некорректный JSON, таймауты,
сетевые и TLS-сбои, а также конкурентное использование.

## Лицензия

Лицензия MIT (MIT). Подробнее в [файле лицензии](LICENSE).

## Поддержка

По вопросам поддержки пишите на [support@tronzap.com](mailto:support@tronzap.com).
