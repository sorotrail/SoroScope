# Upstream mode

`SOURCE_MODE=sorotrail`

SoroScope reads from an existing [SoroTrail](https://github.com/sorotrail/SoroTrail) indexer's HTTP API instead of polling the RPC. SoroTrail stores events durably, so this mode reaches back as far as that indexer has been running — well beyond the RPC's own window.

```
 SoroTrail API ──▶ SoroScope ──▶ web UI + JSON API
```

**No database of its own, no ingestion, no migrations.** SoroScope becomes a pure presentation layer.

## What you need

| | |
| --- | --- |
| Required | `SOROTRAIL_URL` |
| Ignored | `DATABASE_URL`, `RPC_URL`, and every ingestion variable |

`SOROTRAIL_URL` is a base URL with no path — `http://localhost:8080`, not `http://localhost:8080/api`.

Since SoroTrail also defaults to `:8080`, running both on one host means moving one of them:

```sh
SOURCE_MODE=sorotrail SOROTRAIL_URL=http://localhost:8080 HTTP_ADDR=:8090 make run
```

## Two things it works around

SoroScope adapts to SoroTrail's current API rather than requiring changes to it. Both workarounds are visible in behaviour, so they are documented rather than buried.

### Descending order is synthesised

**SoroTrail paginates ascending by event ID only.** SoroScope shows newest first, so it walks ledger windows backwards and reverses locally, narrowing the window when a range turns out to be dense.

A page view normally costs **two to four upstream requests**. This is the main reason upstream mode feels slightly slower than standalone on a large dataset.

### The contracts list is approximate

**SoroTrail has no contracts endpoint.** The contracts list is therefore derived from a bounded scan of recent events, cached briefly, and reported as approximate — `approximate: true` in the API, and labelled in the UI.

Totals on `/api/stats` still come straight from SoroTrail and are exact. It is only the type breakdown and the contract enumeration that are derived.

### Both would collapse into pass-through calls

If SoroTrail gained a descending-order parameter and a `GET /contracts` endpoint, both workarounds would reduce to simple proxying. That makes them good contribution targets on either side — see [CONTRIBUTING.md](https://github.com/sorotrail/SoroScope/blob/main/CONTRIBUTING.md).

## When to prefer this mode

* You need history older than the RPC's 24h–7d window.
* You already run SoroTrail and do not want a second copy of the same data.
* You want the explorer to be stateless — several SoroScope instances can share one indexer.
* You want to survive downtime without permanent gaps.

## When not to

* You have no SoroTrail deployment and do not want to run one — use [standalone](standalone.md).
* You need the fastest possible page loads over a large dataset, where local SQL beats several upstream round trips.

## Health

`/health` reports the upstream's reachability:

```json
{
  "mode": "sorotrail",
  "healthy": true,
  "latest_ledger": 3947332
}
```

An unreachable indexer is a `503` with a `detail` explaining it, never a crash — the UI still renders and tells the user what is wrong.
