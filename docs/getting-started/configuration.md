# Configuration

All configuration comes from environment variables. SoroScope validates the variables its selected mode requires and **fails at startup** with a message naming both the variable and the mode, rather than failing later on a request.

## Every variable

| Variable | Default | Mode | Description |
| --- | --- | --- | --- |
| `SOURCE_MODE` | `rpc` | both | `rpc` (standalone) or `sorotrail` (upstream). |
| `HTTP_ADDR` | `:8080` | both | Listen address for the UI and API. |
| `LOG_LEVEL` | `info` | both | `debug` \| `info` \| `warn` \| `error`. |
| `RPC_URL` | `https://soroban-testnet.stellar.org` | standalone | Stellar RPC endpoint. Point at a provider URL for mainnet. |
| `DATABASE_URL` | — (**required**) | standalone | Postgres connection string. |
| `POLL_INTERVAL` | `5s` | standalone | Sleep between polls once caught up. Minimum 1s. |
| `WATCHED_CONTRACTS` | empty | standalone | Comma-separated contract IDs. Empty ingests **all** contract events. |
| `START_LEDGER` | unset | standalone | Force cold-start ingestion from this ledger. |
| `RETENTION_LEDGERS` | `17280` | standalone | Cold-start reach-back in ledgers (~24h at 5s/ledger). |
| `SOROTRAIL_URL` | — (**required**) | upstream | Base URL of a SoroTrail indexer. |

A variable belonging to the mode you are not running is ignored, not rejected. You can keep a single `.env` holding both sets and switch modes with `SOURCE_MODE` alone.

## Notes on the ones that bite

### `WATCHED_CONTRACTS`

Leaving this empty is a deliberate default, not an oversight — it makes the quickstart work with no arguments. But on a busy network it means ingesting every contract event there is. For anything beyond a first look, name the contracts you care about.

### `RETENTION_LEDGERS` and `START_LEDGER`

These only matter on a **cold start**, when there is no stored resume point. Once SoroScope has ingested anything it resumes from where it stopped and ignores both.

`RETENTION_LEDGERS` defaults to 17280, about 24 hours at 5 seconds per ledger. Raising it does not conjure history the RPC has already dropped — if you ask to reach back further than the node retains, you get what the node still has. `START_LEDGER` overrides the calculation entirely when you know the exact ledger you want.

### `POLL_INTERVAL`

The sleep between polls **once caught up**. While catching up, SoroScope pages forward as fast as the RPC allows and does not sleep. The minimum accepted value is 1s.

### `RPC_URL`

The default is the public Stellar testnet endpoint. Public endpoints are rate-limited and not intended for sustained ingestion — for mainnet or anything long-running, use a provider URL.

### `SOROTRAIL_URL`

The base URL only, with no path: `http://localhost:8080`, not `http://localhost:8080/api`. SoroScope appends the paths it needs.

## Configuration for mainnet

There is no `NETWORK` variable — the network is whatever `RPC_URL` points at. For mainnet, set an appropriate provider endpoint and expect to want `WATCHED_CONTRACTS` set:

```sh
SOURCE_MODE=rpc
RPC_URL=https://your-mainnet-provider.example/soroban/rpc
DATABASE_URL=postgres://…
WATCHED_CONTRACTS=CDLZ…,CBLV…
RETENTION_LEDGERS=17280
```
