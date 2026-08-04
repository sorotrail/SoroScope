# Development guide

## Prerequisites

Go and Docker. Postgres is optional — the tests that need it skip themselves when it is absent.

## Make targets

```sh
make build     # compile to bin/soroscope
make test      # unit tests; the Postgres tests skip without a database
make test-db   # everything, against the docker-compose Postgres
make lint      # golangci-lint
make fmt       # gofmt
make run       # run from source
```

`make test` passing with no database running is a property worth preserving — it means a new contributor can clone the repository and immediately run the suite. If you add a test that needs Postgres, make it skip cleanly rather than fail.

## Running locally

### Standalone

```sh
docker compose up -d postgres     # or bring your own Postgres
cp .env.example .env              # adjust as needed
set -a; source .env; set +a
make run
```

Set `WATCHED_CONTRACTS` to a contract or two while developing. The default ingests every contract event on the network, which is far more data than you want locally.

### Upstream

```sh
SOURCE_MODE=sorotrail SOROTRAIL_URL=http://localhost:8080 HTTP_ADDR=:8090 make run
```

Note the changed `HTTP_ADDR` — SoroTrail also defaults to `:8080`.

## Layout

| Package | Responsibility |
| --- | --- |
| `cmd/soroscope` | Wiring and the `SOURCE_MODE` switch. |
| `internal/config` | Environment parsing and per-mode validation. |
| `internal/source` | The `EventSource` interface and shared types. |
| `internal/source/rpcsource` | Standalone backend. |
| `internal/source/sorotrailsource` | Upstream backend. |
| `internal/store` | Postgres access and migrations. |
| `internal/ingest` | The RPC polling loop. |
| `internal/rpc` | Stellar RPC client. |
| `internal/decode` | `ScVal` decoding and rendering. |
| `internal/api` | JSON handlers. |
| `internal/web` | Templates and htmx partials. |

See [architecture](../reference/architecture.md) for how these fit together.

## Working on the UI

Templates are in `internal/web/templates` — `layout.html` wraps the rest, `partials.html` holds the fragments htmx swaps in.

There is no build step and no frontend toolchain. Editing a template and restarting is the whole loop. Keep it that way: adding a bundler would make the project meaningfully harder to contribute to, for very little gain on a server-rendered UI this size.

## Working on decoding

`internal/decode` splits into `xdr.go` (the base64 XDR fallback path), `bigint.go` (wide integers as decimal strings) and `render.go` (the readable form the UI shows). `render_test.go` and `xdr_test.go` are the places to add cases.

Remember the invariant: the API returns values **as stored**, and rendering is UI-only and lossy. Do not move rendering into the API layer.

## Adding a migration

Migrations are numbered `.up.sql`/`.down.sql` pairs in `internal/store/migrations` and run automatically at startup.

Give each a number nobody else has claimed. Duplicate migration numbers break the loader — not just the duplicated migration, the whole sequence — and it is an easy collision when two branches are open at once. Check the directory before choosing.

## Before opening a pull request

```sh
make fmt
make lint
make test
```

If your change touches the store, run `make test-db` too.

Keep changes scoped to one thing. If you find an unrelated problem, an issue describing it is more useful than a second unrelated commit in the same branch.

## Adding a new backend

See [adding an event source](extending.md) — it is the main extension point and the interface is only six methods.
