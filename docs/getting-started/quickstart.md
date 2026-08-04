# Quickstart

The fastest path is standalone mode against the public Stellar testnet, which needs nothing but Docker.

## Standalone, with Docker

```sh
docker compose up --build
```

This starts Postgres and SoroScope. The UI is on [http://localhost:8080](http://localhost:8080); watch the logs to see events arrive. Migrations run automatically at startup.

Give it a minute before judging it as empty. A fresh standalone instance starts from the retention horizon and works forward, so the first page of results appears once ingestion catches up to the chain tip.

### Watching specific contracts

By default SoroScope ingests **every** contract event on the network, which is a lot. To narrow it:

```sh
WATCHED_CONTRACTS=CDLZFC3SYJYDZT7K67VZ75HPJVIEUVNIXF47ZG2FB2RMQQVU2HHGCYSC \
  docker compose up --build
```

Watching more than 25 contracts is supported — SoroScope batches them across requests to respect the RPC's caps of 5 filters per request and 5 contract IDs per filter.

## Standalone, bare metal

```sh
docker compose up -d postgres     # or bring your own Postgres
cp .env.example .env              # adjust as needed
set -a; source .env; set +a
make run
```

## Upstream, against a SoroTrail indexer

No database needed:

```sh
SOURCE_MODE=sorotrail \
SOROTRAIL_URL=http://localhost:8080 \
HTTP_ADDR=:8090 \
  make run
```

Or through compose:

```sh
SOURCE_MODE=sorotrail SOROTRAIL_URL=http://your-sorotrail:8080 docker compose up
```

Note the `HTTP_ADDR=:8090` in the bare-metal example. SoroTrail also defaults to `:8080`, so running both on one machine needs one of them moved.

## Checking it works

```sh
curl -s localhost:8080/health
```

```json
{
  "mode": "rpc",
  "healthy": true,
  "latest_ledger": 3947332,
  "retention_note": "Standalone mode captures events only while SoroScope is running: …"
}
```

`/health` answers `200` when healthy and `503` when not, so it works directly as a container probe.

## Next steps

* [Configuration](configuration.md) — every variable and which mode needs it
* [Browsing the explorer](../guides/browsing.md) — what each page does
* [HTTP API](../reference/api.md) — the JSON endpoints
