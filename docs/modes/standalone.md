# Standalone mode

`SOURCE_MODE=rpc`

SoroScope polls Stellar RPC's `getEvents` itself and stores what it finds in its own Postgres database. Self-contained: all you need is an RPC endpoint and a database.

```
 Stellar RPC ──poll──▶ ingester ──▶ Postgres ──▶ web UI + JSON API
```

## What you need

| | |
| --- | --- |
| Required | `DATABASE_URL` |
| Usually set | `RPC_URL`, `WATCHED_CONTRACTS` |
| Optional | `POLL_INTERVAL`, `RETENTION_LEDGERS`, `START_LEDGER` |

Migrations run automatically at startup, so an empty database is fine.

## How ingestion works

A single loop polls `getEvents` forward from a stored resume point:

1. On a **cold start** — no stored state — the starting ledger is `START_LEDGER` if set, otherwise the current tip minus `RETENTION_LEDGERS`.
2. Each poll requests the next window of ledgers, batching watched contracts to respect the RPC's caps of **5 filters per request** and **5 contract IDs per filter**.
3. Events are written with `ON CONFLICT (id) DO NOTHING`. An event is immutable once written, so re-reading a ledger range is a no-op rather than a rewrite.
4. The resume point advances, and once caught up the loop sleeps for `POLL_INTERVAL`.

Because the resume point is stored, a restart continues where it left off instead of re-reading from the retention horizon.

## The retention limit

This is the defining constraint of standalone mode and worth stating plainly:

> **Stellar RPC keeps contract events for roughly 24 hours to 7 days.** A standalone SoroScope can only ever capture events emitted while it was running. History from before you started it is not available for it to read — not slowly, not with a larger `RETENTION_LEDGERS`, not at all.

SoroScope does not hide this. Every page carries a banner, and `/health` returns a `retention_note` explaining the coverage. An explorer that silently showed a partial history would be worse than one that admits its limits.

If you need history that outlives the RPC's window, that is exactly what [upstream mode](upstream.md) is for.

## Downtime is a permanent gap

A corollary that surprises people: if a standalone instance is down for longer than the RPC's retention window, the events emitted during that outage are gone for good. The resume point will still be where it was, but the node no longer holds those ledgers.

For deployments where gaps matter, run [SoroTrail](https://github.com/sorotrail/SoroTrail) as the durable indexer and point SoroScope at it.

## Operational notes

* **Disk grows without bound.** SoroScope has no pruner — every event it ingests is kept. With `WATCHED_CONTRACTS` empty on a busy network, plan capacity accordingly.
* **One ingester per database.** Two instances writing the same database will both poll and both insert; the `ON CONFLICT` makes this harmless but wasteful.
* **The UI is readable during catch-up.** Ingestion and serving are independent — the API answers from whatever is already stored.

## See also

* [Configuration](../getting-started/configuration.md) — every variable in detail
* [Data model](../reference/data-model.md) — the tables and indexes
* [Upstream mode](upstream.md) — the alternative
