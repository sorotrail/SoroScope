# Browsing the explorer

The UI is Go `html/template` plus [htmx](https://htmx.org) — server-rendered, no build step, no frontend framework. Filtering and paging an event list swap in place; everything else is a plain page load.

## The pages

| Path | Page |
| --- | --- |
| `/` | Overview: totals, event-type breakdown, recent events. |
| `/contracts` | Every contract with events, searchable and paginated. |
| `/contracts/{id}` | One contract: stats, type breakdown, filterable event list. |
| `/events/{id}` | One event fully expanded, decoded plus raw. |
| `/search?q=` | Routes a contract ID or event TOID to the right page. |

## Overview

The landing page answers "what is this instance holding?" — total events, how many contracts, the ledger range covered, and a breakdown by event type, followed by the most recent events.

In upstream mode the type breakdown is labelled approximate, because it is derived from a bounded scan rather than counted. The totals beside it are exact either way.

## Contracts

Every contract that has emitted at least one event, most recently active first. The search box matches any substring of a contract ID, case-insensitively — useful when you remember the beginning or end of an ID but not the middle.

Each row shows the event count and when the contract was last active. In upstream mode this list is derived from a bounded scan of recent events, so a contract that has been quiet for a long time may not appear even though its events are still retrievable directly.

## Contract detail

One contract's totals and type breakdown, above a filterable list of its events. The filters are the same ones the API exposes — type, topic, ledger range — and applying one swaps the list in place rather than reloading the page.

See [filtering events](filtering.md) for what each filter accepts.

## Event detail

One event fully expanded: its identifiers, the transaction it came from, its position within that transaction, whether it occurred in a successful call, and its decoded topics and value.

Both a rendered form and the raw stored JSON are shown. The rendered form is for reading; the raw form is what the API returns and what you would parse.

## Search

A single box that routes rather than searches. Give it a contract ID and you land on that contract; give it an event TOID and you land on that event. It is a navigation shortcut, not a full-text search — there is no index over topic contents to search against.

## The retention banner

Every page in standalone mode carries a banner explaining that SoroScope only captures events emitted while it was running. This is deliberate. An explorer that quietly showed a partial history would leave people concluding a contract had no activity when in fact the window simply predates the deployment.

In upstream mode the banner reflects whatever coverage the indexer reports instead.

## Everything is also JSON

Every page has an API equivalent with identical filters and pagination, so anything you can browse you can also query. See the [HTTP API reference](../reference/api.md).
