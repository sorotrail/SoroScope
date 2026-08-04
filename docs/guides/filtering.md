# Filtering events

The same filters apply to the event list in the UI and to `GET /api/events` and `GET /api/contracts/{id}/events`. They combine with AND — every filter you add narrows the result further.

## The filters

| Parameter | Description |
| --- | --- |
| `type` | `contract`, `system` or `diagnostic`. |
| `topic` | A bare word is treated as an event name, so `topic=transfer` means `{"symbol":"transfer"}`. Any JSON value also works, e.g. `topic={"address":"G…"}`. Matches at any topic position. |
| `from_ledger` / `to_ledger` | Inclusive ledger bounds. |
| `cursor` | Opaque; pass back the `next_cursor` from the previous page. |
| `limit` | 1–200, default 50. |

## Filtering by topic

Topic filtering is the one worth understanding properly, because it is what makes the explorer useful.

Contract events carry topics as an array of decoded `ScVal`s. Most contracts put the event name first — `transfer`, `mint`, `approve` — followed by the addresses and values involved.

### By event name

A bare word is a convenience for the common case:

```sh
curl -s 'localhost:8080/api/events?topic=transfer'
```

This is exactly equivalent to passing `{"symbol":"transfer"}`. Symbols are how contracts encode event names, so the shorthand covers most of what people want.

### By any topic value

Pass JSON to match anything else:

```sh
curl -s 'localhost:8080/api/events?topic={"address":"GDS2XSFBG5KQ3G3UNGSA6EX6E4OS3CSBS3NHFS7AGWZP67KD7T46HQJH"}'
```

Remember to URL-encode it in a real client.

### Position does not matter

A topic filter matches at **any position** in the topics array. Filtering by an address finds events where that address is the sender, the recipient, or anywhere else it appears — SoroScope does not know which position means what, because that is contract-specific.

To pin down a direction, combine the topic filter with the contract and read the results — or file an issue if you want positional matching, since it is a reasonable thing to want.

### Matching is exact

A topic value matches or it does not. There is no substring, prefix or numeric-range matching on topics — `{"i128":"1000"}` will not match an event whose value is `1001`. The stored form is a single-key wrapper and the comparison is against that whole value.

## Filtering by ledger range

`from_ledger` and `to_ledger` are inclusive and can be used independently:

```sh
curl -s 'localhost:8080/api/events?from_ledger=3930000&to_ledger=3930500'
```

Ledger numbers are the practical way to express "around this time" — an event's `ledger_closed_at` gives you the wall-clock time of any ledger you already have, which you can use to bracket a range.

## Paging

Results are newest first. Pass the `next_cursor` from one response as the `cursor` of the next:

```sh
curl -s 'localhost:8080/api/events?limit=50'
curl -s 'localhost:8080/api/events?limit=50&cursor=0016880389704384512-0000000002'
```

Paging until `next_cursor` is absent walks the whole result set, newest to oldest, **without repeats** — in both modes. Event IDs are zero-padded TOIDs, so their lexicographic order matches chronological order, which is what makes stable cursor paging possible.

Treat the cursor as opaque. Only the backend that produced it can interpret it, and the two modes encode them differently.

## Limits

`limit` is clamped to 1–200 with a default of 50. Asking for more than 200 gets you 200 rather than an error.
