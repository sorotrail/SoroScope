# Choosing a mode

Both modes serve an identical UI and an identical API. The choice is entirely about **where events come from** and **how far back they reach**.

## The short version

> Want to try it in one command? **Standalone.**
> Need history older than a few days? **Upstream**, with SoroTrail behind it.

## Side by side

| | Standalone (`rpc`) | Upstream (`sorotrail`) |
| --- | --- | --- |
| Reads from | Stellar RPC directly | A SoroTrail indexer's API |
| Database | Postgres, its own | None |
| Migrations | Run at startup | None |
| History reaches back | Only while it was running | As far as the indexer has run |
| Survives downtime | No — gaps are permanent | Yes, the indexer keeps running |
| Extra infrastructure | Postgres | A SoroTrail deployment |
| Contract list | Exact, counted in SQL | Approximate, from a bounded scan |
| Stats totals | Exact | Exact |
| Requests per page view | One local query | Two to four upstream calls |
| Stateless (horizontally scalable) | No | Yes |

## Decide by what you are doing

**Evaluating SoroScope, or developing against it.** Standalone. `docker compose up --build` and you have a working explorer with no other moving parts. Set `WATCHED_CONTRACTS` to something specific so you are not ingesting an entire network for a demo.

**Watching a handful of contracts you deployed, from now on.** Standalone is genuinely sufficient. You only care about events from here forward, which is exactly what it captures. Be aware that a long outage is an unrecoverable gap.

**Investigating something that already happened.** Upstream — assuming an indexer was already running. If nothing was indexing at the time, no configuration of either mode recovers those events; the RPC has dropped them.

**Running an explorer as a service, for other people.** Upstream. It is stateless, so you can run several instances behind a load balancer, and the durable history lives in one place instead of being duplicated per instance.

**Already running SoroTrail.** Upstream, almost certainly. Standalone would mean a second ingestion pipeline and a second copy of the same events.

## Switching later

Switching is just changing `SOURCE_MODE` and restarting — nothing above the `EventSource` interface changes, so bookmarks, API clients and dashboards keep working.

Going standalone → upstream leaves your Postgres database untouched but unused. Going upstream → standalone starts from an empty database at the retention horizon; it does not import the indexer's history.

## A third option

Neither mode fits? The [`EventSource` interface](../contributing/extending.md) is a deliberately small seam — six methods — and adding a backend means implementing it and adding one line to a switch. Nothing in the API or web layers needs to change.
