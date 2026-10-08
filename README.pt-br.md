# Aluguel de Energia Tron via API
## SDK Ruby por TronZap.com

[English](README.md) | [Español](README.es.md) | **[Português](README.pt-br.md)** | [Русский](README.ru.md)

[![Gem Version](https://img.shields.io/gem/v/tronzap-sdk.svg)](https://rubygems.org/gems/tronzap-sdk)
[![CI](https://github.com/tron-energy-market/tronzap-sdk-ruby/actions/workflows/ci.yml/badge.svg)](https://github.com/tron-energy-market/tronzap-sdk-ruby/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

SDK oficial em Ruby para a API do TronZap.
Este SDK permite integrar facilmente os serviços TronZap para aluguel de energia TRON.

TronZap.com permite [comprar energia TRON](https://tronzap.com/), reduzindo significativamente as taxas nas transferências de USDT (TRC20).

👉 [Registre-se para obter uma chave API](https://tronzap.com) para começar a usar a API TronZap e integrá-la através do SDK.

- Site: https://tronzap.com/
- Referência da API: https://docs.tronzap.com/
- RubyGems: https://rubygems.org/gems/tronzap-sdk
- Código-fonte: https://github.com/tron-energy-market/tronzap-sdk-ruby

## Instalação

Adicione a gem ao seu Gemfile:

```ruby
gem "tronzap-sdk"
```

ou instale-a diretamente:

```bash
gem install tronzap-sdk
```

## Requisitos

- Ruby 3.3 ou superior
- Uma única dependência em tempo de execução, `bigdecimal`. O SDK não depende do Rails.

## Início rápido

```ruby
require "tronzap"

client = Tronzap::Client.new(
  api_token: "seu_api_token",
  api_secret: "seu_api_secret"
)

begin
  balance = client.get_balance
  puts "balance: #{balance.balance.to_s("F")} (deposit to #{balance.address})"

  # Estima quanta energia uma transferência de USDT precisa e compra exatamente essa quantidade.
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

`require "tronzap"` carrega o SDK. Com o Bundler, `gem "tronzap-sdk"` no Gemfile também o carrega.

Um passo a passo executável de todas as operações está em
[`examples/basic_usage.rb`](examples/basic_usage.rb):

```bash
export TRONZAP_API_TOKEN=seu_api_token
export TRONZAP_API_SECRET=seu_api_secret
export TRONZAP_BASE_URL=api.tronzap.com   # opcional
ruby -Ilib examples/basic_usage.rb
```

Por padrão ele apenas lê e não gasta nada. Com `TRONZAP_ALLOW_PURCHASES=1` ele
também executa os endpoints que criam transações e verificações AML, que debitam o
saldo da conta. Veja o comentário no início do arquivo para as demais variáveis
opcionais.

## Configuração

O cliente recebe as duas credenciais do seu painel: o token da API é enviado como
bearer token, e o segredo da API assina o corpo de cada requisição e nunca é
enviado. Todo o resto é opcional. Passe as configurações como argumentos nomeados,
em um bloco ou de ambas as formas; o bloco é executado por último:

```ruby
client = Tronzap::Client.new(
  api_token: api_token,
  api_secret: api_secret,
  base_url: "api.tronzap.com",   # padrão: Tronzap::Configuration::DEFAULT_BASE_URL
  timeout: 10,                   # segundos; padrão: 30
  user_agent: "my-app/1.0"
)

client = Tronzap::Client.new do |config|
  config.api_token = ENV.fetch("TRONZAP_API_TOKEN")
  config.api_secret = ENV.fetch("TRONZAP_API_SECRET")
  config.timeout = 10
end
```

`base_url` aceita um domínio ou uma URL completa: sem esquema, usa-se `https`, e a
barra final é removida, então `"api.tronzap.com"`, `"api.tronzap.com/"` e
`"https://api.tronzap.com"` são equivalentes. Informe um esquema explícito para
evitar isso, por exemplo `"http://localhost:8080"` com um mock local.

`timeout` se aplica à abertura da conexão e a cada leitura e escrita, não à
requisição como um todo.

O SDK não mantém estado global. Cada cliente valida suas configurações ao ser
criado e as congela, então um cliente é imutável e seguro para compartilhar entre
threads. Crie um por conjunto de credenciais. `inspect` nunca exibe as
credenciais.

### Seu próprio adaptador HTTP

O adaptador padrão usa `Net::HTTP` da biblioteca padrão, abre uma nova conexão a
cada requisição, sempre verifica os certificados TLS e respeita a variável de
ambiente `https_proxy`. Para confiar em uma autoridade certificadora privada,
passe o arquivo PEM dela:

```ruby
adapter = Tronzap::HttpAdapter::NetHttp.new(ca_file: "/etc/ssl/corporate-ca.pem")
client = Tronzap::Client.new(api_token: api_token, api_secret: api_secret, adapter: adapter)
```

Qualquer objeto com um método `call` pode substituí-lo. Ele recebe um
`Tronzap::HttpAdapter::Request` (`http_method`, `url`, `headers`, `body`,
`timeout`) e retorna um `Tronzap::HttpAdapter::Response` (`status`, `headers`,
`body`). Envie o corpo sem alterações: ele é assinado byte a byte.

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

Os erros de rede padrão do Ruby lançados por um adaptador (`Timeout::Error`,
`OpenSSL::SSL::SSLError`, `SocketError`, `SystemCallError`, `IOError`) são
informados automaticamente como subclasses de `Tronzap::NetworkError`. Os erros de
outras bibliotecas HTTP precisam ser traduzidos pelo adaptador, como acima.

## Métodos disponíveis

| Método | Endpoint | Descrição |
|---|---|---|
| `get_services` | `/v1/services` | Serviços disponíveis e preços |
| `get_balance` | `/v1/balance` | Saldo atual da conta |
| `get_address_info(address)` | `/v1/address-info` | Recursos (energia, largura de banda) e saldos (TRX, USDT) de um endereço |
| `estimate_energy(from_address:, to_address:, contract_address: nil)` | `/v1/estimate-energy` | Energia necessária para uma transferência e seu custo |
| `calculate(address:, energy:, duration: 1)` | `/v1/calculate` | Preço de uma compra sem criar a transação |
| `create_energy_transaction(address:, energy:, duration: 1, external_id: nil, activate_address: false)` | `/v1/transaction/new` | Comprar energia |
| `create_bandwidth_transaction(address:, bandwidth:, external_id: nil)` | `/v1/transaction/new` | Comprar largura de banda |
| `create_resource_bundle_transaction(address:, energy:, bandwidth:, duration: 1, external_id: nil, activate_address: false)` | `/v1/transaction/new` | Comprar energia e largura de banda em uma única transação |
| `create_address_activation_transaction(address:, external_id: nil)` | `/v1/transaction/new` | Ativar um endereço TRON |
| `check_transaction(id: nil, external_id: nil)` | `/v1/transaction/check` | Status de uma transação, por id ou id externo |
| `get_direct_recharge_info` | `/v1/direct-recharge-info` | Endereço e tarifas de recarga direta |
| `get_aml_services` | `/v1/aml-checks` | Serviços AML e preços |
| `create_aml_check(type:, network:, address:, transaction_hash: nil, direction: nil)` | `/v1/aml-checks/new` | Iniciar uma verificação AML |
| `check_aml_status(id)` | `/v1/aml-checks/check` | Status e resultado de uma verificação AML |
| `get_aml_history(page: 1, per_page: 10, status: nil)` | `/v1/aml-checks/history` | Histórico paginado de verificações AML |

Os métodos com parâmetros aceitam argumentos nomeados ou um objeto de requisição de
`Tronzap::Requests`, então uma requisição pode ser montada, validada e repassada
antes de ser enviada:

```ruby
request = Tronzap::Requests::EnergyTransaction.new(address: "TRecipientAddress", energy: 65000)
client.create_energy_transaction(request)
```

Uma requisição é validada ao ser criada, então uma requisição inválida lança
`ArgumentError` e nunca chega à API. As quantidades devem ser valores `Integer`
positivos. Os padrões coincidem com a API: `duration` é 1 hora e o histórico AML
começa na página 1 com 10 itens.

Os resultados são objetos `Data` imutáveis em `Tronzap::Responses` e
`Tronzap::Models`, não hashes: `transaction.status`, `estimate.amount`. As coleções
são congeladas e nunca são `nil`, e os valores que a API pode omitir são `nil`.

### Comprar recursos

```ruby
# Energia, com ativação opcional do endereço na mesma chamada.
client.create_energy_transaction(
  address: "TRecipientAddress",
  energy: 65000,
  duration: 1,            # horas; veja get_services para as durações disponíveis
  external_id: "order-42",
  activate_address: true
)

# Largura de banda.
client.create_bandwidth_transaction(address: "TRecipientAddress", bandwidth: 345, external_id: "bandwidth-1")

# Energia e largura de banda juntas em uma única transação.
client.create_resource_bundle_transaction(
  address: "TRecipientAddress",
  energy: 65000,
  bandwidth: 345,
  external_id: "bundle-1"
)

# Apenas a ativação.
client.create_address_activation_transaction(address: "TRecipientAddress", external_id: "activation-1")
```

Em `get_services`, os preços da energia e da largura de banda são ambos por 1000
unidades, então uma compra custa `price × amount / 1000`: 65000 de energia com um
`EnergyRate#price` de 0.03 custam 1.95, e 345 de largura de banda com um
`BandwidthRate#price` de 1 custam 0.345.

Atualmente a API informa um pacote de recursos com `service` igual a `:energy`, e
não `:resource_bundle`. Consulte `params.amounts` para saber quais recursos uma
transação contém.

### Acompanhar uma transação

Uma transação passa por `:new` → `:pending` → `:success` ou `:failed`:

```ruby
transaction = nil
loop do
  sleep 2
  transaction = client.check_transaction(external_id: "order-42")
  break unless %i[new pending].include?(transaction.status)
end

puts "finished as #{transaction.status}, hash #{transaction.transaction_hash || "none"}"
```

### Verificação AML

```ruby
check = client.create_aml_check(Tronzap::Requests::AmlCheck.for_address("TRX", "TAddressToScreen"))
# ou Tronzap::Requests::AmlCheck.for_hash("BTC", "bc1RecipientAddress", "TX_HASH", direction: :withdrawal)

result = client.check_aml_status(check.id)
if result.status == :completed
  puts "#{result.risk_level} #{result.risk_score.to_s("F")} #{result.risk_factors.size} factor(s)"
end
```

`risk_score` é `nil` até a verificação terminar. Uma verificação concluída pode
ter pontuação 0, o que não é o mesmo que ainda não ter pontuação.

## Tratamento de erros

Toda falha de uma chamada à API é um `Tronzap::Error`. Capture uma subclasse para
tratar um tipo específico de falha:

```
Tronzap::Error
├── Tronzap::ApiError              — a API respondeu com um código diferente de zero
├── Tronzap::HttpError             — resposta não 2xx sem payload da API
│   ├── Tronzap::RateLimitError    — HTTP 429
│   ├── Tronzap::UnauthorizedError — HTTP 401 ou 403
│   └── Tronzap::ServerError       — HTTP 5xx
├── Tronzap::InvalidResponseError  — resposta 2xx que o SDK não conseguiu ler
└── Tronzap::NetworkError          — nenhuma resposta chegou
    ├── Tronzap::ConnectionError   — falha de DNS, conexão recusada
    ├── Tronzap::TimeoutError      — a requisição excedeu o timeout
    └── Tronzap::SslError          — falha no handshake TLS ou no certificado
```

`ApiError`, `HttpError` e `InvalidResponseError` trazem o status HTTP (`status`) e
o corpo bruto da resposta (`response_body`). `ApiError` também traz o código de
erro da API (`code`), a chave do erro (`error_key`) e o ID da requisição
(`request_id`). `RateLimitError#retry_after` contém o intervalo de `Retry-After`
em segundos quando a API o envia.

Argumentos inválidos não são falhas da API: eles lançam `ArgumentError` antes de
qualquer envio.

```ruby
begin
  client.create_energy_transaction(address: "TRecipientAddress", energy: 65000)
rescue Tronzap::ApiError => e
  # Falha no nível da aplicação: o código diz exatamente o que deu errado.
  case e.code
  when Tronzap::ErrorCode::INVALID_TRON_ADDRESS
    # A chave pode detalhar, p. ex. "invalid_tron_address.from_address"
    warn "bad address: #{e.error_key}"
  when Tronzap::ErrorCode::INSUFFICIENT_FUNDS
    warn "top up the account"
  when Tronzap::ErrorCode::ADDRESS_NOT_ACTIVATED
    warn "activate the address first"
  else
    warn "api error #{e.code}: #{e.message} (request #{e.request_id || "-"})"
  end
rescue Tronzap::RateLimitError => e
  # Aguarde e tente novamente, após e.retry_after segundos se a API o enviou.
rescue Tronzap::UnauthorizedError
  # Token ou assinatura incorretos.
rescue Tronzap::TimeoutError, Tronzap::ServerError
  # Transitório; pode tentar novamente.
rescue Tronzap::NetworkError
  # Inacessível.
end
```

`request_id` é o identificador que a API atribui a cada requisição. Informe-o ao
contatar o suporte.

Um erro da API tem prioridade sobre o status HTTP: a API informa algumas falhas
com status 2xx e outras com 4xx ou 5xx, então um payload legível com código
diferente de zero é sempre informado como `Tronzap::ApiError`, nunca como
`Tronzap::HttpError`.

### Códigos de erro da API

| Código | Constante | Descrição |
|------|----------|-------------|
| 1 | `AUTH_ERROR` | Erro de autenticação: token da API ou assinatura inválidos |
| 2 | `INVALID_SERVICE_OR_PARAMS` | Serviço ou parâmetros inválidos |
| 5 | `WALLET_NOT_FOUND` | Carteira interna não encontrada. Contate o suporte. |
| 6 | `INSUFFICIENT_FUNDS` | Saldo insuficiente |
| 10 | `INVALID_TRON_ADDRESS` | Endereço TRON inválido |
| 11 | `INVALID_ENERGY_AMOUNT` | Quantidade de energia inválida |
| 12 | `INVALID_DURATION` | Duração inválida |
| 20 | `TRANSACTION_NOT_FOUND` | Transação/assinatura não encontrada |
| 21 | `CANNOT_STOP_SUBSCRIPTION` | Não é possível interromper a assinatura |
| 24 | `ADDRESS_NOT_ACTIVATED` | Endereço não ativado |
| 25 | `ADDRESS_ALREADY_ACTIVATED` | Endereço já ativado |
| 30 | `AML_CHECK_NOT_FOUND` | Verificação AML não encontrada |
| 35 | `SERVICE_NOT_AVAILABLE` | Serviço indisponível |
| 50 | `INVALID_BANDWIDTH_AMOUNT` | Quantidade de largura de banda inválida |
| 500 | `INTERNAL_SERVER_ERROR` | Erro interno do servidor: contate o suporte |

As constantes estão em `Tronzap::ErrorCode`. Um código que esta versão do SDK não
conhece continua disponível como número em `ApiError#code`.

## Campos decimais e de data

Valores e preços são `BigDecimal`, então mantêm o valor exato enviado pela API. A
API codifica dinheiro como número JSON em algumas respostas e como string JSON em
outras; as duas formas são lidas da mesma maneira. Use `to_s("F")` para exibir um
valor sem notação exponencial.

Datas são objetos `Tronzap::Models::Timestamp`: `value` é o `Time` interpretado e
`raw` é o texto exatamente como a API enviou. Os vários formatos usados pela API
são aceitos, e horários sem fuso são lidos como UTC. Uma data não reconhecida
deixa `value` como `nil` em vez de fazer toda a resposta falhar.

Campos semelhantes a enums são símbolos, como `:energy` ou `:completed`. Um valor que a
API venha a adicionar no futuro, como um novo status de transação, é informado
como `:unknown` em vez de falhar. Os valores conhecidos estão listados em
`Tronzap::Models`.

## Testes

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

Os testes rodam contra um servidor HTTP local: o corpo exato da requisição e a
assinatura de cada endpoint, erros da API e HTTP, JSON malformado, timeouts, falhas
de rede e de TLS, e uso concorrente.

## Licença

Licença MIT (MIT). Veja o [arquivo de licença](LICENSE) para mais informações.

## Suporte

Para suporte, entre em contato com [support@tronzap.com](mailto:support@tronzap.com).
