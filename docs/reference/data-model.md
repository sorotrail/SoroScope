# Data model

**Standalone mode only.** Upstream mode uses no database at all — it holds nothing locally and every read goes to the indexer.

Migrations live in `internal/store/migrations` and run automatically at startup, so an empty database is all you need to provide.

## `events`

One row per contract event.

| Column | Notes |
| --- | --- |
| `id` | TOID, **primary key**. Zero-padded, so lexicographic order matches chronological order. |
| `contract_id` | The emitting contract. |
| `ledger` | Ledger sequence number. |
| `type` | `contract`, `system` or `diagnostic`. |
| `tx_hash` | The transaction that produced it. |
| `tx_index` | Position of the transaction within its ledger. |
| `op_index` | Position of the operation within the transaction. |
| `in_successful_call` | Whether the emitting call ultimately succeeded. |
| `topics` | `jsonb` — array of decoded `ScVal`s. |
| `value` | `jsonb` — a single decoded `ScVal`. |
| `ledger_closed_at` | On-chain time: when the ledger closed. |
| `created_at` | Ingest time. Unrelated to when the event happened. |

### Indexes

| Index | Serves |
| --- | --- |
| `contract_id` | Per-contract event lists. |
| `ledger` | Ledger-range filters. |
| `(contract_id, ledger)` | Both together — the contract detail page. |
| `id` descending | Cursor paging, newest first. |
| GIN on `topics` | The topic filter. |

The GIN index is what makes topic filtering viable — a containment query against JSONB rather than a scan.

## `ingest_state`

A single row holding the resume point, so a restart continues instead of re-reading from the retention horizon.

This is the whole of SoroScope's mutable state. Deleting it does not delete events; it makes the next start a cold start, which will re-read from the retention horizon and insert nothing it already has.

## Immutability

Events are inserted with `ON CONFLICT (id) DO NOTHING`. An event is immutable once written, so re-reading a ledger range is a no-op rather than a rewrite.

Three things follow from this:

* The ingester is **safe to restart at any point**, including mid-window. Overlap is free.
* Running two ingesters against one database is harmless, just wasteful.
* There is no update path. A stored event is what the RPC said at ingest time, permanently.

## Growth

There is **no pruner**. Every event ingested is kept indefinitely.

With `WATCHED_CONTRACTS` empty on a busy network this grows quickly, since it means ingesting every contract event there is. Plan capacity accordingly, or narrow the watch list.

If you need retention policy, that is a reasonable feature request — and a well-scoped one, since it touches only the store layer.

## Querying directly

Nothing stops you querying Postgres yourself; the schema is small and stable. Two things to remember if you do:

* **Topics and values are already decoded** — you are querying JSONB wrappers like `{"symbol":"transfer"}`, not XDR.
* **Wide integers are strings inside that JSON**, so numeric comparison on an `i128` needs a cast, and the cast will fail on values that genuinely exceed what you cast to.
