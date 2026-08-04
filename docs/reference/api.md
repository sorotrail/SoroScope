# HTTP API

Read-only JSON, mirroring the UI. Filters and pagination are identical to the web pages, and identical between the two operating modes.

There is no authentication — SoroScope serves public chain data. Put it behind a proxy if you need access control.

## `GET /health`

Returns the configured mode and whether the backend is reachable. Answers `200` when healthy and `503` when not, so it works as a container probe.

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

`retention_note` is a human-readable caveat about history coverage — the same text the UI banner shows.

## `GET /api/contracts`

Contracts with events, most recently active first.

Query parameters: `search` (substring of a contract ID, case-insensitive), `cursor`, `limit` (1–200, default 50).

```sh
curl -s 'localhost:8080/api/contracts?limit=2'
```

```json
{
  "contracts": [
    {
      "id": "CDLZFC3SYJYDZT7K67VZ75HPJVIEUVNIXF47ZG2FB2RMQQVU2HHGCYSC",
      "event_count": 4987,
      "first_ledger": 3930041,
      "last_ledger": 3930272,
      "last_activity": "2026-08-02T12:43:57+01:00"
    }
  ],
  "next_cursor": "MzkzMDI3MXxDQkxWWlo1NTdBTEIzNDJHQlFJTUMyRTNJWVhKNUFFTDdYU1ZNUFgzNkNWTEtSRFFHREgyMlVMNg"
}
```

In upstream mode this list is derived from a bounded scan of recent events — see [upstream mode](../modes/upstream.md).

## `GET /api/events` and `GET /api/contracts/{id}/events`

Events newest first. The contract-scoped form is the same endpoint with the contract fixed.

Query parameters:

| Parameter | Description |
| --- | --- |
| `type` | `contract`, `system` or `diagnostic`. |
| `topic` | A bare word is treated as an event name, so `topic=transfer` means `{"symbol":"transfer"}`. Any JSON value also works, e.g. `topic={"address":"G…"}`. Matches at any topic position. |
| `from_ledger` / `to_ledger` | Inclusive ledger bounds. |
| `cursor` | Opaque; pass back the `next_cursor` from the previous page. |
| `limit` | 1–200, default 50. |

```sh
curl -s 'localhost:8080/api/events?topic=fee&limit=1'
```

```json
{
  "events": [
    {
      "id": "0016880389704384512-0000000003",
      "contract_id": "CDLZFC3SYJYDZT7K67VZ75HPJVIEUVNIXF47ZG2FB2RMQQVU2HHGCYSC",
      "ledger": 3930272,
      "type": "contract",
      "tx_hash": "bcd19d1ae7ca70115c19a5098652b242e5c98c9f2ed9355f07433f99d84920dd",
      "tx_index": 0,
      "op_index": 0,
      "in_successful_call": true,
      "topics": [
        {"symbol": "fee"},
        {"address": "GDS2XSFBG5KQ3G3UNGSA6EX6E4OS3CSBS3NHFS7AGWZP67KD7T46HQJH"}
      ],
      "value": {"i128": "26039"},
      "ledger_closed_at": "2026-08-02T12:43:57+01:00",
      "created_at": "2026-08-03T12:28:52.587273+01:00"
    }
  ],
  "next_cursor": "0016880389704384512-0000000002"
}
```

Paging until `next_cursor` is absent walks the whole result set, newest to oldest, without repeats — in both modes.

See [filtering events](../guides/filtering.md) for what each filter accepts.

## `GET /api/events/{id}`

One event by its TOID. `404` when the source has no such event.

```sh
curl -s localhost:8080/api/events/0016880389704384512-0000000003
```

Note that "no such event" and "that event is outside this instance's coverage" are the same `404`. In standalone mode an event emitted before the instance started will not be found even though it existed on chain.

## `GET /api/contracts/{id}/stats`

One contract's totals and event-type breakdown.

## `GET /api/stats`

Everything visible to this source.

```sh
curl -s localhost:8080/api/stats
```

```json
{
  "total_events": 6600,
  "contract_count": 51,
  "first_ledger": 3930041,
  "last_ledger": 3930210,
  "type_breakdown": [{"type": "contract", "count": 6600}],
  "approximate": false
}
```

`approximate` is `false` in standalone mode, where everything is counted in SQL. It is `true` in upstream mode, where the type breakdown is derived from a bounded scan — the totals themselves still come straight from SoroTrail.

Treat `approximate: true` as a signal to label the figure in any UI you build on top, the way SoroScope's own pages do.

## Field notes

**`id`** is the RPC's TOID-based identifier and is zero-padded, so lexicographic order matches chronological order. This is what makes cursor pagination stable.

**`ledger_closed_at`** is the on-chain time — when the event's ledger closed. **`created_at`** is when SoroScope ingested the row, which in standalone mode is unrelated to when the event happened. Use `ledger_closed_at` for anything user-facing.

**`topics`** and **`value`** are decoded `ScVal`s in single-key wrapper form. See [event decoding](decoding.md).

**`in_successful_call`** distinguishes events emitted in a call that ultimately succeeded from those in a reverted one. Both are recorded.
