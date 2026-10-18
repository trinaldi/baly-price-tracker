# Price Tracker

A small Rails app that checks the price of products on supermarket websites twice a day, keeps the price history in SQLite, and sends an email when a price changes or a check fails.

It started as a hands-on project to get back into Ruby on Rails: small services with a single responsibility, a spec for every piece, and a systemd timer instead of a hosted scheduler. There is no web UI and no external service besides SMTP.

## Features

- Tracks any number of products, listed in a YAML file
- One class per market (site), each with its own host, cookie and price extraction
- Prices stored as integer cents, never as floats
- Price history per product: one record per check, including failures
- Email when a price changes and when a check fails
- On demand email report with the current price of every product
- Failure isolation: one broken product does not stop the others

## How it works

```
systemd timer (09:00 and 21:00)
  -> bin/rails price:check
       -> price:sync          reads config/products.yml and upserts Products
       -> CheckPriceJob       runs the Runner for each Product
            -> Runner
                 1. Markets.for(url)          finds the market by host
                 2. Fetcher.get(url, cookie)  downloads the page
                 3. market.price_cents(html)  extracts the price in cents
                 4. saves a PriceCheck and updates the Product (one transaction)
                 5. PriceMailer               emails on change or on failure
```

What happens on each check:

| Situation | PriceCheck | Product | Email |
|---|---|---|---|
| First check of a product | ok | price saved | none |
| Same price | ok | unchanged | none |
| Different price | ok | price and `last_changed_at` updated | price changed |
| Known failure (network, parsing, unknown market, missing config) | error | unchanged | check failed |

Unexpected errors for one product are logged and re-raised at the end of the job, after every other product has been checked. The service then exits with a failure status, which shows up in `systemctl --user --failed`.

## Data model

- `Product`: `slug` (unique), `name`, `url`, `price_cents`, `last_changed_at`. Holds the current state.
- `PriceCheck`: `product_id`, `status` (`ok` or `error`), `price_cents`, `error_message`, `checked_at`. Append only history.

## Markets

A market is a class in `app/services/price_tracker/markets/` that responds to:

- `host`: the hostname used to match product URLs
- `cookie`: the value of the `Cookie` header to send (some sites change the price by store or postal code)
- `price_cents(html)`: returns the price as integer cents, or raises `PriceTracker::Parser::ParseError`

Current markets:

- **Simão Doces**: price read from `#variacaoPreco`. A fixed cookie selects the store.
- **Jaú Serve**: price read from the sales price element (`span.sales span.value[content]`) and converted with `BigDecimal`. The cookie combines a store id and a postal code. The postal code is personal data, so it is read from an environment variable and never stored in the repository.

To add a new market:

1. Write the spec first, using a small HTML snippet that contains only the price markup
2. Create the class with `host`, `cookie` and `price_cents`
3. Register it in `PriceTracker::Markets.all`
4. Add the products to `config/products.yml`

A product whose host has no registered market is recorded as a failed check and reported by email. It does not affect the other products.

## Configuration

### Products

`config/products.yml`:

```yaml
products:
  my_product:
    name: "Product name"
    url: "https://www.example.com/product-page"
```

Only `name` and `url` are synced. Prices and history are never read from the file. A product removed from the file stays in the database, so its history is kept.

### Environment variables

| Variable | Required | Description |
|---|---|---|
| `PRICE_ALERT_EMAIL` | yes | Address that receives the emails |
| `SMTP_ADDRESS` | for real emails | SMTP host, for example `smtp.gmail.com` |
| `SMTP_PORT` | no | Defaults to `587` |
| `SMTP_USERNAME` | for real emails | SMTP user |
| `SMTP_PASSWORD` | for real emails | SMTP password. With Gmail, use an app password |
| `JAUSERVE_CEP` | for Jaú Serve | Postal code used to select the store price |

Without `SMTP_ADDRESS`, emails open in the browser through `letter_opener` in development. The app currently runs in the development environment on a personal machine.

## Getting started

