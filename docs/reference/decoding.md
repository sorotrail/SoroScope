# Event decoding

Contract events carry topics and a value as Soroban `ScVal`s — a binary XDR union. Making those readable is most of what SoroScope does.

## How SoroScope gets decoded values

When the RPC node supports `xdrFormat: "json"`, SoroScope asks for that and stores what it gets. Against older nodes it falls back to base64 XDR and decodes locally through `github.com/stellar/go-stellar-sdk/xdr`.

**The fallback latches after one attempt**, so only the first request pays for the discovery. A node that does not support the JSON format is detected once, not re-probed on every poll.

Either way the stored result is identical, so nothing downstream needs to know which path produced it.

## The stored form

A decoded value is a **single-key wrapper** naming its type:

```json
{"symbol": "transfer"}
{"address": "GDS2XSFBG5KQ3G3UNGSA6EX6E4OS3CSBS3NHFS7AGWZP67KD7T46HQJH"}
{"i128": "26039"}
{"bool": true}
```

`topics` is a JSON array of these; `value` is a single one.

### Wide integers are strings

Integers wider than 64 bits — `i128`, `u128`, `i256`, `u256` — are decimal **strings**, not JSON numbers:

```json
{"i128": "170141183460469231731687303715884105727"}
```

This is deliberate. JSON numbers are IEEE 754 doubles in most parsers, which would silently lose precision on a value that size. As strings, nothing is lost passing through JSON, and a client can parse them into whatever big-integer type it has.

If you are consuming the API, treat any integer field as potentially a string and parse accordingly.

## Rendering versus returning

**The API returns values as stored.** Clients get the wrapper form and can parse it programmatically.

**The UI renders them into short readable strings.** `{"symbol":"transfer"}` becomes `transfer`; an address is truncated to something that fits a table cell. The event detail page shows both the rendered form and the raw stored JSON, because the readable form is for scanning and the raw form is what you would actually parse.

This split is why the API does not return pre-rendered strings — rendering is lossy by design, and a client that wanted the underlying value could not recover it.

## Filtering against decoded values

Because topics are stored decoded as JSONB, filtering happens against the decoded form, not the XDR. `topic=transfer` is shorthand for the wrapper `{"symbol":"transfer"}`, and matching is exact and position-independent.

See [filtering events](../guides/filtering.md) for the details.

## Types you will see

| Wrapper key | Meaning |
| --- | --- |
| `symbol` | A Soroban symbol — how contracts encode event names. |
| `address` | An account (`G…`) or contract (`C…`) address. |
| `i128`, `u128`, `i256`, `u256` | Wide integers, as decimal strings. |
| `i32`, `u32`, `i64`, `u64` | Narrow integers. |
| `bool` | A boolean. |
| `string`, `bytes` | Text and byte strings. |
| `vec`, `map` | Nested structures, whose elements are themselves wrapped values. |

Nested `vec` and `map` values contain wrapped values all the way down, so a recursive walk handles arbitrary depth.
