# STATIC pure encoding efficiency

This batch preserves the exact rendering bytes from source
`2549ddd393b35c72e37b3eefff89d3540c94edb6`. It changes only
`StreamStaticRenderEncoding` and `StreamRenderContextV1`. It changes no
renderer/source selection, authorization, domains, caps, defaults, or vendor code.

The locally generated `data:text/html;base64,` animation URL is already JSON-safe:
its fixed prefix and Base64 alphabet contain none of the original escape triggers.
Only this branch bypasses escaping. An animation URI from source state still passes
through the original escaping semantics.

JSON escaping first counts the exact output expansion. With no special bytes it
returns the original byte sequence; otherwise it allocates the exact length and
copies ordinary spans in words, with byte tails. Quotes and backslashes, every
control byte below 32, `<`, and exactly the UTF-8 encodings of U+2028/U+2029 retain
their old encodings. Other bytes, including malformed UTF-8, remain untouched.
This helper is a serializer, not a new UTF-8 validator.

Script text uses the original case-insensitive eight-byte `</script` prefix rule.
A trailing `>` is not required: `</scriptX` is still escaped. The scan counts
matches, returns unchanged scripts without allocating a copy, and otherwise
copies spans while inserting the original backslash before `/`. Byte reads use
aligned word loads; copies write only complete destination words and explicit
remaining bytes. Input and neighboring memory are not modified. Both algorithms
remain linear in input length. Existing fixed-count concatenations are retained;
no input-length-dependent concatenation loop was found in these two files.

## Focused evidence

`test/unit/metadata/StreamStaticPureEncoding.t.sol` compares against the two frozen
old encoder libraries under `test/unit/metadata/helpers`. These references are
exact copies of the base source except library names and relocated imports.
Independent literal oracles cover the historically significant escapes. Other
cases cover all 256 byte values, every alignment through 64 bytes, all 64 case
variants of the closing prefix, adjacent and incomplete matches, valid and malformed
Unicode separator sequences, unchanged input/neighbor memory, and exact full
JSON/HTML/compact bytes. Three differential fuzz tests ran 256 cases each.

The final 14-source isolated native capture passed all 11 tests under Solidity
0.8.19, optimizer 200, viaIR, Paris, without compiler metadata. Runtime sizes were
12,594 bytes for the new pure formatter and 12,765 for its frozen reference.

| Identical input/output workload | Frozen gas | New gas |
| --- | ---: | ---: |
| 24,576-byte ONCHAIN `/*aaaa...*/`, full HTML | 16,963,842 | 5,106,311 |
| Same script, full JSON including base64 HTML | 42,686,707 | 7,707,896 |
| 24,576-byte ASCII JSON escape | 16,669,204 | 5,522,021 |
| Same length, `<` at every 97th byte | 16,851,432 | 11,779,036 |

Each measurement uses a fresh external pure wrapper frame with the same input
serialization, and asserts identical output hashes. These figures include that
wrapper's decoding/call overhead. The test harness has a high gas limit solely to
execute both the historically expensive reference and the new result in one test;
it is not a production transaction allowance. The large-script benchmark explicitly
selects ONCHAIN mode. An earlier retained capture accidentally selected OFFCHAIN
and is not the source of these gas figures.

Local reproducibility evidence is retained at
`D:/repos/6529Stream/.tmp-static-pure-encoding-2549-run4/`: `capture.json`,
`native.json`, `native.stderr.log`, `run.json`, `result.json`, and the frozen
project with its compiler artifacts. Earlier failed syntax/type captures remain
separate. No broad renderer build was run for this batch.

## Remaining acceptance

The full selected Renderer/Router/source graph and the producer checkpoint must
still be benchmarked together with cold dependencies, actual governed gas caps,
and the real transaction gas envelope. Pure savings do not prove that the full
producer transaction fits 16,777,216 gas. Large dependencies, token data, and inputs
with frequent escaping require their own complete-path measurements. Exact byte
parity preserves output semantics; deployment/runtime pin selection and actual
current-graph integration remain separately owned checks.
