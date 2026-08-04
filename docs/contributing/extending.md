# Adding an event source

`EventSource` is SoroScope's main extension point. Implement it and SoroScope can read events from somewhere new — a different indexer, a data warehouse, a file of captured events for testing — with **no changes to the API or web layers**.

The package documentation says it directly:

> To add a new backend, implement `EventSource` in a new package under `internal/source` and wire it into the switch in `cmd/soroscope`. Nothing outside that switch should need to change — the API and web layers only ever see this interface.

## The interface

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

Six methods, all read-only. `internal/source` deliberately has no dependencies beyond the standard library, so your package can import it freely.

## Steps

1. **Create a package** under `internal/source`, e.g. `internal/source/mysource`.
2. **Implement the six methods.** Take whatever configuration you need as constructor arguments.
3. **Add config fields** in `internal/config` for anything environment-driven, with validation that names your mode in the error.
4. **Wire it into the switch** in `cmd/soroscope` under a new `SOURCE_MODE` value.
5. **Test it** — see below.

## Contracts your implementation must honour

These are not stylistic preferences; the layers above depend on them.

**Return `source.ErrNotFound` from `GetEvent`, exactly.** Wrap it or return it, but handlers check for that error to produce a 404. Any other error becomes a 500.

**`Status` must not return an error.** An unreachable backend is a `Status` with `Healthy: false` and an explanatory `Detail`. This is what lets the UI always render a banner rather than failing the page.

**All methods must be safe for concurrent use.** Multiple HTTP handlers call them simultaneously.

**Order results correctly.** `ListEvents` returns newest first. `ListContracts` returns most recently active first.

**Treat cursors as yours alone.** A cursor is opaque to everyone else, so encode whatever you need. Just make paging **stable and repeat-free**: paging until `NextCursor` is empty must walk the whole result set exactly once.

**Clamp limits with `source.NormalizeLimit`.** It applies the shared 1–200 bounds so a page size means the same thing across backends.

**Set `Approximate` honestly.** If your counts come from a bounded scan rather than an exact count, say so. The UI labels approximate figures, and a client that trusted a wrong number would be worse off than one told it was an estimate.

## Two worked examples already in the tree

**`rpcsource`** is the simple case — it sits on Postgres, so ordering and counting are just SQL. Read this one first.

**`sorotrailsource`** is the instructive one. Its upstream paginates ascending only and has no contracts endpoint, so it walks ledger windows backwards and reverses locally, and derives contracts from a bounded scan. Its three files separate the concerns: `client.go` speaks HTTP, `scan.go` holds the window-walking, `sorotrailsource.go` implements the interface.

If your backend has awkward constraints, `sorotrailsource` shows how to adapt without leaking those constraints upward.

## Testing

Both shipped implementations have tests beside them — `rpcsource_test.go` and `sorotrailsource_test.go`. Follow the same pattern.

The store integration tests skip themselves when no database is present, so `make test` passes without Postgres and `make test-db` runs everything against the compose database. Keep that property: a contributor without Postgres should still be able to run the suite.

## Other places worth contributing

Beyond new sources, two known workarounds would disappear if SoroTrail's API gained capabilities — a descending-order parameter and a `GET /contracts` endpoint would each collapse a chunk of `sorotrailsource` into a pass-through call. That is a contribution on either side of the pair.

See [CONTRIBUTING.md](https://github.com/sorotrail/SoroScope/blob/main/CONTRIBUTING.md) in the repository.
