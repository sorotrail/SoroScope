# SoroScope

A contract explorer and event-data UI for the Stellar/Soroban network.

Stellar's existing explorers show transactions and payments well. What they do not show well is **decoded Soroban contract event data** — what a contract actually emitted, with human-readable topics and values, browsable and filterable. SoroScope is a focused, self-hostable explorer for exactly that.

Point it at a network, and browse contracts, inspect their decoded events, and filter across them in a small server-rendered web UI. Everything the UI shows is also available as JSON, so SoroScope doubles as a queryable API.

```
                    ┌──────────────┐
 Stellar RPC ──────▶│              │
 (standalone)       │  SoroScope   │──▶ web UI + JSON API
 SoroTrail API ────▶│              │
 (upstream)         └──────────────┘
```

## Two ways to run it

SoroScope reads events through a single `EventSource` interface with two implementations, selected by `SOURCE_MODE`. Everything above that interface — the web UI and the whole JSON API — behaves identically either way.

| | [Standalone](modes/standalone.md) | [Upstream](modes/upstream.md) |
| --- | --- | --- |
| `SOURCE_MODE` | `rpc` | `sorotrail` |
| Reads from | Stellar RPC directly | A SoroTrail indexer's API |
| Database | Postgres, its own | None |
| History reaches back | Only while it was running | As far as the indexer has run |

If you are not sure which you want, see [choosing a mode](modes/choosing.md).

## Start here

* **[Quickstart](getting-started/quickstart.md)** — running in one command
* **[Configuration](getting-started/configuration.md)** — every environment variable
* **[HTTP API](reference/api.md)** — the JSON endpoints
* **[Adding an event source](contributing/extending.md)** — the main extension point

## The retention caveat

This is the single most important thing to understand about a standalone deployment. **Stellar RPC only keeps contract events for roughly 24 hours to 7 days.** A standalone SoroScope can therefore only ever capture events emitted while it was running — history from before you started it is not available anywhere for it to read.

SoroScope states this in a banner on every page rather than silently looking like a broken explorer. Upstream mode is the answer when you need real history: [SoroTrail](https://github.com/sorotrail/SoroTrail) stores events durably past that window, and SoroScope reads back through it.

## Related projects

Three tools over the same Soroban event data, each useful on its own:

* **[SoroTrail](https://github.com/sorotrail/SoroTrail)** — indexes contract events durably, past the RPC's retention window. SoroScope reads from it in upstream mode.
* **SoroBeacon** — monitors contract events and sends alerts when they match a rule.
* **SoroScope** — browses and explores the events, decoded.

## License

Apache-2.0.