Requirements: Ruby (see `.ruby-version`), Bundler and SQLite.

```bash
bundle install
bin/rails db:prepare
bundle exec rspec
```

Load the environment variables, then run the tasks:

```bash
set -a; source ~/.config/price-tracker/env; set +a

bin/rails price:sync     # sync products from config/products.yml
bin/rails price:check    # sync, then check every product
bin/rails price:report   # email the current price of every product
```

## Scheduling with systemd

The checks run from a systemd user timer. The environment file is read by the service, so credentials survive reboots and stay out of the repository.

`~/.config/price-tracker/env` (create the directory with `chmod 700` and the file with `chmod 600`). Use `KEY=value` lines, without `export` and without quotes:

```
RAILS_ENV=development
PRICE_ALERT_EMAIL=you@example.com
SMTP_ADDRESS=smtp.gmail.com
SMTP_USERNAME=you@example.com
SMTP_PASSWORD=your-app-password
JAUSERVE_CEP=00000-000
```

`~/.config/systemd/user/price-tracker.service`:

```ini
[Unit]
Description=Check product prices

[Service]
Type=oneshot
WorkingDirectory=/path/to/price_tracker
EnvironmentFile=%h/.config/price-tracker/env
Environment=PATH=%h/.rbenv/shims:%h/.rbenv/bin:/usr/local/bin:/usr/bin:/bin
ExecStartPre=/usr/bin/bash -c 'for i in $(seq 1 30); do getent hosts www.example.com >/dev/null && exit 0; sleep 2; done; exit 1'
ExecStart=%h/.rbenv/shims/bundle exec bin/rails price:check
```

`~/.config/systemd/user/price-tracker.timer`:

```ini
[Unit]
Description=Price check twice a day

[Timer]
OnCalendar=*-*-* 09,21:00:00
Persistent=true
RandomizedDelaySec=300

[Install]
WantedBy=timers.target
```

- `Persistent=true` runs a missed check once the machine is back on and the user is logged in.
- `RandomizedDelaySec` spreads the requests over a few minutes.
- The `ExecStartPre` line waits for the network, so a check right after boot does not fail because of Wi-Fi.
- The `PATH` line is needed so systemd finds the Ruby installed by rbenv.

Enable and inspect:

```bash
systemctl --user daemon-reload
systemctl --user enable --now price-tracker.timer
systemctl --user list-timers --no-pager
systemctl --user start price-tracker.service      # run once, right now
journalctl --user -u price-tracker.service -n 50 --no-pager -a
```

## Tests

```bash
bundle exec rspec
```

- Real HTTP requests are blocked by WebMock. The fetcher specs stub every request.
- Market specs use small inline HTML snippets with only the price markup.
- Runner specs use a fake market and stub the mailer, so they cover the orchestration only.

## Project layout

```
app/
  jobs/check_price_job.rb              runs the Runner for every product
  mailers/price_mailer.rb              price changed, check failed, price report
  models/product.rb                    current state of a tracked product
  models/price_check.rb                one record per check
  services/price_tracker/
    fetcher.rb                         HTTP with timeouts, raises FetchError
    markets.rb                         finds the market by host
    markets/simao.rb                   market: Simão Doces
    markets/jauserve.rb                market: Jaú Serve
    parser.rb                          HTML extraction used by the Simão Doces market
    product_sync.rb                    syncs config/products.yml into the database
    runner.rb                          one check of one product
config/products.yml                    the list of tracked products
lib/tasks/price.rake                   price:sync, price:check, price:report
```

## Known limitations and ideas

- A site that stays down sends one failure email per run, which is two a day.
- The price changed email is sent after the data is saved. If SMTP fails at that moment, that alert is lost.
- Extraction depends on the page markup, which sites can change. A failed extraction is recorded as an error and is never saved as a price.
- Ideas: JSON-LD as a price source, price target alerts, back in stock alerts, and a JSON endpoint with the price history.

## A note on scraping

This is a personal tool. It makes one request per product per run, twice a day. Check the terms of each site before adding it.
