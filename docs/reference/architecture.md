# Architecture

SoroScope is a single Go binary. Its design turns on one seam: **`EventSource`**, the interface between the read paths and wherever events actually come from.

```
        ┌───────────────────────────────────┐
        │  internal/web    internal/api     │   UI + JSON, mode-agnostic
        └────────────────┬──────────────────┘
                         │  source.EventSource
        ┌────────────────┴──────────────────┐
        │                                   │
  rpcsource                          sorotrailsource
  (Postgres +                        (SoroTrail HTTP API)
   ingester)
```

Everything above the interface behaves identically whichever implementation is below it. That is why `SOURCE_MODE` can change the entire data pipeline without touching a handler.

## Packages

| Package | Responsibility |
| --- | --- |
| `cmd/soroscope` | Wiring and the `SOURCE_MODE` switch. |
| `internal/config` | Environment parsing and per-mode validation. |
| `internal/source` | The `EventSource` interface and its shared types. No dependencies beyond the standard library. |
| `internal/source/rpcsource` | Standalone backend: reads from Postgres. |
| `internal/source/sorotrailsource` | Upstream backend: reads from a SoroTrail indexer. |
| `internal/store` | Postgres access and migrations. Standalone only. |
| `internal/ingest` | The RPC polling loop. Standalone only. |
| `internal/rpc` | Stellar RPC JSON-RPC client. |
| `internal/decode` | `ScVal` decoding and rendering. |
| `internal/api` | JSON handlers. |
| `internal/web` | `html/template` pages and htmx partials. |

## The `EventSource` interface

Six read-only methods, all of which must be safe for concurrent use by multiple HTTP handlers:

```go
type EventSource interface {
    ListContracts(ctx context.Context, q ContractQuery) (ContractPage, error)
    ListEvents(ctx context.Context, q EventQuery) (EventPage, error)
    GetEvent(ctx context.Context, id string) (Event, error)
    ContractStats(ctx context.Context, contractID string) (ContractStats, error)
    Stats(ctx context.Context) (Stats, error)
    Status(ctx context.Context) Status
}
```

Three details matter for anyone implementing it:

**`ErrNotFound` must be returned or wrapped exactly.** Handlers map it to a 404 without knowing which backend produced it. Returning a different error means a 500 where a 404 belonged.

**`Status` returns no error.** An unreachable backend is a `Status` with `Healthy: false`, not a failure — so the UI can always render its banner instead of erroring out.

**Cursors are opaque and implementation-owned.** Only the implementation that produced a cursor may interpret it. The two shipped backends encode them completely differently.

`NormalizeLimit` in the same package clamps page sizes into the shared 1–200 bounds, so a limit means the same thing everywhere.

## The two implementations

**`rpcsource`** sits on Postgres. The ingester writes; this reads. Queries are ordinary SQL, so counts are exact and paging is a `WHERE id < $cursor ORDER BY id DESC`.

**`sorotrailsource`** sits on SoroTrail's HTTP API and does more work, because that API paginates ascending only and has no contracts endpoint. It walks ledger windows backwards and reverses locally, and derives the contract list from a bounded scan. See [upstream mode](../modes/upstream.md) for what this costs and why.

The split across three files reflects that: `client.go` speaks HTTP, `scan.go` holds the window-walking and scanning logic, `sorotrailsource.go` implements the interface on top.

## Request flow

A page view or an API call follows the same path:

1. `internal/web` or `internal/api` parses query parameters into a `source.EventQuery`.
2. It calls the configured `EventSource`.
3. Results come back as `source.Event` values with topics and value as raw decoded JSON.
4. The API returns them as stored; the web layer renders them through `internal/decode`.

Ingestion, in standalone mode, runs independently of all of this — the API answers from whatever is stored, whether or not the ingester is currently caught up.

## Design choices worth knowing

**Server-rendered UI.** Go `html/template` plus htmx: no build step, no `node_modules`, no separate frontend deployment. Filtering and paging swap fragments in place; everything else is a plain page load.

**Events are immutable.** Inserted with `ON CONFLICT (id) DO NOTHING`, so re-reading a ledger range is a no-op. This makes the ingester safe to restart at any point.

**Decoded once, at ingest.** Topics and values are stored already decoded, so reads never pay for XDR parsing. See [event decoding](decoding.md).

**`internal/source` has no dependencies.** Deliberately — so the store layer and every implementation can import it freely without cycles.
